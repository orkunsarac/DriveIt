import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment_outbox.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'planet_segment_test.dart' as fixtures;

void main() {
  const builder = PlanetSegmentBuilder();
  test('geometry changes change id; no source/time/version collision', () {
    final a = fixtures.fixture([8000]);
    final b = fixtures.fixture([10000]);
    expect(
      builder.build('drive', a).segments.single.id,
      isNot(builder.build('drive', b).segments.single.id),
    );
    expect(
      builder.build('drive', a).segments.single.toMap()['rulesVersion'],
      6,
    );
    expect(a.points.first.distanceFromPreviousMeters, 0);
  });
  test('non-monotonic timestamps rejected rather than fabricated segments', () {
    final r = fixtures.fixture([8000]);
    final bad = DriveTelemetryRecord(
      driveSessionId: 'drive',
      dataVersion: 1,
      createdAt: r.createdAt,
      acquisitionMetadata: r.acquisitionMetadata,
      points: [...r.points.reversed],
    );
    expect(builder.build('drive', bad).segments, isEmpty);
  });
  test(
    'non-finite metadata fails closed without JSON or scoring exception',
    () {
      final r = fixtures.fixture([8000]);
      final p = r.points.first;
      final bad = CanonicalTelemetryPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        speedMps: double.nan,
        headingDegrees: 0,
        altitudeMeters: 0,
        accuracyMeters: 5,
        distanceFromPreviousMeters: 0,
        accelerationMps2: 0,
      );
      expect(
        builder
            .build(
              'drive',
              DriveTelemetryRecord(
                driveSessionId: 'drive',
                dataVersion: 1,
                createdAt: r.createdAt,
                acquisitionMetadata: r.acquisitionMetadata,
                points: [bad, ...r.points.skip(1)],
              ),
            )
            .segments,
        isEmpty,
      );
    },
  );
  test(
    'JSON preserves canonical samples including microseconds and quality',
    () {
      final r = fixtures.fixture([8000, 12000]);
      final segments = builder.build('drive', r).segments;
      final payload = jsonDecode(jsonEncode(segments.last.toMap())) as Map;
      final points = payload['points'] as List;
      expect(points.first['breakBefore'], true);
      expect(
        points.first['timeMicros'],
        r.points[201].timestamp.microsecondsSinceEpoch,
      );
      expect(points.first['speedSource'], 'gps');
      expect(points.first['accuracy'], 5);
      expect(points.length, 201);
      expect(payload['score'], isNot(segments.first.id));
    },
  );
  test(
    'under minimum movement remains N/A but 5km local distance remains eligible',
    () {
      final r = fixtures.fixture([5000]);
      final sparse = DriveTelemetryRecord(
        driveSessionId: 'drive',
        dataVersion: 1,
        createdAt: r.createdAt,
        acquisitionMetadata: r.acquisitionMetadata,
        points: [
          r.points.first,
          CanonicalTelemetryPoint(
            latitude: 40.1,
            longitude: 29,
            timestamp: r.points[1].timestamp,
            speedMps: 20,
            headingDegrees: 0,
            altitudeMeters: 0,
            accuracyMeters: 5,
            distanceFromPreviousMeters: 5000,
            accelerationMps2: 0,
            speedSource: 'gps',
          ),
        ],
      );
      final s = builder.build('drive', sparse).segments.single;
      expect(s.score, isNull);
      expect(s.eligible, true);
    },
  );
  group('restart and authoritative receipt safety', () {
    late Directory dir;
    late Box<dynamic> box;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('planet_recovery_');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('recover');
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    test(
      'durable sending crash marker reconciles before any new submit',
      () async {
        final s = builder
            .build('drive', fixtures.fixture([8000]))
            .segments
            .single;
        final g = fixtures.FakeGateway();
        var outbox = PlanetSegmentOutbox(box, gateway: g);
        await outbox.prepare('owner', [s]);
        final key = box.keys.single;
        final row = outbox.entry('owner', s.id)!..['state'] = 'sending';
        await box.put(key, jsonEncode(row));
        await box.flush();
        await box.close();
        box = await Hive.openBox<dynamic>('recover');
        g.records[s.id] = const SegmentRemoteReceipt(
          SegmentRemoteState.accepted,
          remoteId: 'server-id',
          validDistanceMeters: 7500,
        );
        outbox = PlanetSegmentOutbox(box, gateway: g);
        await outbox.deliver('owner', s.id);
        expect(g.lookups, 1);
        expect(g.submits, 0);
        expect(outbox.acceptedDistance('owner'), 7500);
      },
    );
    test('lookup unavailable never submits, retry can proceed later', () async {
      final s = builder
          .build('drive', fixtures.fixture([8000]))
          .segments
          .single;
      final g = LookupFailureGateway();
      final outbox = PlanetSegmentOutbox(box, gateway: g);
      await outbox.prepare('owner', [s]);
      await outbox.deliver('owner', s.id);
      expect(g.submits, 0);
      expect(outbox.entry('owner', s.id)!['state'], 'retryableFailure');
      g.lookupFailure = false;
      await outbox.deliver('owner', s.id);
      expect(g.submits, 1);
      expect(outbox.acceptedDistance('owner'), 8000);
    });
    test(
      'validation pending excluded from accepted distance and reused without resubmit',
      () async {
        final s = builder
            .build('drive', fixtures.fixture([8000]))
            .segments
            .single;
        final g = fixtures.FakeGateway();
        g.records[s.id] = const SegmentRemoteReceipt(
          SegmentRemoteState.awaitingValidation,
          remoteId: 'server-id',
        );
        final outbox = PlanetSegmentOutbox(box, gateway: g);
        await outbox.prepare('owner', [s]);
        await outbox.deliver('owner', s.id);
        expect(outbox.acceptedDistance('owner'), 0);
        expect(outbox.entry('owner', s.id)!['state'], 'awaitingValidation');
        await outbox.deliver('owner', s.id);
        expect(g.submits, 0);
      },
    );
    test(
      'below 5km server distance cannot become accepted even if local 8km',
      () async {
        final s = builder
            .build('drive', fixtures.fixture([8000]))
            .segments
            .single;
        final g = fixtures.FakeGateway();
        g.records[s.id] = const SegmentRemoteReceipt(
          SegmentRemoteState.accepted,
          remoteId: 'server-id',
          validDistanceMeters: 4999,
        );
        final outbox = PlanetSegmentOutbox(box, gateway: g);
        await outbox.prepare('owner', [s]);
        await outbox.deliver('owner', s.id);
        expect(outbox.acceptedDistance('owner'), 0);
        expect(outbox.entry('owner', s.id)!['state'], 'retryableFailure');
      },
    );
    test(
      'prepare only eligible pieces; owner partition and terminal state immutable',
      () async {
        final p = builder.build('drive', fixtures.fixture([8000, 4000]));
        final g = fixtures.FakeGateway();
        final outbox = PlanetSegmentOutbox(box, gateway: g);
        await Future.wait([
          outbox.prepare('owner', p.segments),
          outbox.prepare('owner', p.segments),
        ]);
        expect(box.length, 1);
        await outbox.deliver('owner', p.segments.first.id);
        await outbox.prepare('owner', p.segments);
        expect(
          outbox.entry('owner', p.segments.first.id)!['state'],
          'accepted',
        );
        await outbox.prepare('second-owner', p.segments);
        expect(box.length, 2);
        expect(outbox.acceptedDistance('second-owner'), 0);
      },
    );
  });
  test(
    'flush failure never crosses network boundary; retry reconciles safely',
    () async {
      final box = fixtures.MemoryBox();
      final g = fixtures.FakeGateway();
      final outbox = PlanetSegmentOutbox(box, gateway: g);
      final s = builder
          .build('drive', fixtures.fixture([8000]))
          .segments
          .single;
      await outbox.prepare('owner', [s]);
      box.failFlush = true;
      await expectLater(outbox.deliver('owner', s.id), throwsStateError);
      expect(g.lookups, 0);
      expect(g.submits, 0);
      box.failFlush = false;
      await outbox.deliver('owner', s.id);
      expect(g.lookups, 1);
      expect(g.submits, 1);
      expect(outbox.acceptedDistance('owner'), 8000);
    },
  );
  test(
    'prepare flush failure preserves evidence and retry makes it durable',
    () async {
      final box = fixtures.MemoryBox()..failFlush = true;
      final outbox = PlanetSegmentOutbox(box);
      final s = builder
          .build('drive', fixtures.fixture([8000]))
          .segments
          .single;
      await expectLater(outbox.prepare('owner', [s]), throwsStateError);
      expect(outbox.entry('owner', s.id)!['payload']['points'].length, 201);
      box.failFlush = false;
      await outbox.prepare('owner', [s]);
      expect(box.length, 1);
      expect(outbox.acceptedDistance('owner'), 0);
    },
  );
}

class LookupFailureGateway extends fixtures.FakeGateway {
  bool lookupFailure = true;
  @override
  Future<SegmentRemoteReceipt> lookup(String owner, String id) async {
    if (lookupFailure) throw const SocketException('synthetic');
    return super.lookup(owner, id);
  }
}
