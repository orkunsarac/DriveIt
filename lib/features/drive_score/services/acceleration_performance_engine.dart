import 'dart:math' as math;

import '../config/acceleration_performance_calibration.dart';
import '../models/driving_analysis_models.dart';
import '../models/flow_acceleration_transition_models.dart';

class AccelerationPerformanceEngine {
  const AccelerationPerformanceEngine();
  AccelerationPerformanceScoreResult score(DrivePhaseAnalysisResult analysis) {
    final events = <DrivingEvent>[];
    var ignored = 0;
    for (final e in analysis.eventsOfType(DrivingEventType.acceleration)) {
      final traffic = math.max(
        e.trafficContext.denseTrafficConfidence,
        e.trafficContext.stopAndGoConfidence,
      );
      if (e.primaryOwner != EventOwnerDomain.acceleration ||
          e.endSpeedMps - e.startSpeedMps <
              AccelerationPerformanceCalibration.minimumSpeedGainMps ||
          (traffic >=
                  AccelerationPerformanceCalibration
                      .trafficExclusionConfidence &&
              e.maximumSpeedMps <
                  AccelerationPerformanceCalibration
                      .lowSpeedTrafficExclusionMps)) {
        ignored++;
      } else {
        events.add(e);
      }
    }
    if (events.isEmpty) {
      return AccelerationPerformanceScoreResult(
        totalScore: 0,
        rawAccelerationScore: 0,
        throttleApplicationScore: 0,
        settlingScore: 0,
        applicable: false,
        sampleSufficient: false,
        analyzedAccelerationCount: 0,
        ignoredAccelerationCount: ignored,
        diagnostics: 'No meaningful acceleration event.',
      );
    }
    double aggregate(double Function(DrivingEvent) f) =>
        events.map(f).reduce((a, b) => a + b) / events.length;
    final raw = aggregate(
      (e) => _clamp(
        ((e.endSpeedMps - e.startSpeedMps) / e.duration.inMilliseconds * 1000) /
            AccelerationPerformanceCalibration.rawAccelerationReferenceMps2,
      ),
    );
    final throttle = aggregate(
      (e) =>
          1 -
          _clamp(
            _accelerationVariance(analysis, e) /
                AccelerationPerformanceCalibration.throttleVariationTolerance,
          ),
    );
    final settle = aggregate((e) => _settling(analysis, e));
    final rawScore = raw * AccelerationPerformanceCalibration.rawMaximumScore,
        throttleScore =
            throttle * AccelerationPerformanceCalibration.throttleMaximumScore,
        settlingScore =
            settle * AccelerationPerformanceCalibration.settlingMaximumScore;
    return AccelerationPerformanceScoreResult(
      totalScore: rawScore + throttleScore + settlingScore,
      rawAccelerationScore: rawScore,
      throttleApplicationScore: throttleScore,
      settlingScore: settlingScore,
      applicable: true,
      sampleSufficient: events.length >= 2,
      analyzedAccelerationCount: events.length,
      ignoredAccelerationCount: ignored,
      diagnostics: 'Analyzed ${events.length} acceleration event(s).',
    );
  }

  double _accelerationVariance(DrivePhaseAnalysisResult a, DrivingEvent e) {
    final v = a.features
        .sublist(e.startIndex, e.endIndex + 1)
        .map((f) => f.smoothedAccelerationMps2)
        .toList();
    final m = v.reduce((x, y) => x + y) / v.length;
    return v.fold<double>(0, (s, x) => s + (x - m) * (x - m)) / v.length;
  }

  double _settling(DrivePhaseAnalysisResult a, DrivingEvent e) {
    final deadline = e.endTime.add(
      AccelerationPerformanceCalibration.settlingWindow,
    );
    final v = a.features
        .where(
          (f) => f.index > e.endIndex && !f.point.timestamp.isAfter(deadline),
        )
        .map((f) => f.point.speedMps)
        .toList();
    if (v.length < 2) return 0;
    final m = v.reduce((x, y) => x + y) / v.length;
    final variance =
        v.fold<double>(0, (s, x) => s + (x - m) * (x - m)) / v.length;
    return 1 -
        _clamp(
          math.sqrt(variance) /
              AccelerationPerformanceCalibration.settlingVariationToleranceMps,
        );
  }

  double _clamp(double x) => x.clamp(0, 1).toDouble();
}
