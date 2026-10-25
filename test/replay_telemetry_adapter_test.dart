import 'package:driveit_project/features/drive_replay/replay_telemetry_adapter.dart';
import 'package:driveit_project/features/drive_replay/replay_interpolator.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';

final epoch = DateTime.utc(2026, 8, 1);

CanonicalTelemetryPoint point(
  int seconds, {
  double latitude = 41,
  double accuracy = 3,
  double speed = 10,
  String source = 'native',
  double distance = 10,
  bool boundary = false,
  int gapMicros = 0,
}) => CanonicalTelemetryPoint(
  latitude: latitude,
  longitude: 29,
  timestamp: epoch.add(Duration(seconds: seconds)),
  speedMps: speed,
  headingDegrees: 0,
  altitudeMeters: 0,
  accuracyMeters: accuracy,
  distanceFromPreviousMeters: distance,
  accelerationMps2: 0,
  speedSource: source,
  breakBefore: boundary,
  gapDurationMicros: gapMicros,
);

DriveSession drive() => DriveSession(
  id: 'adapter-fixture',
  date: DateTime(2000),
  distance: 9999,
  durationSeconds: 900,
  averageSpeed: 99,
  maxSpeed: 150,
  mapImagePath: '',
  route: [
    RoutePoint(
      latitude: 40,
      longitude: 28,
      legacyHiveFields: {2: DateTime(2001)},
    ),
    RoutePoint(latitude: 40.1, longitude: 28.1),
  ],
);

DriveTelemetryRecord record(
  List<CanonicalTelemetryPoint> points, {
  String id = 'adapter-fixture',
  int version = DriveTelemetryRecord.currentDataVersion,
}) => DriveTelemetryRecord(
  driveSessionId: id,
  dataVersion: version,
  createdAt: DateTime(2002),
  points: points,
);

ReplayTelemetryData adapt(List<CanonicalTelemetryPoint> points) =>
    ReplayTelemetryAdapter.build(drive(), record(points));

bool hasIssue(ReplayTelemetryData data, ReplayTelemetryIssue issue) =>
    data.diagnostics.any((d) => d.issue == issue);

Object snapshot(ReplayTelemetryData data) => [
  data.source,
  for (final s in data.samples)
    [
      s.sourceIndex,
      s.segmentId,
      s.latitude,
      s.longitude,
      s.timestamp,
      s.elapsed,
      s.speedKmh,
      s.speedSource,
      s.recordedSpeedSource,
      s.distanceIncrementMeters,
      s.cumulativeDistanceMeters,
      s.breakBefore,
      s.gapDuration,
      s.boundaryReasons,
    ],
  for (final d in data.diagnostics) [d.issue, d.sourceIndex],
];

