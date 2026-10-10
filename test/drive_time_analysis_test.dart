import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/drive_time_analysis.dart';
import 'package:driveit_project/services/drive_route_projection.dart';
import 'package:driveit_project/features/drive_score/services/drive_phase_analyzer.dart';
import 'package:driveit_project/features/drive_score/services/tempo_performance_engine.dart';
import 'package:driveit_project/features/drive_score/models/driving_analysis_models.dart';

final start = DateTime.utc(2026);
CanonicalTelemetryPoint point(
  double sec, {
  double speed = 10,
  bool gap = false,
  double distance = 50,
  String source = 'native',
  double acceleration = 0,
}) => CanonicalTelemetryPoint(
  latitude: 40,
  longitude: 29,
  timestamp: start.add(Duration(microseconds: (sec * 1000000).round())),
  speedMps: speed,
  headingDegrees: 0,
  altitudeMeters: 0,
  accuracyMeters: 3,
  distanceFromPreviousMeters: distance,
  accelerationMps2: acceleration,
  breakBefore: gap,
  speedSource: source,
  accelerationReliable: !gap,
);
Map<String, dynamic> metadata(double sec) => {
  'reliabilityPolicyVersion': 1,
  'startedAtMicros': start.microsecondsSinceEpoch,
  'stopRequestedAtMicros': start
      .add(Duration(microseconds: (sec * 1000000).round()))
      .microsecondsSinceEpoch,
};
List<CanonicalTelemetryPoint> timeline(double until) => [
  for (var t = 0.0; t < until; t += 5) point(t),
  point(until),
];
void main() {
  test(
    'short gap metadata excludes its delta and adds boundary without changing source',
    () {
      final p = CanonicalTelemetryPoint.fromMap({
        ...point(15).toMap(),
        'gapDurationMicros': 10000000,
      })!;
      final points = [point(0), point(5), p, point(20)];
      final result = DriveTimeAnalysis.analyze(points, metadata: metadata(20));
      final projection = DriveRouteProjection(points);
      expect(result.measuredMicros, 10000000);
      expect(result.distanceMeters, 100);
      expect(projection.distanceMeters, 100);
      expect(projection.route[2].breakBefore, true);
      expect(p.breakBefore, false);
      expect(p.distanceFromPreviousMeters, 50);
    },
  );
  test(
    'continuous session: full coverage, measured time and SI conversion',
    () {
      final result = DriveTimeAnalysis.analyze(
        timeline(100),
        metadata: metadata(100),
      );
      expect(result.coverage, 1);
      expect(result.lostMicros, 0);
      expect(result.distanceMeters, 1000);
      expect(result.averageSpeedKmh, 36);
      expect(result.movingAverageSpeedKmh, 36);
      expect(result.scoreEligible, true);
    },
  );
  for (final duration in [79.99, 80.0, 100.0]) {
    test(
      'exact coverage boundary $duration / 100 without rounded eligibility',
      () {
        final result = DriveTimeAnalysis.analyze(
          timeline(duration),
          metadata: metadata(100),
        );
        expect(result.coverage, closeTo(duration / 100, 1e-12));
        expect(result.coverageSufficient, duration >= 80);
      },
    );
  }
  test('80 percent and adequate movement can score with partial warning', () {
    final result = DriveTimeAnalysis.analyze(
      timeline(160),
      metadata: metadata(200),
    );
    expect(result.scoreEligible, true);
    expect(result.partial, true);
    expect(result.lostMicros, 40000000);
  });
  test(
    'high coverage but insufficient moving duration/samples is not scoreable',
    () {
      final result = DriveTimeAnalysis.analyze(
        timeline(20),
        metadata: metadata(20),
      );
      expect(result.coverageSufficient, true);
      expect(result.movementSufficient, false);
      expect(result.scoreEligible, false);
    },
  );
  for (final gapLength in [2, 120]) {
    test(
      'explicit $gapLength second gap contributes no motion, distance or stop',
      () {
        final points = [
          point(0, speed: 0),
          point(5, speed: 0, distance: 0),
          point(5.0 + gapLength, speed: 0, gap: true, distance: 99999),
          point(10.0 + gapLength, speed: 0, distance: 0),
        ];
        final result = DriveTimeAnalysis.analyze(
          points,
          metadata: metadata(10.0 + gapLength),
        );
        expect(result.measuredMicros, 10000000);
        expect(result.stationaryMicros, 10000000);
        expect(result.lostMicros, gapLength * 1000000);
        expect(result.movingMicros, 0);
        expect(result.distanceMeters, 0);
        expect(result.stopCount, 2);
      },
    );
  }
  test('trusted stationary time remains in general average denominator', () {
    final points = [
      point(0),
      point(5),
      point(10, speed: 0, distance: 0),
      point(15, speed: 0, distance: 0),
      point(20, speed: 0, distance: 0),
    ];
    final result = DriveTimeAnalysis.analyze(points, metadata: metadata(20));
    expect(result.measuredMicros, 20000000);
    expect(result.movingMicros, 5000000);
    expect(result.averageSpeedKmh, 9);
    expect(result.movingAverageSpeedKmh, 36);
  });
  test('unmarked long gap and held/unknown speed cannot prove intervals', () {
    final result = DriveTimeAnalysis.analyze([
      point(0),
      point(120, distance: 99999),
      point(125, source: 'held_estimate'),
      point(130),
      point(135),
    ], metadata: metadata(135));
    expect(result.measuredMicros, 15000000);
    expect(result.movingMicros, 5000000);
    expect(result.distanceMeters, 150);
  });
  test('legacy timing remains unknown; no date or GPS endpoints invented', () {
    final result = DriveTimeAnalysis.analyze(timeline(100));
    expect(result.totalMicros, isNull);
    expect(result.coverage, isNull);
    expect(result.scoreEligible, false);
  });
  test('nonmonotonic or invalid session events cannot pass global gate', () {
    expect(
      DriveTimeAnalysis.analyze([
        point(0),
        point(5),
        point(0),
        point(5),
      ], metadata: metadata(10)).timingKnown,
      false,
    );
    expect(
      DriveTimeAnalysis.analyze(
        timeline(100),
        metadata: metadata(0),
      ).timingKnown,
      false,
    );
  });
  test(
    'gap boundary creates no artificial acceleration/deceleration events',
    () {
      final analysis = const DrivePhaseAnalyzer().analyze(
        driveSessionId: 'synthetic',
        reliableIntervalsOnly: true,
        telemetry: [
          point(0, speed: 30),
          point(5, speed: 30),
          point(120, speed: 0, gap: true, distance: 0),
          point(125, speed: 0, distance: 0),
        ],
      );
      expect(
        analysis.events.where(
          (e) =>
              e.type == DrivingEventType.deceleration ||
              e.type == DrivingEventType.acceleration,
        ),
        isEmpty,
      );
    },
  );
  test(
    'Tempo ignores unmeasured gap, including contaminated distance delta',
    () {
      final points = [
        point(0),
        point(5),
        point(120, gap: true, distance: 99999),
        point(125),
      ];
      final analysis = const DrivePhaseAnalyzer().analyze(
        driveSessionId: 'synthetic',
        reliableIntervalsOnly: true,
        telemetry: points,
      );
      final score = const TempoPerformanceEngine().score(analysis);
      expect(score.totalElapsedDuration.inSeconds, 10);
      expect(score.movingDuration.inSeconds, 10);
      expect(score.totalDistanceKm, .1);
      expect(score.averageCruisingSpeedKmh, 36);
    },
  );
}
