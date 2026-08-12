import 'dart:math' as math;

import '../config/cornering_score_calibration.dart';
import '../models/cornering_score_models.dart';
import '../models/driving_analysis_models.dart';

class CorneringScoreEngine {
  const CorneringScoreEngine();

  CorneringPerformanceScoreResult score(DrivePhaseAnalysisResult analysis) {
    final contributions = <CornerScoreContribution>[];
    var ignored = 0;
    var lowConfidence = 0;
    for (final corner in analysis.eventsOfType(DrivingEventType.corner)) {
      final contribution = _contribution(analysis, corner);
      if (contribution == null) {
        ignored++;
        if (corner.confidence <
            CorneringScoreCalibration.minimumCornerConfidence) {
          lowConfidence++;
        }
      } else {
        contributions.add(contribution);
      }
    }
    if (contributions.isEmpty) {
      return CorneringPerformanceScoreResult(
        totalScore: 0,
        speedRetentionScore: 0,
        entryQualityScore: 0,
        exitQualityScore: 0,
        stabilityScore: 0,
        analyzedCornerCount: 0,
        ignoredCornerCount: ignored,
        lowConfidenceCornerCount: lowConfidence,
        averageCornerQuality: 0,
        applicable: false,
        sampleSufficient: false,
        contributions: const [],
        diagnostics: 'No meaningful performance corner was available.',
      );
    }
    double weighted(double Function(CornerScoreContribution) select) {
      final weights = contributions.map(_weight).toList(growable: false);
      final total = weights.fold<double>(0, (sum, value) => sum + value);
      return List<double>.generate(
            contributions.length,
            (index) => select(contributions[index]) * weights[index],
          ).fold<double>(0, (sum, value) => sum + value) /
          total;
    }

    final retention = weighted((item) => item.speedRetentionQuality);
    final entry = weighted((item) => item.entryQuality);
    final exit = weighted((item) => item.exitQuality);
    final stability = weighted((item) => item.stabilityQuality);
    final retentionScore =
        retention * CorneringScoreCalibration.speedRetentionMaximumScore;
    final entryScore =
        entry * CorneringScoreCalibration.entryQualityMaximumScore;
    final exitScore = exit * CorneringScoreCalibration.exitQualityMaximumScore;
    final stabilityScore =
        stability * CorneringScoreCalibration.stabilityMaximumScore;
    return CorneringPerformanceScoreResult(
      totalScore: _clamp(
        retentionScore + entryScore + exitScore + stabilityScore,
        0,
        CorneringScoreCalibration.totalMaximumScore,
      ),
      speedRetentionScore: retentionScore,
      entryQualityScore: entryScore,
      exitQualityScore: exitScore,
      stabilityScore: stabilityScore,
      analyzedCornerCount: contributions.length,
      ignoredCornerCount: ignored,
      lowConfidenceCornerCount: lowConfidence,
      averageCornerQuality: (retention + entry + exit + stability) / 4,
      applicable: true,
      sampleSufficient: contributions.length >= 2,
      contributions: List.unmodifiable(contributions),
      diagnostics:
          'Analyzed ${contributions.length} corner event(s); ignored $ignored.',
    );
  }

