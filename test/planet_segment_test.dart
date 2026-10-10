import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment_outbox.dart';
import 'package:driveit_project/features/world_publish/segments/planet_publication_section.dart';

DriveTelemetryRecord fixture(
  List<double> distances, {
  bool timing = true,
  bool speed = true,
}) {
  final points = <CanonicalTelemetryPoint>[];
  var seconds = 0;
  for (var segment = 0; segment < distances.length; segment++) {
    if (segment > 0) seconds += 120;
    for (var i = 0; i <= 200; i++) {
      points.add(
        CanonicalTelemetryPoint(
          latitude: 40 + i * .0001,
          longitude: 29 + segment * .1,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(
            seconds * 1000000,
            isUtc: true,
          ),
          speedMps: speed ? 20 : 0,
          headingDegrees: 0,
          altitudeMeters: 0,
          accuracyMeters: 5,
          distanceFromPreviousMeters: i == 0 ? 0 : distances[segment] / 200,
          accelerationMps2: 0,
          speedSource: speed ? 'gps' : 'unavailable',
          breakBefore: segment > 0 && i == 0,
        ),
      );
      seconds++;
    }
  }
  return DriveTelemetryRecord(
    driveSessionId: 'drive',
    dataVersion: 1,
    createdAt: DateTime(2026),
    points: points,
    acquisitionMetadata: {
      'reliabilityPolicyVersion': 1,
      if (timing) 'startedAtMicros': 0,
      if (timing)
        'stopRequestedAtMicros': points.last.timestamp.microsecondsSinceEpoch,
    },
  );
}

class FakeGateway implements PlanetSegmentGateway {
  @override
  bool get enabled => true;
  final Map<String, SegmentRemoteReceipt> records = {};
  int submits = 0, lookups = 0;
  bool fail = false, loseResponse = false, reject = false;
  Completer<void>? gate;
  @override
  Future<SegmentRemoteReceipt> lookup(String owner, String id) async {
    lookups++;
    if (gate != null) await gate!.future;
    return records[id] ?? const SegmentRemoteReceipt(SegmentRemoteState.absent);
  }

  @override
  Future<SegmentRemoteReceipt> submit(
    String owner,
    Map<String, dynamic> payload,
  ) async {
    submits++;
    if (fail) throw const SocketException('synthetic');
    final receipt = SegmentRemoteReceipt(
      reject ? SegmentRemoteState.rejected : SegmentRemoteState.accepted,
      remoteId: 'remote:$submits',
      validDistanceMeters: (payload['distanceMeters'] as num).toDouble(),
    );
    records[payload['id']] = receipt;
    if (loseResponse) throw TimeoutException('synthetic');
    return receipt;
  }
}

class MemoryBox extends Fake implements Box<dynamic> {
  final data = <dynamic, dynamic>{};
  bool failFlush = false;
  @override
  String get name => 'memory';
  @override
  String? get path => 'memory';
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => data[key] ?? defaultValue;
  @override
  Iterable<dynamic> get values => data.values;
  @override
  int get length => data.length;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    data[key] = value;
  }

  @override
  Future<void> flush() async {
    if (failFlush) throw StateError('synthetic flush failure');
  }
}

