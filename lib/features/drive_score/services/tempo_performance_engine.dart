import 'dart:math' as math;

import '../config/tempo_performance_calibration.dart';
import '../models/driving_analysis_models.dart';
import '../models/tempo_performance_models.dart';

/// Deterministic offline scorer for only Tempo & Performance (150 points).
///
/// It consumes canonical Phase 1 telemetry and the Phase 2 phase timeline.
/// No braking result or final Drive Score is an input to this category.
class TempoPerformanceEngine {
  const TempoPerformanceEngine();

  TempoPerformanceScoreResult score(DrivePhaseAnalysisResult analysis) {
    final features = analysis.features;
    if (features.length < 2) return _insufficientResult(features.length);

    var movingMicroseconds = 0;
    var stoppedMicroseconds = 0;
    var movingDistanceMeters = 0.0;
    var totalDistanceMeters = 0.0;
    var ignoredSamples = 0;

    for (var index = 0; index < features.length; index++) {
      totalDistanceMeters += features[index].point.distanceFromPreviousMeters;
      if (index == features.length - 1) continue;
      final current = features[index];
      final next = features[index + 1];
      final elapsed = next.point.timestamp.difference(current.point.timestamp);
      if (elapsed <= Duration.zero) {
        ignoredSamples++;
        continue;
      }
      if (_isStoppedInterval(analysis, index)) {
        stoppedMicroseconds += elapsed.inMicroseconds;
      } else {
        movingMicroseconds += elapsed.inMicroseconds;
        movingDistanceMeters += next.point.distanceFromPreviousMeters;
      }
    }

    final totalElapsed = features.last.point.timestamp.difference(
      features.first.point.timestamp,
    );
    final movingDuration = Duration(microseconds: movingMicroseconds);
    final stoppedDuration = Duration(microseconds: stoppedMicroseconds);
    final totalDistanceKm = totalDistanceMeters / 1000;
    final averageCruisingKmh = movingDuration <= Duration.zero
        ? 0.0
        : movingDistanceMeters /
              (movingDuration.inMicroseconds / Duration.microsecondsPerSecond) *
              3.6;
    final validatedMaximum = _validatedMaximumSpeed(analysis);
    final sampleSufficient = _isSampleSufficient(
      features.length,
      movingDuration,
      totalDistanceMeters,
    );
    final confidence = _confidence(
      features.length,
      movingDuration,
      totalDistanceMeters,
    );

    // An insufficient timeline has no score semantics yet. Returning zero
    // together with an explicit diagnostic prevents a short capture from
    // becoming a fake perfect (or a persisted bad) Drive Score contribution.
    if (!sampleSufficient) {
      return TempoPerformanceScoreResult(
        totalScore: 0,
        cruisingSpeedScore: 0,
        maxSpeedScore: 0,
        distanceTimeScore: 0,
        averageCruisingSpeedKmh: averageCruisingKmh,
        validatedMaxSpeedKmh: validatedMaximum.speedMps * 3.6,
        totalDistanceKm: totalDistanceKm,
        totalElapsedDuration: totalElapsed,
        movingDuration: movingDuration,
        stoppedDuration: stoppedDuration,
        analyzedSampleCount: features.length,
        ignoredSampleCount: ignoredSamples,
        diagnostics: TempoPerformanceDiagnostics(
          sampleSufficient: false,
          confidence: confidence,
          cruisingSpeedNotApplicable: movingDuration <= Duration.zero,
          maxSpeedNotApplicable:
              validatedMaximum.supportingSampleCount <
              TempoPerformanceCalibration.maxSpeedMinimumSupportingSamples,
          distanceTimeNotApplicable:
              totalElapsed <= Duration.zero || totalDistanceMeters <= 0,
          validatedMaxSpeedSupportingSampleCount:
              validatedMaximum.supportingSampleCount,
          summary:
              'Insufficient Tempo & Performance sample: '
              '${features.length} points, ${totalDistanceKm.toStringAsFixed(2)} km, '
              '${movingDuration.inSeconds}s moving.',
        ),
      );
    }

    final elapsedAverageKmh = totalElapsed <= Duration.zero
        ? 0.0
        : totalDistanceMeters /
              (totalElapsed.inMicroseconds / Duration.microsecondsPerSecond) *
              3.6;
    final cruisingScore = _scoreCurve(
      averageCruisingKmh,
      TempoPerformanceCalibration.cruisingSpeedCurve,
      TempoPerformanceCalibration.cruisingSpeedMaximumScore,
    );
    final maxScore =
        validatedMaximum.supportingSampleCount <
            TempoPerformanceCalibration.maxSpeedMinimumSupportingSamples
        ? 0.0
        : _scoreCurve(
            validatedMaximum.speedMps * 3.6,
            TempoPerformanceCalibration.maxSpeedCurve,
            TempoPerformanceCalibration.maxSpeedMaximumScore,
          );
    final distanceTimeScore = _scoreCurve(
      elapsedAverageKmh,
      TempoPerformanceCalibration.distanceTimeCurve,
      TempoPerformanceCalibration.distanceTimeMaximumScore,
    );
    final totalScore = _clamp(
      cruisingScore + maxScore + distanceTimeScore,
      0,
      TempoPerformanceCalibration.totalMaximumScore,
    );

    return TempoPerformanceScoreResult(
      totalScore: totalScore,
      cruisingSpeedScore: cruisingScore,
      maxSpeedScore: maxScore,
      distanceTimeScore: distanceTimeScore,
      averageCruisingSpeedKmh: averageCruisingKmh,
      validatedMaxSpeedKmh: validatedMaximum.speedMps * 3.6,
      totalDistanceKm: totalDistanceKm,
      totalElapsedDuration: totalElapsed,
      movingDuration: movingDuration,
      stoppedDuration: stoppedDuration,
      analyzedSampleCount: features.length,
      ignoredSampleCount: ignoredSamples,
      diagnostics: TempoPerformanceDiagnostics(
        sampleSufficient: true,
        confidence: confidence,
        cruisingSpeedNotApplicable: false,
        maxSpeedNotApplicable:
            validatedMaximum.supportingSampleCount <
            TempoPerformanceCalibration.maxSpeedMinimumSupportingSamples,
        distanceTimeNotApplicable: false,
        validatedMaxSpeedSupportingSampleCount:
            validatedMaximum.supportingSampleCount,
        summary:
            'Tempo sample accepted: ${features.length} points, '
            '${totalDistanceKm.toStringAsFixed(2)} km, '
            '${movingDuration.inSeconds}s moving, '
            '${stoppedDuration.inSeconds}s stopped.',
      ),
    );
  }