  CornerScoreContribution? _contribution(
    DrivePhaseAnalysisResult analysis,
    DrivingEvent event,
  ) {
    if (event.primaryOwner != EventOwnerDomain.cornering ||
        event.confidence < CorneringScoreCalibration.minimumCornerConfidence ||
        event.distanceMeters <
            CorneringScoreCalibration.minimumCornerDistanceMeters) {
      return null;
    }
    final headingChange = event.metadata['totalHeadingChangeDegrees'] ?? 0;
    if (headingChange < CorneringScoreCalibration.minimumHeadingChangeDegrees) {
      return null;
    }
    final features = analysis.features;
    final apex =
        (event.metadata['apexIndex'] ??
                ((event.startIndex + event.endIndex) / 2))
            .round()
            .clamp(event.startIndex, event.endIndex)
            .toInt();
    final entryEnd = math.max(
      event.startIndex,
      event.startIndex + ((apex - event.startIndex) ~/ 2),
    );
    final exitStart = math.min(
      event.endIndex,
      apex + ((event.endIndex - apex) ~/ 2),
    );
    final entry = _medianSpeed(features, event.startIndex, entryEnd);
    final apexSpeed = _medianSpeed(
      features,
      math.max(event.startIndex, apex - 1),
      math.min(event.endIndex, apex + 1),
    );
    final recoveryEnd = _recoveryEnd(features, event.endIndex);
    final exit = _medianSpeed(features, exitStart, recoveryEnd);
    if (entry < CorneringScoreCalibration.minimumEntrySpeedMps) return null;
    final trafficConfidence = math.max(
      event.trafficContext.denseTrafficConfidence,
      event.trafficContext.stopAndGoConfidence,
    );
    if (trafficConfidence >=
            CorneringScoreCalibration.trafficExclusionConfidence &&
        entry < CorneringScoreCalibration.trafficLowSpeedExclusionMps) {
      return null;
    }
    final radians = headingChange * math.pi / 180;
    final radius = radians <= 0
        ? CorneringScoreCalibration.wideRadiusMeters
        : event.distanceMeters / radians;
    final sharpness = _clamp(
      .55 * ((headingChange - 15) / 75) +
          .45 *
              ((CorneringScoreCalibration.wideRadiusMeters - radius) /
                  (CorneringScoreCalibration.wideRadiusMeters -
                      CorneringScoreCalibration.tightRadiusMeters)),
      0,
      1,
    );
    final actualLoss = _clamp((entry - apexSpeed) / entry, 0, 1);
    final expectedLoss = _lerp(
      CorneringScoreCalibration.wideCornerExpectedLoss,
      CorneringScoreCalibration.tightCornerExpectedLoss,
      sharpness,
    );
    var retention =
        1 -
        _clamp(
          (actualLoss - expectedLoss) /
              CorneringScoreCalibration.retentionExtraLossTolerance,
          0,
          1,
        );
    final trafficSoftened = trafficConfidence > 0;
    if (trafficSoftened) {
      retention = _lerp(
        retention,
        1,
        trafficConfidence * CorneringScoreCalibration.trafficRetentionSoftening,
      );
    }
    final entryProfile = _speeds(features, event.startIndex, apex);
    final entryVariation = _normalisedVariation(entryProfile, entry);
    // This measures profile stability, not braking force; braking magnitude remains owned by Phase 3.
    final entryQuality =
        1 -
        _clamp(
          entryVariation / CorneringScoreCalibration.entryVariationTolerance,
          0,
          1,
        );
    final recoveryRatio = _clamp(exit / entry, 0, 1.1);
    final exitQuality = _clamp(
      recoveryRatio / CorneringScoreCalibration.exitRecoveryTarget,
      0,
      1,
    );
    final cornerSpeeds = _speeds(features, event.startIndex, event.endIndex);
    final stability =
        1 -
        _clamp(
          _normalisedVariation(cornerSpeeds, entry) /
              CorneringScoreCalibration.stabilityVarianceTolerance,
          0,
          1,
        );
    return CornerScoreContribution(
      cornerEventId: event.id,
      entrySpeedKmh: entry * 3.6,
      apexSpeedKmh: apexSpeed * 3.6,
      exitSpeedKmh: exit * 3.6,
      headingChangeDegrees: headingChange,
      estimatedRadiusMeters: radius,
      sharpness: sharpness,
      confidence: event.confidence,
      speedRetentionQuality: retention,
      entryQuality: entryQuality,
      exitQuality: exitQuality,
      stabilityQuality: stability,
      overlapEventIds: List.unmodifiable(event.overlappingEventIds),
      trafficSoftened: trafficSoftened,
    );
  }

  int _recoveryEnd(List<TelemetryFeature> features, int end) {
    final deadline = features[end].point.timestamp.add(
      CorneringScoreCalibration.exitRecoveryWindow,
    );
    var result = end;
    for (var index = end + 1; index < features.length; index++) {
      if (features[index].point.timestamp.isAfter(deadline)) break;
      result = index;
    }
    return result;
  }

  List<double> _speeds(List<TelemetryFeature> features, int start, int end) => [
    for (var index = start; index <= end; index++)
      features[index].point.speedMps,
  ];

  double _medianSpeed(List<TelemetryFeature> features, int start, int end) {
    final speeds = _speeds(features, start, end)..sort();
    final middle = speeds.length ~/ 2;
    return speeds.length.isOdd
        ? speeds[middle]
        : (speeds[middle - 1] + speeds[middle]) / 2;
  }

  double _normalisedVariation(List<double> values, double reference) {
    if (values.length < 2 || reference <= 0) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    var squaredDifferenceSum = 0.0;
    for (final value in values) {
      final difference = value - mean;
      squaredDifferenceSum += difference * difference;
    }
    final variance = squaredDifferenceSum / values.length;
    return math.sqrt(variance) / reference;
  }

  double _weight(CornerScoreContribution contribution) => math.min(
    CorneringScoreCalibration.maximumEventWeight,
    math.max(
      .25,
      contribution.confidence *
          (.5 + contribution.sharpness) *
          (contribution.headingChangeDegrees / 30),
    ),
  );

  double _lerp(double a, double b, double t) => a + (b - a) * _clamp(t, 0, 1);
  double _clamp(double value, double min, double max) =>
      value.clamp(min, max).toDouble();
}