void main() {
  test('missing speed does not break a reliable positional interval', () {
    final data = adapt([point(0), point(1, source: 'unavailable'), point(2)]);
    expect(data.samples[1].speedKmh, isNull);
    expect(data.samples[1].breakBefore, isFalse);
    expect(data.samples.map((s) => s.segmentId), [0, 0, 0]);
    expect(data.samples.last.cumulativeDistanceMeters, 20);
  });

  test('sub-minimum sample interval becomes a boundary', () {
    final data = adapt([point(0), point(0), point(1)]);
    expect(data.samples.last.distanceIncrementMeters, isNull);
    final microPoint = CanonicalTelemetryPoint(
      latitude: 41,
      longitude: 29,
      timestamp: epoch.add(const Duration(milliseconds: 100)),
      speedMps: 1,
      headingDegrees: 0,
      altitudeMeters: 0,
      accuracyMeters: 3,
      distanceFromPreviousMeters: 1,
      accelerationMps2: 0,
      speedSource: 'native',
    );
    final short = adapt([point(0), microPoint]);
    expect(short.samples.last.distanceIncrementMeters, isNull);
    expect(
      short.samples.last.boundaryReasons,
      contains(ReplayTelemetryIssue.unreliableInterval),
    );
  });

  test('consecutive caller snapshots cannot reuse a previous record', () {
    final canonical = adapt([point(0)]);
    final legacy = ReplayTelemetryAdapter.build(drive(), null);
    expect(canonical.source, ReplayTelemetrySource.canonical);
    expect(legacy.source, ReplayTelemetrySource.legacy);
    expect(legacy.samples.first.speedKmh, isNull);
    final empty = drive()..route.clear();
    expect(ReplayTelemetryAdapter.build(empty, null).samples, isEmpty);
  });

  test('canonical uses recorded time and accepted increments, not summary', () {
    final data = adapt([point(0), point(1), point(3, distance: 20)]);
    expect(data.source, ReplayTelemetrySource.canonical);
    expect(data.samples.map((p) => p.sourceIndex), [0, 1, 2]);
    expect(data.samples.last.elapsed, const Duration(seconds: 3));
    expect(data.samples.last.timestamp, epoch.add(const Duration(seconds: 3)));
    expect(data.samples.first.distanceIncrementMeters, isNull);
    expect(data.samples.last.cumulativeDistanceMeters, 30);
    expect(data.samples.map((p) => p.segmentId), [0, 0, 0]);
  });

  test(
    'canonical frame preserves stationary time and interpolates one segment',
    () {
      final data = adapt([
        point(0, latitude: 41, speed: 10),
        point(5, latitude: 41, speed: 10),
        point(10, latitude: 41.001, speed: 20),
      ]);
      final stopped = ReplayInterpolator.frameAtTelemetry(
        data,
        const Duration(seconds: 3),
      );
      expect(stopped.latitude, 41);
      expect(stopped.elapsed, const Duration(seconds: 3));
      expect(stopped.speedKmh, closeTo(36, 0.001));
      expect(stopped.speedKind, ReplayFrameSpeedKind.interpolatedNative);
      expect(stopped.distanceMeters, closeTo(6, 0.001));
    },
  );

  test(
    'canonical frame reports a gap without interpolated position or distance',
    () {
      final data = adapt([
        point(0, latitude: 41),
        point(2, latitude: 41.001, boundary: true),
        point(4, latitude: 41.002),
      ]);
      final frame = ReplayInterpolator.frameAtTelemetry(
        data,
        const Duration(seconds: 1),
      );
      expect(frame.isGap, isTrue);
      expect(frame.latitude, isNull);
      expect(frame.longitude, isNull);
      expect(frame.speedKmh, isNull);
      expect(frame.distanceMeters, 0);
      expect(frame.elapsed, const Duration(seconds: 1));
    },
  );

  test('mixed or missing sample speed is not interpolated', () {
    final data = adapt([
      point(0, source: 'native'),
      point(1, source: 'geometry_estimate'),
      point(2, source: 'unavailable'),
      point(3, source: 'native'),
    ]);
    for (final second in [0.5, 1.5, 2.5]) {
      final frame = ReplayInterpolator.frameAtTelemetry(
        data,
        Duration(milliseconds: (second * 1000).round()),
      );
      expect(frame.speedKmh, isNull);
      expect(frame.speedKind, ReplayFrameSpeedKind.unavailable);
    }
  });

  test(
    'exact interior sample keeps its own speed source across a source change',
    () {
      final data = adapt([
        point(0, source: 'native'),
        point(1, source: 'geometry_estimate'),
        point(2, source: 'native'),
      ]);
      final frame = ReplayInterpolator.frameAtTelemetry(
        data,
        const Duration(seconds: 1),
      );
      expect(frame.speedKmh, 36);
      expect(frame.speedKind, ReplayFrameSpeedKind.geometryEstimate);
    },
  );

  test('canonical one-sample and zero-duration frame stays deterministic', () {
    final data = adapt([point(0)]);
    final atStart = ReplayInterpolator.frameAtTelemetry(data, Duration.zero);
    final later = ReplayInterpolator.frameAtTelemetry(
      data,
      const Duration(seconds: 5),
    );
    expect(atStart.latitude, 41);
    expect(later.latitude, 41);
    expect(later.elapsed, Duration.zero);
    expect(later.speedKmh, 36);
  });

  test('native canonical and geometry estimated speed remain distinct', () {
    final samples = adapt([
      point(0),
      point(1, source: 'geometry_estimate'),
    ]).samples;
    expect(samples.first.speedSource, ReplaySpeedSource.nativeCanonical);
    expect(samples.last.speedSource, ReplaySpeedSource.geometryEstimate);
    expect(samples.map((s) => s.speedKmh), [36, 36]);
  });

  for (final source in ['legacy', 'unavailable', 'held_estimate', 'future']) {
    test('$source speed is not presented as a measurement', () {
      final data = adapt([point(0, source: source)]);
      expect(data.samples.single.speedKmh, isNull);
      expect(data.samples.single.speedSource, ReplaySpeedSource.unavailable);
      expect(data.samples.single.recordedSpeedSource, source);
      expect(data.diagnostics, isNotEmpty);
    });
  }

  for (final speed in [double.nan, double.infinity, -1.0, 71.0]) {
    test('invalid numeric speed $speed remains unavailable', () {
      final data = adapt([point(0, speed: speed)]);
      expect(data.samples.single.speedKmh, isNull);
      expect(hasIssue(data, ReplayTelemetryIssue.invalidSpeed), isTrue);
    });
  }

  test('stationary samples and genuine zero speed preserve elapsed time', () {
    final data = adapt([
      point(0, speed: 0, distance: 0),
      point(2, speed: 0, distance: 0),
      point(4, speed: 0, distance: 0),
    ]);
    expect(data.samples, hasLength(3));
    expect(data.samples.last.elapsed, const Duration(seconds: 4));
    expect(data.samples.last.speedKmh, 0);
    expect(data.samples.last.distanceIncrementMeters, 0);
    expect(data.samples.last.cumulativeDistanceMeters, 0);
  });

  for (final seconds in [6, 15, 16]) {
    test('$seconds second gap does not bridge distance', () {
      final data = adapt([point(0), point(seconds), point(seconds + 1)]);
      expect(data.samples[1].distanceIncrementMeters, isNull);
      expect(data.samples[1].segmentId, 1);
      expect(data.samples[1].gapDuration, Duration(seconds: seconds));
      expect(
        data.samples[1].boundaryReasons,
        contains(ReplayTelemetryIssue.sampleGap),
      );
      expect(data.samples.last.cumulativeDistanceMeters, 10);
      expect(data.samples.last.elapsed, Duration(seconds: seconds + 1));
    });
  }

  test('recorded short gap and explicit break remain boundaries', () {
    final data = adapt([
      point(0),
      point(1, gapMicros: 500000),
      point(2, boundary: true),
      point(3),
    ]);
    expect(data.samples[1].gapDuration, const Duration(microseconds: 500000));
    expect(
      data.samples[1].boundaryReasons,
      contains(ReplayTelemetryIssue.recordedGap),
    );
    expect(
      data.samples[2].boundaryReasons,
      contains(ReplayTelemetryIssue.recordedBreak),
    );
    expect(data.samples.map((p) => p.segmentId), [0, 1, 2, 2]);
    expect(data.samples.last.cumulativeDistanceMeters, 10);
  });

  for (final invalid in [
    point(1, latitude: double.nan),
    point(1, latitude: 91),
    point(1, accuracy: 31),
    point(1, accuracy: -1),
    point(1, accuracy: double.infinity),
  ]) {
    test('invalid coordinate or accuracy cannot create a bridge', () {
      final data = adapt([point(0), invalid, point(2), point(3)]);
      expect(data.samples.map((s) => s.sourceIndex), [0, 2, 3]);
      expect(data.samples[1].breakBefore, isTrue);
      expect(data.samples[1].distanceIncrementMeters, isNull);
      expect(data.samples.last.cumulativeDistanceMeters, 10);
      expect(data.diagnostics.any((d) => d.sourceIndex == 1), isTrue);
    });
  }

  test('duplicate and backward times are not sorted or bridged', () {
    final data = adapt([
      point(0),
      point(2),
      point(2),
      point(1),
      point(3),
      point(4),
    ]);
    expect(data.samples.map((s) => s.sourceIndex), [0, 1, 4, 5]);
    expect(
      data.samples[2].boundaryReasons,
      contains(ReplayTelemetryIssue.nonIncreasingTime),
    );
    expect(data.samples[2].distanceIncrementMeters, isNull);
    expect(data.samples.last.cumulativeDistanceMeters, 20);
    expect(data.samples.last.elapsed, const Duration(seconds: 4));
  });

  for (final distance in [double.nan, double.infinity, -1.0]) {
    test('invalid interval distance $distance is unknown, not zero', () {
      final data = adapt([point(0), point(1, distance: distance), point(2)]);
      expect(data.samples[1].distanceIncrementMeters, isNull);
      expect(
        data.samples[1].boundaryReasons,
        contains(ReplayTelemetryIssue.unreliableInterval),
      );
      expect(data.samples.last.cumulativeDistanceMeters, 10);
    });
  }

  test(
    'legacy has geometry without fabricated GPS speed, time or distance',
    () {
      final data = ReplayTelemetryAdapter.build(drive(), null);
      expect(data.source, ReplayTelemetrySource.legacy);
      expect(data.samples, hasLength(2));
      expect(hasIssue(data, ReplayTelemetryIssue.missingRecord), isTrue);
      for (final s in data.samples) {
        expect(s.timestamp, isNull);
        expect(s.elapsed, isNull);
        expect(s.speedKmh, isNull);
        expect(s.distanceIncrementMeters, isNull);
      }
    },
  );

  test('wrong ID rejects telemetry before using any points', () {
    final data = ReplayTelemetryAdapter.build(
      drive(),
      record([point(0)], id: 'other'),
    );
    expect(data.source, ReplayTelemetrySource.legacy);
    expect(data.samples.first.latitude, 40);
    expect(hasIssue(data, ReplayTelemetryIssue.driveIdMismatch), isTrue);
  });

  test('unsupported version rejects telemetry', () {
    final data = ReplayTelemetryAdapter.build(
      drive(),
      record([point(0)], version: 2),
    );
    expect(data.source, ReplayTelemetrySource.legacy);
    expect(hasIssue(data, ReplayTelemetryIssue.unsupportedVersion), isTrue);
  });

  test('empty or unusable canonical falls back with diagnostics', () {
    for (final points in [
      <CanonicalTelemetryPoint>[],
      [point(0, latitude: 91)],
    ]) {
      final data = adapt(points);
      expect(data.source, ReplayTelemetrySource.legacy);
      expect(hasIssue(data, ReplayTelemetryIssue.emptyCanonical), isTrue);
    }
  });

  test(
    'legacy invalid points and explicit breaks preserve continuity limits',
    () {
      final session = drive();
      session.route.addAll([
        RoutePoint(latitude: double.nan, longitude: 0),
        RoutePoint(latitude: 40.2, longitude: 28.2),
        RoutePoint(latitude: 40.3, longitude: 28.3, breakBefore: true),
      ]);
      final data = ReplayTelemetryAdapter.build(session, null);
      expect(data.samples.map((s) => s.sourceIndex), [0, 1, 3, 4]);
      expect(data.samples.map((s) => s.segmentId), [0, 0, 1, 2]);
      expect(
        data.samples[2].boundaryReasons,
        contains(ReplayTelemetryIssue.invalidCoordinate),
      );
      expect(data.samples.last.breakBefore, isTrue);
    },
  );

  test(
    'deterministic immutable snapshots do not mutate or retain input lists',
    () {
      final session = drive();
      final points = [point(0), point(1), point(2, boundary: true)];
      final telemetry = record(points);
      final before = points.map((p) => p.toMap()).toList();
      final fields = Map<int, dynamic>.of(session.route.first.legacyHiveFields);
      final first = ReplayTelemetryAdapter.build(session, telemetry);
      final second = ReplayTelemetryAdapter.build(session, telemetry);
      expect(snapshot(first), snapshot(second));
      expect(points.map((p) => p.toMap()).toList(), before);
      expect(session.route.first.legacyHiveFields, fields);
      expect(session.distance, 9999);
      expect(telemetry.points, same(points));
      expect(() => first.samples.clear(), throwsUnsupportedError);
      expect(() => first.diagnostics.clear(), throwsUnsupportedError);
      expect(
        () => first.samples.last.boundaryReasons.clear(),
        throwsUnsupportedError,
      );
      points.clear();
      expect(first.samples, hasLength(3));
      final legacy = ReplayTelemetryAdapter.build(session, null);
      session.route.first.latitude = 12;
      session.route.clear();
      expect(legacy.samples.first.latitude, 40);
      expect(legacy.samples, hasLength(2));
    },
  );
}
