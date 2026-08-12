import 'package:driveit_project/features/drive_score/services/drive_phase_analyzer.dart';
import 'package:driveit_project/features/drive_score/services/tempo_performance_engine.dart';
import 'package:driveit_project/features/drive_score/models/tempo_performance_models.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = DrivePhaseAnalyzer();
  const engine = TempoPerformanceEngine();

  test(
    'stable 90 km/h drive has moving duration equal to elapsed duration',
    () {
      final result = score(
        List<double>.filled(31, 25),
        secondsBetween: 60,
        distancePerInterval: 1500,
      );

      expect(result.diagnostics.sampleSufficient, isTrue);
      expect(result.averageCruisingSpeedKmh, closeTo(90, .1));
      expect(result.movingDuration, result.totalElapsedDuration);
      expect(result.stoppedDuration, Duration.zero);
    },
  );

  test(
    'red-light stop leaves moving average intact but stays in elapsed time',
    () {
      final speeds = <double>[...List<double>.filled(11, 20), 0, 0, 0];
      final result = score(
        speeds,
        secondsBetween: 60,
        distancePerInterval: 1200,
        zeroSpeedDistance: 0,
      );

      expect(result.stoppedDuration, const Duration(minutes: 2));
      expect(
        result.totalElapsedDuration,
        result.movingDuration + result.stoppedDuration,
      );
      expect(result.averageCruisingSpeedKmh, greaterThan(65));
      final noStop = score(
        List<double>.filled(14, 20),
        secondsBetween: 60,
        distancePerInterval: 1200,
      );
      expect(result.distanceTimeScore, lessThan(noStop.distanceTimeScore));
    },
  );

  test(
    'stop-and-go keeps real low speed motion but excludes confirmed stops',
    () {
      final result = score(
        [0, 5, 8, 3, 0, 0, 0, 6, 2, 0, 0, 0, 7, 3, 0, 0, 0],
        secondsBetween: 30,
        distancePerInterval: 100,
        zeroSpeedDistance: 0,
      );

      expect(result.stoppedDuration, greaterThan(Duration.zero));
      expect(result.movingDuration, greaterThan(Duration.zero));
      expect(result.totalElapsedDuration, greaterThan(result.movingDuration));
    },
  );

  test('stationary GPS drift does not inflate moving duration', () {
    final result = score(
      List<double>.filled(8, 0),
      secondsBetween: 30,
      distancePerInterval: 0,
    );

    expect(result.movingDuration, Duration.zero);
    expect(result.averageCruisingSpeedKmh, 0);
  });

  test('isolated speed spike is excluded from validated maximum speed', () {
    final result = score(
      [27.8, 28, 61.1, 28, 27.8, 28, 28, 28],
      secondsBetween: 60,
      distancePerInterval: 1600,
    );

    expect(result.validatedMaxSpeedKmh, lessThan(110));
  });

  test('continuous high-speed samples are accepted as validated maximum', () {
    final result = score(
      [47.2, 49.4, 51.4, 52.8, 52.2, 50.8, 50, 50],
      secondsBetween: 60,
      distancePerInterval: 3000,
    );

    expect(result.validatedMaxSpeedKmh, closeTo(190.08, .2));
    expect(result.maxSpeedScore, greaterThan(25));
  });

  test('average cruising speed is time weighted for irregular timestamps', () {
    final result = scoreWithIntervals(
      [10, 10, 30, 30, 30, 30],
      intervals: [30, 30, 90, 90, 90],
      distancePerInterval: 1200,
    );

    // 6 km over 330 seconds = about 65.45 km/h. A sample average would be 84.
    expect(result.averageCruisingSpeedKmh, closeTo(65.45, .2));
  });

  test(
    'same moving pace with long stop has similar cruise but lower completion score',
    () {
      final withoutStop = score(
        List<double>.filled(21, 20),
        secondsBetween: 60,
        distancePerInterval: 1200,
      );
      final withStop = score(
        [...List<double>.filled(21, 20), 0, 0, 0, 0, 0],
        secondsBetween: 60,
        distancePerInterval: 1200,
        zeroSpeedDistance: 0,
      );

      expect(
        withStop.averageCruisingSpeedKmh,
        closeTo(withoutStop.averageCruisingSpeedKmh, 5),
      );
      expect(
        withStop.distanceTimeScore,
        lessThan(withoutStop.distanceTimeScore),
      );
    },
  );

  test('same distance completed more slowly lowers distance-time score', () {
    final faster = score(
      List<double>.filled(21, 20),
      secondsBetween: 60,
      distancePerInterval: 1000,
    );
    final slower = score(
      List<double>.filled(21, 20),
      secondsBetween: 90,
      distancePerInterval: 1000,
    );

    expect(slower.totalDistanceKm, closeTo(faster.totalDistanceKm, .001));
    expect(slower.distanceTimeScore, lessThan(faster.distanceTimeScore));
  });

  test(
    'short drive is explicitly insufficient and cannot earn a fake maximum',
    () {
      final result = score(
        [25, 25, 25],
        secondsBetween: 10,
        distancePerInterval: 250,
      );

      expect(result.diagnostics.sampleSufficient, isFalse);
      expect(result.totalScore, 0);
      expect(result.totalScore, lessThan(150));
    },
  );

  test('no movement is safe and bounded', () {
    final result = score(
      List<double>.filled(8, 0),
      secondsBetween: 30,
      distancePerInterval: 0,
    );

    expect(result.movingDuration, Duration.zero);
    expect(result.averageCruisingSpeedKmh, 0);
    expect(result.totalScore, inInclusiveRange(0, 150));
  });

  test('same canonical timeline produces identical bounded tempo result', () {
    final telemetry = buildPoints(
      [20, 20, 20, 0, 0, 0, 20, 20, 20, 20],
      intervals: List<int>.filled(9, 60),
      distancePerInterval: 1000,
      zeroSpeedDistance: 0,
    );
    final analysis = analyzer.analyze(
      driveSessionId: 'same',
      telemetry: telemetry,
    );
    final first = engine.score(analysis);
    final second = engine.score(analysis);

    expect(first.totalScore, second.totalScore);
    expect(first.totalScore, inInclusiveRange(0, 150));
    expect(first.cruisingSpeedScore, inInclusiveRange(0, 60));
    expect(first.maxSpeedScore, inInclusiveRange(0, 30));
    expect(first.distanceTimeScore, inInclusiveRange(0, 60));
  });
}

