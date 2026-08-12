import 'dart:math' as math;

import '../config/driving_smoothness_calibration.dart';
import '../models/driving_analysis_models.dart';
import '../models/flow_acceleration_transition_models.dart';

class DrivingSmoothnessEngine {
  const DrivingSmoothnessEngine();

  DrivingSmoothnessScoreResult score(DrivePhaseAnalysisResult analysis) {
    final eligible = <DrivingEvent>[];
    var ignored = 0;
    for (final event in analysis.eventsOfType(DrivingEventType.cruise)) {
      final traffic = math.max(
        event.trafficContext.denseTrafficConfidence,
        event.trafficContext.stopAndGoConfidence,
      );
      if (event.primaryOwner != EventOwnerDomain.cruising ||
          event.duration <
              DrivingSmoothnessCalibration.minimumEligibleDuration ||
          event.maximumSpeedMps <
              DrivingSmoothnessCalibration.minimumCruiseSpeedMps ||
          traffic >= DrivingSmoothnessCalibration.trafficExclusionConfidence) {
        ignored++;
      } else {
        eligible.add(event);
      }
    }
    if (eligible.isEmpty) {
      return DrivingSmoothnessScoreResult(
        totalScore: 0,
        applicable: false,
        sampleSufficient: false,
        analyzedCruiseCount: 0,
        ignoredCruiseCount: ignored,
        totalEligibleCruiseDuration: Duration.zero,
        longestStableCruiseDuration: Duration.zero,
        averageCruiseStability: 0,
        diagnostics: 'No eligible free-flow cruise event.',
      );
    }
    var micros = 0;
    var longest = Duration.zero;
    var weightedStability = 0.0;
    for (final event in eligible) {
      micros += event.duration.inMicroseconds;
      if (event.duration > longest) {
        longest = event.duration;
      }
      final variance = _variance(analysis, event);
      final stability = _clamp(
        1 -
            variance /
                DrivingSmoothnessCalibration.stabilityVarianceToleranceMps2,
      );
      weightedStability += stability * event.duration.inMicroseconds;
    }
    final total = Duration(microseconds: micros);
    final stability = weightedStability / micros;
    final durationQuality = _curve(
      total,
      DrivingSmoothnessCalibration.minimumEligibleDuration,
      DrivingSmoothnessCalibration.strongDuration,
      DrivingSmoothnessCalibration.maximumDuration,
    );
    return DrivingSmoothnessScoreResult(
      totalScore:
          _clamp(
            (.55 * durationQuality + .45 * stability) *
                DrivingSmoothnessCalibration.maximumScore,
          ) *
          100,
      applicable: true,
      sampleSufficient:
          total >= DrivingSmoothnessCalibration.sampleSufficientDuration,
      analyzedCruiseCount: eligible.length,
      ignoredCruiseCount: ignored,
      totalEligibleCruiseDuration: total,
      longestStableCruiseDuration: longest,
      averageCruiseStability: stability,
      diagnostics: 'Eligible free-flow cruise: ${total.inSeconds}s.',
    );
  }

  double _variance(DrivePhaseAnalysisResult a, DrivingEvent e) {
    final values = a.features
        .sublist(e.startIndex, e.endIndex + 1)
        .map((f) => f.point.speedMps)
        .toList();
    final mean = values.reduce((x, y) => x + y) / values.length;
    return values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
        values.length;
  }

  double _curve(Duration d, Duration min, Duration strong, Duration max) {
    final x = d.inMicroseconds.toDouble();
    if (x <= min.inMicroseconds) {
      return 0;
    }
    if (x <= strong.inMicroseconds) {
      return .75 *
          (x - min.inMicroseconds) /
          (strong.inMicroseconds - min.inMicroseconds);
    }
    return .75 +
        .25 *
            _clamp(
              (x - strong.inMicroseconds) /
                  (max.inMicroseconds - strong.inMicroseconds),
            );
  }

  double _clamp(double x) => x.clamp(0, 1).toDouble();
}