void main() {
  const builder = PlanetSegmentBuilder();
  test(
    '8km and 8+4+12 independent distance, boundaries and deterministic identity',
    () {
      expect(builder.build('drive', fixture([8000])).eligible.length, 1);
      final record = fixture([8000, 4000, 12000]);
      final preview = builder.build('drive', record);
      expect(preview.segments.map((s) => s.distanceMeters), [
        8000,
        4000,
        12000,
      ]);
      expect(preview.eligible.length, 2);
      expect(preview.eligibleDistance, 20000);
      expect(preview.segments.map((s) => s.points.length), [201, 201, 201]);
      expect(
        preview.segments.map((s) => s.id),
        builder.build('drive', record).segments.map((s) => s.id),
      );
      expect(preview.segments.map((s) => s.id).toSet().length, 3);
      expect(record.points.length, 603); // no mutation/interpolated link
    },
  );
  test(
    'exact 5000 accepted locally, 4999 rejected without total-drive fallback',
    () {
      final p = builder.build('drive', fixture([5000, 4999]));
      expect(p.segments.first.eligible, true);
      expect(p.segments.last.eligible, false);
    },
  );
  test(
    'missing/legacy metadata fail closed; unknown timing and missing speed give N/A',
    () {
      expect(builder.build('drive', null).segments, isEmpty);
      final r = fixture([8000]);
      expect(
        builder
            .build(
              'drive',
              DriveTelemetryRecord(
                driveSessionId: 'drive',
                dataVersion: 1,
                createdAt: r.createdAt,
                points: r.points,
              ),
            )
            .segments,
        isEmpty,
      );
      expect(
        builder
            .build('drive', fixture([8000], timing: false))
            .segments
            .single
            .score,
        isNull,
      );
      expect(
        builder
            .build('drive', fixture([8000], speed: false))
            .segments
            .single
            .score,
        isNull,
      );
      expect(builder.build('drive', r).segments.single.score, isNotNull);
      expect(builder.build('other', r).segments, isEmpty);
    },
  );
  test('bad accuracy and unmarked time gap split without inventing route', () {
    final r = fixture([8000]);
    final points = [...r.points];
    final p = points[100];
    points[100] = CanonicalTelemetryPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      timestamp: p.timestamp,
      speedMps: 20,
      headingDegrees: 0,
      altitudeMeters: 0,
      accuracyMeters: 999,
      distanceFromPreviousMeters: 40,
      accelerationMps2: 0,
    );
    final result = builder.build(
      'drive',
      DriveTelemetryRecord(
        driveSessionId: 'drive',
        dataVersion: 1,
        createdAt: r.createdAt,
        points: points,
        acquisitionMetadata: r.acquisitionMetadata,
      ),
    );
    expect(result.segments.length, 2);
    expect(result.eligible, isEmpty);
    expect(
      result.segments.fold<int>(0, (sum, s) => sum + s.points.length),
      200,
    );
  });

  group('durable outbox', () {
    late Directory dir;
    late Box<dynamic> box;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('planet_segments_');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('outbox');
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    test(
      'duplicate prepare, partial success, retry only failure, no source deletion coupling',
      () async {
        final gateway = FakeGateway();
        final outbox = PlanetSegmentOutbox(box, gateway: gateway);
        final candidates = builder
            .build('drive', fixture([8000, 4000, 12000]))
            .eligible
            .toList();
        await outbox.prepare('owner', candidates);
        await outbox.prepare('owner', candidates);
        expect(box.length, 2);
        await outbox.deliver('owner', candidates.first.id);
        gateway.fail = true;
        await outbox.deliver('owner', candidates.last.id);
        expect(outbox.acceptedDistance('owner'), 8000);
        expect(
          outbox.entry('owner', candidates.last.id)!['state'],
          'retryableFailure',
        );
        gateway.fail = false;
        await outbox.deliver('owner', candidates.last.id);
        await outbox.deliver('owner', candidates.first.id);
        expect(gateway.submits, 3);
        expect(outbox.acceptedDistance('owner'), 20000);
        expect(outbox.acceptedDistance('other'), 0);
        // History/World stores are not dependencies and cannot remove this receipt.
        expect(outbox.entries('owner', 'drive').length, 2);
      },
    );
    test(
      'unknown response then reopen reconciles accepted without duplicate submit',
      () async {
        final g = FakeGateway()..loseResponse = true;
        var outbox = PlanetSegmentOutbox(box, gateway: g);
        final s = builder.build('drive', fixture([8000])).segments.single;
        await outbox.prepare('owner', [s]);
        await outbox.deliver('owner', s.id);
        await box.close();
        box = await Hive.openBox<dynamic>('outbox');
        outbox = PlanetSegmentOutbox(box, gateway: g);
        await outbox.deliver('owner', s.id);
        expect(g.submits, 1);
        expect(outbox.entry('owner', s.id)!['state'], 'accepted');
      },
    );
    test(
      'in-flight duplicate, rejected terminal and disabled backend never submits',
      () async {
        final s = builder.build('drive', fixture([8000])).segments.single;
        final g = FakeGateway()
          ..gate = Completer<void>()
          ..reject = true;
        final outbox = PlanetSegmentOutbox(box, gateway: g);
        await outbox.prepare('owner', [s]);
        final a = outbox.deliver('owner', s.id),
            b = outbox.deliver('owner', s.id);
        expect(identical(a, b), true);
        g.gate!.complete();
        await a;
        await b;
        await outbox.deliver('owner', s.id);
        expect(g.submits, 1);
        expect(outbox.acceptedDistance('owner'), 0);
        await PlanetSegmentOutbox(box).prepare('other', [s]);
        await PlanetSegmentOutbox(box).deliver('other', s.id);
        expect(outbox.entry('other', s.id)!['state'], 'queued');
      },
    );
  });
  testWidgets(
    'preview only prepares eligible pieces, never shared map acceptance',
    (tester) async {
      final box = MemoryBox();
      final drive = DriveSession(
        id: 'drive',
        date: DateTime(2026),
        distance: 24000,
        durationSeconds: 800,
        averageSpeed: 50,
        maxSpeed: 80,
        mapImagePath: '',
        route: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlanetPublicationSection(
                drive: drive,
                record: fixture([8000, 4000, 12000]),
                existingLookup: () async => false,
                outbox: PlanetSegmentOutbox(box),
                ownerScope: 'owner',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Parça 2'), findsOneWidget);
      expect(find.textContaining('2 uygun parça'), findsOneWidget);
      await tester.tap(find.text('Uygun Parçaları Hazırla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hazırla'));
      await tester.pumpAndSettle();
      expect(box.length, 2);
      expect(PlanetSegmentOutbox(box).acceptedDistance('owner'), 0);
      expect(find.text("DriveIt Gezegeni'nde"), findsNothing);
    },
  );
}