TempoPerformanceScoreResult score(
  List<double> speeds, {
  required int secondsBetween,
  required double distancePerInterval,
  double? zeroSpeedDistance,
}) => const TempoPerformanceEngine().score(
  const DrivePhaseAnalyzer().analyze(
    driveSessionId: 'tempo-test',
    telemetry: buildPoints(
      speeds,
      intervals: List<int>.filled(speeds.length - 1, secondsBetween),
      distancePerInterval: distancePerInterval,
      zeroSpeedDistance: zeroSpeedDistance,
    ),
  ),
);

TempoPerformanceScoreResult scoreWithIntervals(
  List<double> speeds, {
  required List<int> intervals,
  required double distancePerInterval,
}) => const TempoPerformanceEngine().score(
  const DrivePhaseAnalyzer().analyze(
    driveSessionId: 'irregular',
    telemetry: buildPoints(
      speeds,
      intervals: intervals,
      distancePerInterval: distancePerInterval,
    ),
  ),
);

List<CanonicalTelemetryPoint> buildPoints(
  List<double> speeds, {
  required List<int> intervals,
  required double distancePerInterval,
  double? zeroSpeedDistance,
}) {
  final start = DateTime.utc(2026, 1, 1, 12);
  var current = start;
  return List.generate(speeds.length, (index) {
    if (index > 0) {
      current = current.add(Duration(seconds: intervals[index - 1]));
    }
    final previousSpeed = index == 0 ? speeds[index] : speeds[index - 1];
    return CanonicalTelemetryPoint(
      latitude: 41 + index * .00001,
      longitude: 29 + index * .00001,
      timestamp: current,
      speedMps: speeds[index],
      headingDegrees: 0,
      altitudeMeters: 10,
      accuracyMeters: 5,
      distanceFromPreviousMeters: index == 0
          ? 0
          : speeds[index] == 0
          ? zeroSpeedDistance ?? distancePerInterval
          : distancePerInterval,
      accelerationMps2: index == 0
          ? 0
          : (speeds[index] - previousSpeed) / intervals[index - 1],
    );
  });
}
