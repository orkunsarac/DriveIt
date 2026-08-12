import 'package:driveit_project/features/drive_score/models/driving_analysis_models.dart';
import 'package:driveit_project/features/drive_score/services/acceleration_performance_engine.dart';
import 'package:driveit_project/features/drive_score/services/driving_smoothness_engine.dart';
import 'package:driveit_project/features/drive_score/services/transition_control_engine.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const smoothness = DrivingSmoothnessEngine();
  const acceleration = AccelerationPerformanceEngine();
  const transitions = TransitionControlEngine();

  test('long stable cruise has high smoothness while no cruise is N/A', () {
    final stable = smoothness.score(analysis([event('cruise', 0, 40)]));
    final none = smoothness.score(analysis([]));
    expect(stable.totalScore, greaterThan(70));
    expect(none.applicable, isFalse);
  });

  test('traffic cruise is excluded rather than creating a penalty', () {
    final traffic = const TrafficContext(
      regime: TrafficRegime.stopAndGo,
      confidence: .9,
      denseTrafficConfidence: .8,
      stopAndGoConfidence: .9,
    );
    final result = smoothness.score(
      analysis([event('cruise', 0, 20, traffic: traffic)]),
    );
    expect(result.applicable, isFalse);
  });

  test(
    'clean acceleration scores higher throttle quality than interrupted acceleration',
    () {
      final clean = acceleration.score(analysis([event('acceleration', 0, 6)]));
      final noisyFeatures = features([
        10,
        12,
        11,
        14,
        13,
        16,
        18,
        18,
        18,
        18,
        18,
      ]);
      final noisy = acceleration.score(
        DrivePhaseAnalysisResult(
          driveSessionId: 'd',
          features: noisyFeatures,
          phaseTimeline: const [],
          corneringTimeline: const [],
          trafficTimeline: List.filled(
            noisyFeatures.length,
            TrafficContext.unknown,
          ),
          events: [event('acceleration', 0, 6)],
        ),
      );
      expect(clean.applicable, isTrue);
      expect(
        clean.throttleApplicationScore,
        greaterThan(noisy.throttleApplicationScore),
      );
    },
  );

  test('no acceleration is N/A and all category bounds hold', () {
    final result = acceleration.score(analysis([]));
    expect(result.applicable, isFalse);
    expect(result.totalScore, 0);
  });

  test(
    'clean cruise-deceleration-cruise transition earns positive-only score',
    () {
      final result = transitions.score(
        analysis([
          event('cruise', 0, 5),
          event('deceleration', 6, 10),
          event('cruise', 11, 18),
        ]),
      );
      expect(result.cruiseDecelCruiseScore, greaterThan(0));
      expect(result.totalScore, inInclusiveRange(0, 50));
    },
  );

  test(
    'clean cruise-corner-cruise and acceleration-cruise transitions are found',
    () {
      final corner = transitions.score(
        analysis([
          event('cruise', 0, 5),
          event('corner', 6, 10),
          event('cruise', 11, 18),
        ]),
      );
      final accel = transitions.score(
        analysis([
          event('acceleration', 0, 5),
          event('unknown', 6, 7),
          event('cruise', 8, 16),
        ]),
      );
      expect(corner.cruiseCornerCruiseScore, greaterThan(0));
      expect(accel.accelerationCruiseScore, greaterThan(0));
    },
  );

  test('phase six engines are deterministic', () {
    final input = analysis([
      event('cruise', 0, 5),
      event('deceleration', 6, 10),
      event('cruise', 11, 18),
    ]);
    expect(
      transitions.score(input).totalScore,
      transitions.score(input).totalScore,
    );
  });
}

DrivePhaseAnalysisResult analysis(List<DrivingEvent> events) {
  final f = features(List.generate(50, (i) => 20.0));
  return DrivePhaseAnalysisResult(
    driveSessionId: 'd',
    features: f,
    phaseTimeline: const [],
    corneringTimeline: const [],
    trafficTimeline: List.filled(f.length, TrafficContext.unknown),
    events: events,
  );
}

List<TelemetryFeature> features(List<double> speeds) {
  final start = DateTime.utc(2026, 1, 1);
  return List.generate(
    speeds.length,
    (i) => TelemetryFeature(
      index: i,
      point: CanonicalTelemetryPoint(
        latitude: 41,
        longitude: 29,
        timestamp: start.add(Duration(seconds: i)),
        speedMps: speeds[i],
        headingDegrees: 0,
        altitudeMeters: 0,
        accuracyMeters: 5,
        distanceFromPreviousMeters: i == 0 ? 0 : speeds[i],
        accelerationMps2: i == 0 ? 0 : speeds[i] - speeds[i - 1],
      ),
      rollingMeanSpeedMps: speeds[i],
      rollingSpeedVariance: 0,
      smoothedAccelerationMps2: i == 0 ? 0 : speeds[i] - speeds[i - 1],
      headingDeltaDegrees: 0,
      headingChangeRateDegreesPerSecond: 0,
      rollingLowSpeedRatio: 0,
      stationaryDurationSeconds: 0,
      movingDurationSeconds: i.toDouble(),
    ),
  );
}

DrivingEvent event(
  String name,
  int start,
  int end, {
  TrafficContext traffic = TrafficContext.unknown,
}) {
  final type = switch (name) {
    'cruise' => DrivingEventType.cruise,
    'deceleration' => DrivingEventType.deceleration,
    'acceleration' => DrivingEventType.acceleration,
    'corner' => DrivingEventType.corner,
    _ => DrivingEventType.stop,
  };
  final owner = switch (type) {
    DrivingEventType.cruise => EventOwnerDomain.cruising,
    DrivingEventType.deceleration => EventOwnerDomain.braking,
    DrivingEventType.acceleration => EventOwnerDomain.acceleration,
    DrivingEventType.corner => EventOwnerDomain.cornering,
    DrivingEventType.stop => EventOwnerDomain.stopping,
  };
  final t = DateTime.utc(2026, 1, 1);
  return DrivingEvent(
    id: '$name-$start',
    driveSessionId: 'd',
    type: type,
    startIndex: start,
    endIndex: end,
    startTime: t.add(Duration(seconds: start)),
    endTime: t.add(Duration(seconds: end)),
    startSpeedMps: 10,
    endSpeedMps: 18,
    maximumSpeedMps: 20,
    minimumSpeedMps: 10,
    distanceMeters: 100,
    confidence: 1,
    trafficContext: traffic,
    primaryOwner: owner,
    ownershipEligibility: {owner},
    contextTags: {},
    metadata: const {},
  );
}
