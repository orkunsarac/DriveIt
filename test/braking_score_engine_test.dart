import 'package:driveit_project/features/drive_score/models/braking_score_models.dart';
import 'package:driveit_project/features/drive_score/services/braking_score_engine.dart';
import 'package:driveit_project/features/drive_score/services/drive_phase_analyzer.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = DrivePhaseAnalyzer();
  const scorer = BrakingScoreEngine();

  BrakingScoreResult score(List<double> speeds, {int seconds = 1}) =>
      scorer.score(
        analyzer.analyze(
          driveSessionId: 'braking-test',
          telemetry: points(speeds, secondsBetween: seconds),
        ),
      );

  test('anticipatory stop scores higher than last-moment concentration', () {
    final anticipatory = score([20, 17, 14, 10.5, 7, 3.5, 0, 0, 0, 0]);
    final late = score([20, 20, 19.5, 19, 8, 0, 0, 0, 0]);

    expect(anticipatory.anticipationScore, greaterThan(late.anticipationScore));
    expect(
      anticipatory.stoppingQualityScore,
      greaterThan(late.stoppingQualityScore),
    );
    expect(
      anticipatory.brakingSeverityScore,
      greaterThanOrEqualTo(late.brakingSeverityScore),
    );
  });

  test(
    'one emergency brake is uncertainty guarded and cannot collapse score',
    () {
      final result = score([25, 25, 20, 15, 10, 5, 0, 0, 0, 0]);

      expect(result.emergencyOrUncertainEventCount, greaterThanOrEqualTo(1));
      expect(result.brakingSeverityScore, greaterThan(60));
      expect(result.totalScore, greaterThan(220));
    },
  );

  test(
    'repeated hard braking carries a larger severity penalty than one event',
    () {
      final single = score([25, 25, 20, 15, 10, 8, 8, 8, 8, 8]);
      final repeated = score([
        25,
        25,
        20,
        15,
        10,
        10,
        15,
        20,
        25,
        25,
        20,
        15,
        10,
        10,
      ]);

      expect(
        repeated.brakingSeverityScore,
        lessThan(single.brakingSeverityScore),
      );
    },
  );

  test('stop-and-go suppresses brake-throttle oscillation penalty', () {
    final freeFlow = score([
      0,
      10,
      18,
      24,
      16,
      8,
      0,
      10,
      18,
      24,
      16,
      8,
      0,
      10,
      18,
      24,
      16,
      8,
      0,
    ]);
    final stopAndGo = score([
      0,
      4,
      8,
      3,
      0,
      6,
      1,
      0,
      5,
      0,
      7,
      1,
      0,
      6,
      1,
      0,
    ], seconds: 5);

    expect(
      stopAndGo.brakeThrottleOscillationScore,
      greaterThanOrEqualTo(freeFlow.brakeThrottleOscillationScore),
    );
  });

  test('repeated free-flow brake-throttle cycles lower oscillation score', () {
    final single = score([10, 14, 18, 22, 16, 10, 10, 10, 10, 10]);
    final repeated = score([
      10,
      14,
      18,
      22,
      16,
      10,
      14,
      18,
      22,
      16,
      10,
      14,
      18,
      22,
      16,
      10,
    ]);

    expect(
      repeated.brakeThrottleOscillationScore,
      lessThan(single.brakeThrottleOscillationScore),
    );
  });

  test('low speed stop-go creep is not scored as stopping quality', () {
    final result = score([0, 1.1, 0, .8, 0, 1, 0, 0, 0]);

    expect(result.analyzedStopEventCount, 0);
    expect(result.diagnostics.stoppingQualityNotApplicable, isTrue);
    expect(result.stoppingQualityScore, 40);
  });

  test(
    'corner overlap softens controlled deceleration without double penalty',
    () {
      final straight = scorer.score(
        analyzer.analyze(
          driveSessionId: 'straight',
          telemetry: points([20, 18, 16, 14, 12, 10, 8]),
        ),
      );
      final corner = scorer.score(
        analyzer.analyze(
          driveSessionId: 'corner',
          telemetry: points(
            [20, 18, 16, 14, 12, 10, 8],
            headings: [0, 5, 10, 15, 20, 25, 30],
            distances: List<double>.filled(7, 15),
          ),
        ),
      );

      expect(
        corner.brakingSeverityScore,
        greaterThanOrEqualTo(straight.brakingSeverityScore),
      );
    },
  );

  test('a no-braking cruise is not penalised by not-applicable components', () {
    final result = score(List<double>.filled(20, 22));

    expect(result.totalScore, 350);
    expect(result.diagnostics.anticipationNotApplicable, isTrue);
    expect(result.diagnostics.stoppingQualityNotApplicable, isTrue);
  });

  test('same Phase 2 result deterministically produces same bounded score', () {
    final analysis = analyzer.analyze(
      driveSessionId: 'deterministic',
      telemetry: points([20, 18, 16, 14, 12, 10, 8, 8, 12, 16, 20, 18, 14]),
    );
    final first = scorer.score(analysis);
    final second = scorer.score(analysis);

    expect(first.totalScore, second.totalScore);
    expect(first.anticipationScore, inInclusiveRange(0, 150));
    expect(first.brakingSeverityScore, inInclusiveRange(0, 100));
    expect(first.brakeThrottleOscillationScore, inInclusiveRange(0, 60));
    expect(first.stoppingQualityScore, inInclusiveRange(0, 40));
    expect(first.totalScore, inInclusiveRange(0, 350));
  });
}

List<CanonicalTelemetryPoint> points(
  List<double> speeds, {
  List<double>? headings,
  List<double>? distances,
  int secondsBetween = 1,
}) {
  final start = DateTime.utc(2026, 1, 1, 12);
  return List.generate(speeds.length, (index) {
    final previousSpeed = index == 0 ? speeds[index] : speeds[index - 1];
    return CanonicalTelemetryPoint(
      latitude: 41 + index * .00001,
      longitude: 29 + index * .00001,
      timestamp: start.add(Duration(seconds: index * secondsBetween)),
      speedMps: speeds[index],
      headingDegrees: headings?[index] ?? 0,
      altitudeMeters: 10,
      accuracyMeters: 5,
      distanceFromPreviousMeters: index == 0
          ? 0
          : distances?[index] ?? speeds[index] * secondsBetween,
      accelerationMps2: index == 0
          ? 0
          : (speeds[index] - previousSpeed) / secondsBetween,
    );
  });
}