  bool _isStoppedInterval(DrivePhaseAnalysisResult analysis, int index) {
    final phase = _phaseAt(analysis.phaseTimeline, index);
    if (phase == DrivingPhase.stopped) return true;
    final current = analysis.features[index].point.speedMps;
    final next = analysis.features[index + 1].point.speedMps;
    // Phase 2 is authoritative for confirmed stops. This conservative fallback
    // only keeps two consecutive low canonical samples from inflating movement
    // while a stop candidate is still within debounce.
    return current <= TempoPerformanceCalibration.stoppedSpeedMps &&
        next <= TempoPerformanceCalibration.stoppedSpeedMps;
  }

  DrivingPhase _phaseAt(List<DrivingPhaseInterval> timeline, int index) {
    for (final interval in timeline) {
      if (index >= interval.startIndex && index <= interval.endIndex) {
        return interval.phase;
      }
    }
    return DrivingPhase.unknown;
  }

  _ValidatedMaximum _validatedMaximumSpeed(DrivePhaseAnalysisResult analysis) {
    final features = analysis.features;
    var bestSpeed = 0.0;
    var bestSupportingCount = 0;
    for (var index = 0; index < features.length; index++) {
      final speed = features[index].point.speedMps;
      if (!speed.isFinite || speed < 0) continue;
      var supportingCount = 1;
      for (final neighbour in <int>[index - 1, index + 1]) {
        if (neighbour < 0 || neighbour >= features.length) continue;
        final neighbourSpeed = features[neighbour].point.speedMps;
        if ((neighbourSpeed - speed).abs() <=
            TempoPerformanceCalibration.maxSpeedNeighbourToleranceMps) {
          supportingCount++;
        }
      }
      if (supportingCount <
          TempoPerformanceCalibration.maxSpeedMinimumSupportingSamples) {
        continue;
      }
      if (speed > bestSpeed) {
        bestSpeed = speed;
        bestSupportingCount = supportingCount;
      }
    }
    return _ValidatedMaximum(bestSpeed, bestSupportingCount);
  }

  bool _isSampleSufficient(
    int sampleCount,
    Duration movingDuration,
    double totalDistanceMeters,
  ) =>
      sampleCount >= TempoPerformanceCalibration.minimumReliableSampleCount &&
      movingDuration >= TempoPerformanceCalibration.minimumMovingDuration &&
      totalDistanceMeters >=
          TempoPerformanceCalibration.minimumReliableDistanceMeters;

  double _confidence(
    int sampleCount,
    Duration movingDuration,
    double totalDistanceMeters,
  ) {
    final sample =
        sampleCount / TempoPerformanceCalibration.minimumReliableSampleCount;
    final duration =
        movingDuration.inMicroseconds /
        TempoPerformanceCalibration.minimumMovingDuration.inMicroseconds;
    final distance =
        totalDistanceMeters /
        TempoPerformanceCalibration.minimumReliableDistanceMeters;
    return _clamp(math.min(sample, math.min(duration, distance)), 0, 1);
  }

  double _scoreCurve(
    double value,
    List<List<double>> curve,
    double maximumScore,
  ) {
    if (value <= curve.first.first) return 0;
    for (var index = 1; index < curve.length; index++) {
      final before = curve[index - 1];
      final after = curve[index];
      if (value <= after.first) {
        final fraction = (value - before.first) / (after.first - before.first);
        return _clamp(
          maximumScore * (before.last + (after.last - before.last) * fraction),
          0,
          maximumScore,
        );
      }
    }
    return maximumScore;
  }

  TempoPerformanceScoreResult _insufficientResult(int sampleCount) =>
      TempoPerformanceScoreResult(
        totalScore: 0,
        cruisingSpeedScore: 0,
        maxSpeedScore: 0,
        distanceTimeScore: 0,
        averageCruisingSpeedKmh: 0,
        validatedMaxSpeedKmh: 0,
        totalDistanceKm: 0,
        totalElapsedDuration: Duration.zero,
        movingDuration: Duration.zero,
        stoppedDuration: Duration.zero,
        analyzedSampleCount: sampleCount,
        ignoredSampleCount: 0,
        diagnostics: const TempoPerformanceDiagnostics(
          sampleSufficient: false,
          confidence: 0,
          cruisingSpeedNotApplicable: true,
          maxSpeedNotApplicable: true,
          distanceTimeNotApplicable: true,
          validatedMaxSpeedSupportingSampleCount: 0,
          summary: 'Insufficient telemetry for Tempo & Performance.',
        ),
      );

  double _clamp(double value, double minimum, double maximum) =>
      value.clamp(minimum, maximum).toDouble();
}

class _ValidatedMaximum {
  final double speedMps;
  final int supportingSampleCount;

  const _ValidatedMaximum(this.speedMps, this.supportingSampleCount);
}
