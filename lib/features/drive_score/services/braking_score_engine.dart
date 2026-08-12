import 'dart:math' as math;

import '../config/braking_score_calibration.dart';
import '../models/braking_score_models.dart';
import '../models/driving_analysis_models.dart';

/// Offline, deterministic scorer for only the 350-point Braking &
/// Anticipation category. It consumes Phase 2 events rather than detecting a
/// second, competing set of braking events from raw telemetry.
class BrakingScoreEngine {
  const BrakingScoreEngine();

  BrakingScoreResult score(DrivePhaseAnalysisResult analysis) {
    final decelerations = analysis
        .eventsOfType(DrivingEventType.deceleration)
        .where((event) => event.primaryOwner == EventOwnerDomain.braking)
        .toList(growable: false);
    final stops = analysis
        .eventsOfType(DrivingEventType.stop)
        .toList(growable: false);
    final corners = analysis
        .eventsOfType(DrivingEventType.corner)
        .toList(growable: false);

    var ignored = 0;
    var emergencyOrUncertain = 0;
    var trafficAdjusted = 0;
    final anticipationQualities = <_WeightedQuality>[];
    final severityPenalties = <double>[];
    final emergencyDecelerationIds = <String>{};

    for (final event in decelerations) {
      if (event.confidence <= 0 || event.duration <= Duration.zero) {
        ignored++;
        continue;
      }
      final isCorner = _hasCornerContext(event, corners);
      final trafficFactor = _trafficPenaltyFactor(event.trafficContext);
      if (trafficFactor < 1 || isCorner) trafficAdjusted++;
      final peakDeceleration = _peakDeceleration(analysis, event);
      final severityPenalty = _severityPenalty(peakDeceleration);
      final emergency =
          peakDeceleration >= BrakingScoreCalibration.hardBrakingMps2;
      if (emergency) {
        emergencyOrUncertain++;
        emergencyDecelerationIds.add(event.id);
      }
      final adjustedSeverityPenalty =
          severityPenalty *
          trafficFactor *
          (isCorner ? 1 - BrakingScoreCalibration.cornerPenaltySuppression : 1);
      severityPenalties.add(adjustedSeverityPenalty);
      anticipationQualities.add(
        _WeightedQuality(
          _anticipationQuality(analysis, event, isCorner: isCorner),
          _speedLossWeight(event),
        ),
      );
    }

    final anticipationNotApplicable = anticipationQualities.isEmpty;
    final anticipationScore = anticipationNotApplicable
        ? BrakingScoreCalibration.anticipationMaximumScore
        : BrakingScoreCalibration.anticipationMaximumScore *
              _weightedAverage(anticipationQualities);

    final severityNotApplicable = severityPenalties.isEmpty;
    final severityScore = severityNotApplicable
        ? BrakingScoreCalibration.severityMaximumScore
        : BrakingScoreCalibration.severityMaximumScore *
              (1 - _aggregateSeverityPenalty(severityPenalties));

    final cycles = _findBrakeThrottleCycles(analysis, decelerations);
    final oscillationNotApplicable = cycles.isEmpty;
    final oscillationPenalty = _oscillationPenalty(cycles);
    final oscillationScore = oscillationNotApplicable
        ? BrakingScoreCalibration.oscillationMaximumScore
        : BrakingScoreCalibration.oscillationMaximumScore *
              (1 - oscillationPenalty);
    trafficAdjusted += cycles.where((cycle) => cycle.trafficSuppressed).length;

    final stopQualities = <double>[];
    for (final stop in stops) {
      final quality = _stopQuality(
        analysis,
        stop,
        decelerations,
        emergencyDecelerationIds,
      );
      if (quality == null) {
        ignored++;
      } else {
        stopQualities.add(quality);
      }
    }
    final stoppingNotApplicable = stopQualities.isEmpty;
    final stoppingScore = stoppingNotApplicable
        ? BrakingScoreCalibration.stoppingQualityMaximumScore
        : BrakingScoreCalibration.stoppingQualityMaximumScore *
              _average(stopQualities);

    final total = _clamp(
      anticipationScore + severityScore + oscillationScore + stoppingScore,
      0,
      BrakingScoreCalibration.totalMaximumScore,
    );
    return BrakingScoreResult(
      totalScore: total,
      anticipationScore: _clamp(
        anticipationScore,
        0,
        BrakingScoreCalibration.anticipationMaximumScore,
      ),
      brakingSeverityScore: _clamp(
        severityScore,
        0,
        BrakingScoreCalibration.severityMaximumScore,
      ),
      brakeThrottleOscillationScore: _clamp(
        oscillationScore,
        0,
        BrakingScoreCalibration.oscillationMaximumScore,
      ),
      stoppingQualityScore: _clamp(
        stoppingScore,
        0,
        BrakingScoreCalibration.stoppingQualityMaximumScore,
      ),
      analyzedDecelerationEventCount: decelerations.length,
      analyzedStopEventCount: stopQualities.length,
      ignoredEventCount: ignored,
      emergencyOrUncertainEventCount: emergencyOrUncertain,
      trafficAdjustedEventCount: trafficAdjusted,
      diagnostics: BrakingScoreDiagnostics(
        anticipationNotApplicable: anticipationNotApplicable,
        severityNotApplicable: severityNotApplicable,
        oscillationNotApplicable: oscillationNotApplicable,
        stoppingQualityNotApplicable: stoppingNotApplicable,
        brakeThrottleCycleCount: cycles.length,
        summary: _summary(
          decelerationCount: decelerations.length,
          scoredStops: stopQualities.length,
          ignored: ignored,
          cycles: cycles.length,
          emergency: emergencyOrUncertain,
        ),
      ),
    );
  }

  double _anticipationQuality(
    DrivePhaseAnalysisResult analysis,
    DrivingEvent event, {
    required bool isCorner,
  }) {
    final features = analysis.features;
    final start = event.startIndex;
    final end = event.endIndex;
    final startSpeed = features[start].point.speedMps;
    final endSpeed = features[end].point.speedMps;
    final totalLoss = math.max(0.0, startSpeed - endSpeed);
    if (totalLoss <= 0) return .5;

    final earlyEnd = _indexAtFraction(features, start, end, .5);
    final lateStart = _indexAtFraction(
      features,
      start,
      end,
      BrakingScoreCalibration.anticipationLateLossStartFraction,
    );
    final earlyLoss = math.max(
      0.0,
      startSpeed - features[earlyEnd].point.speedMps,
    );
    final lateLoss = math.max(
      0.0,
      features[lateStart].point.speedMps - endSpeed,
    );
    final earlyQuality = _clamp(
      earlyLoss /
          totalLoss /
          BrakingScoreCalibration.anticipationEarlyLossTarget,
      0,
      1,
    );
    final lateRatio = lateLoss / totalLoss;
    final lateQuality =
        1 -
        _clamp(
          (lateRatio - .35) /
              (BrakingScoreCalibration.anticipationMaximumLateLossFraction -
                  .35),
          0,
          1,
        );
    final accelerations = <double>[];
    for (var index = start; index <= end; index++) {
      accelerations.add(analysis.features[index].smoothedAccelerationMps2);
    }
    final smoothness =
        1 -
        _clamp(
          _standardDeviation(accelerations) /
              BrakingScoreCalibration
                  .anticipationSmoothnessAccelerationDeviationMps2,
          0,
          1,
        );
    final lookback = features[start].point.timestamp.subtract(
      BrakingScoreCalibration.anticipationLookback,
    );
    final hasPreEventCoasting = features
        .take(start)
        .any(
          (feature) =>
              !feature.point.timestamp.isBefore(lookback) &&
              feature.smoothedAccelerationMps2 < -.08,
        );
    final coastingBonus = hasPreEventCoasting ? .08 : 0.0;
    final cornerSoftening = isCorner ? .10 : 0.0;
    final quality =
        .40 * _clamp(earlyQuality + coastingBonus + cornerSoftening, 0, 1) +
        .30 * smoothness +
        .30 * lateQuality;
    return _clamp(quality, 0, 1);
  }

  double _peakDeceleration(
    DrivePhaseAnalysisResult analysis,
    DrivingEvent event,
  ) {
    var peak = 0.0;
    for (var index = event.startIndex; index <= event.endIndex; index++) {
      peak = math.max(
        peak,
        math.max(
          -analysis.features[index].point.accelerationMps2,
          -analysis.features[index].smoothedAccelerationMps2,
        ),
      );
    }
    return peak;
  }

  double _severityPenalty(double decelerationMagnitudeMps2) {
    final normal = BrakingScoreCalibration.normalBrakingMps2;
    final noticeable = BrakingScoreCalibration.noticeableBrakingMps2;
    final strong = BrakingScoreCalibration.strongBrakingMps2;
    final hard = BrakingScoreCalibration.hardBrakingMps2;
    if (decelerationMagnitudeMps2 <= normal) return 0;
    if (decelerationMagnitudeMps2 <= noticeable) {
      return _lerp(
        0,
        .15,
        (decelerationMagnitudeMps2 - normal) / (noticeable - normal),
      );
    }
    if (decelerationMagnitudeMps2 <= strong) {
      return _lerp(
        .15,
        .35,
        (decelerationMagnitudeMps2 - noticeable) / (strong - noticeable),
      );
    }
    if (decelerationMagnitudeMps2 <= hard) {
      return _lerp(
        .35,
        .75,
        (decelerationMagnitudeMps2 - strong) / (hard - strong),
      );
    }
    return _lerp(.75, 1, (decelerationMagnitudeMps2 - hard) / hard);
  }

  double _aggregateSeverityPenalty(List<double> penalties) {
    final average = _average(penalties);
    if (penalties.length == 1) {
      return math.min(
        average,
        BrakingScoreCalibration.singleEmergencyPenaltyCap,
      );
    }
    return _clamp(
      average * BrakingScoreCalibration.repeatedSeverityPenaltyMultiplier,
      0,
      1,
    );
  }

  List<_BrakeThrottleCycle> _findBrakeThrottleCycles(
    DrivePhaseAnalysisResult analysis,
    List<DrivingEvent> decelerations,
  ) {
    final accelerations = analysis
        .eventsOfType(DrivingEventType.acceleration)
        .where((event) => event.primaryOwner == EventOwnerDomain.acceleration)
        .toList(growable: false);
    final cycles = <_BrakeThrottleCycle>[];
    for (final acceleration in accelerations) {
      final gain = acceleration.endSpeedMps - acceleration.startSpeedMps;
      if (gain < BrakingScoreCalibration.meaningfulBrakeThrottleSpeedGainMps) {
        continue;
      }
      for (final deceleration in decelerations) {
        if (deceleration.startTime.isBefore(acceleration.endTime)) continue;
        final gap = deceleration.startTime.difference(acceleration.endTime);
        final window = _brakeThrottleWindow(acceleration.maximumSpeedMps);
        if (gap > window) break;
        final loss = deceleration.startSpeedMps - deceleration.endSpeedMps;
        if (loss <= 0) continue;
        cycles.add(
          _BrakeThrottleCycle(
            speedGainMps: gain,
            peakDecelerationMps2: _peakDeceleration(analysis, deceleration),
            trafficSuppression: _oscillationTrafficSuppression(
              deceleration.trafficContext,
            ),
          ),
        );
        break;
      }
    }
    return cycles;
  }

  Duration _brakeThrottleWindow(double maximumSpeedMps) {
    final seconds =
        maximumSpeedMps < BrakingScoreCalibration.mediumSpeedThresholdMps
        ? BrakingScoreCalibration.lowSpeedBrakeThrottleWindowSeconds
        : maximumSpeedMps < BrakingScoreCalibration.highSpeedThresholdMps
        ? BrakingScoreCalibration.mediumSpeedBrakeThrottleWindowSeconds
        : BrakingScoreCalibration.highSpeedBrakeThrottleWindowSeconds;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  double _oscillationPenalty(List<_BrakeThrottleCycle> cycles) {
    if (cycles.isEmpty) return 0;
    final averageBehavior = _average(
      cycles.map(
        (cycle) =>
            .6 *
                _clamp(
                  cycle.speedGainMps /
                      (BrakingScoreCalibration
                              .meaningfulBrakeThrottleSpeedGainMps *
                          3),
                  0,
                  1,
                ) +
            .4 *
                _clamp(
                  cycle.peakDecelerationMps2 /
                      BrakingScoreCalibration
                          .brakeThrottleSeverityReferenceMps2,
                  0,
                  1,
                ),
      ),
    );
    final repeatFactor = cycles.length == 1
        ? BrakingScoreCalibration.singleCyclePenaltyMultiplier
        : _clamp(
                cycles.length /
                    BrakingScoreCalibration.repeatFrequencyReference,
                .45,
                1,
              ) *
              BrakingScoreCalibration.repeatedCyclePenaltyMultiplier;
    final meanSuppression = _average(
      cycles.map((cycle) => cycle.trafficSuppression),
    );
    return _clamp(averageBehavior * repeatFactor * (1 - meanSuppression), 0, 1);
  }

  double? _stopQuality(
    DrivePhaseAnalysisResult analysis,
    DrivingEvent stop,
    List<DrivingEvent> decelerations,
    Set<String> emergencyDecelerationIds,
  ) {
    final approachStart = _findApproachStart(analysis, stop.startIndex);
    if (approachStart == null) return null;
    final approachMaxSpeed = analysis.features
        .sublist(approachStart, stop.endIndex + 1)
        .map((feature) => feature.point.speedMps)
        .reduce(math.max);
    if (approachMaxSpeed <
        BrakingScoreCalibration.minimumMeaningfulStopApproachSpeedMps) {
      return null;
    }
    final linkedDeceleration = decelerations
        .where((event) {
          final gap = stop.startTime.difference(event.endTime).abs();
          return event.endIndex <= stop.startIndex &&
              gap <= BrakingScoreCalibration.stopAssociationGap;
        })
        .cast<DrivingEvent?>()
        .firstWhere((event) => event != null, orElse: () => null);
    if (linkedDeceleration != null &&
        emergencyDecelerationIds.contains(linkedDeceleration.id)) {
      return null;
    }
    final end = stop.endIndex;
    final totalLoss = math.max(
      0.0,
      analysis.features[approachStart].point.speedMps -
          analysis.features[end].point.speedMps,
    );
    if (totalLoss <= 0) return null;
    final finalStartTime = analysis.features[end].point.timestamp.subtract(
      BrakingScoreCalibration.stopFinalWindow,
    );
    var finalStart = approachStart;
    for (var index = approachStart; index <= end; index++) {
      if (!analysis.features[index].point.timestamp.isBefore(finalStartTime)) {
        finalStart = index;
        break;
      }
    }
    final finalLoss = math.max(
      0.0,
      analysis.features[finalStart].point.speedMps -
          analysis.features[end].point.speedMps,
    );
    final finalLossRatio = finalLoss / totalLoss;
    final gentleFinish =
        1 -
        _clamp(
          (finalLossRatio - .25) /
              (BrakingScoreCalibration.stopLateBrakingRatioTarget - .25),
          0,
          1,
        );
    final finalAccelerations = <double>[];
    for (var index = finalStart; index <= end; index++) {
      finalAccelerations.add(analysis.features[index].smoothedAccelerationMps2);
    }
    final smoothness =
        1 -
        _clamp(
          _standardDeviation(finalAccelerations) /
              BrakingScoreCalibration.stopSmoothnessAccelerationDeviationMps2,
          0,
          1,
        );
    final consistency = _clamp((gentleFinish + smoothness) / 2, 0, 1);
    return _clamp(
      .5 * gentleFinish + .25 * smoothness + .25 * consistency,
      0,
      1,
    );
  }

  int? _findApproachStart(DrivePhaseAnalysisResult analysis, int stopStart) {
    for (var index = stopStart; index >= 0; index--) {
      if (analysis.features[index].point.speedMps >=
          BrakingScoreCalibration.minimumMeaningfulStopApproachSpeedMps) {
        return index;
      }
    }
    return null;
  }

  bool _hasCornerContext(DrivingEvent event, List<DrivingEvent> corners) =>
      event.contextTags.contains(EventContextTag.cornering) ||
      event.overlappingEventIds.any(
        (id) => corners.any((corner) => corner.id == id),
      );

  double _trafficPenaltyFactor(TrafficContext context) {
    final denseSuppression =
        context.denseTrafficConfidence *
        BrakingScoreCalibration.denseTrafficPenaltySuppression;
    final stopGoSuppression =
        context.stopAndGoConfidence *
        BrakingScoreCalibration.stopAndGoPenaltySuppression;
    return _clamp(1 - math.max(denseSuppression, stopGoSuppression), 0, 1);
  }

  double _oscillationTrafficSuppression(TrafficContext context) {
    final confidence = math.max(
      context.denseTrafficConfidence,
      context.stopAndGoConfidence,
    );
    if (confidence <= 0) return 0;
    return _clamp(
      BrakingScoreCalibration.trafficOscillationSuppressionMinimum *
              confidence +
          (BrakingScoreCalibration.trafficOscillationSuppressionMaximum -
                  BrakingScoreCalibration
                      .trafficOscillationSuppressionMinimum) *
              context.stopAndGoConfidence,
      0,
      1,
    );
  }

  int _indexAtFraction(
    List<TelemetryFeature> features,
    int start,
    int end,
    double fraction,
  ) {
    final target = features[start].point.timestamp.add(
      Duration(
        milliseconds:
            (features[end].point.timestamp
                        .difference(features[start].point.timestamp)
                        .inMilliseconds *
                    fraction)
                .round(),
      ),
    );
    for (var index = start; index <= end; index++) {
      if (!features[index].point.timestamp.isBefore(target)) return index;
    }
    return end;
  }

  double _speedLossWeight(DrivingEvent event) =>
      math.max(1, event.startSpeedMps - event.endSpeedMps);

  double _weightedAverage(List<_WeightedQuality> qualities) {
    final totalWeight = qualities.fold<double>(
      0,
      (sum, value) => sum + value.weight,
    );
    if (totalWeight <= 0) return 1;
    return qualities.fold<double>(
          0,
          (sum, value) => sum + value.quality * value.weight,
        ) /
        totalWeight;
  }

  double _average(Iterable<double> values) {
    var sum = 0.0;
    var count = 0;
    for (final value in values) {
      sum += value;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0;
    final mean = _average(values);
    final variance = _average(
      values.map((value) => math.pow(value - mean, 2).toDouble()),
    );
    return math.sqrt(variance);
  }

  double _lerp(double from, double to, double t) =>
      from + (to - from) * _clamp(t, 0, 1);

  double _clamp(double value, double minimum, double maximum) =>
      value.clamp(minimum, maximum).toDouble();

  String _summary({
    required int decelerationCount,
    required int scoredStops,
    required int ignored,
    required int cycles,
    required int emergency,
  }) =>
      'Deceleration events: $decelerationCount; scored stops: $scoredStops; '
      'ignored: $ignored; brake-throttle cycles: $cycles; '
      'emergency/uncertain: $emergency.';
}

class _WeightedQuality {
  final double quality;
  final double weight;

  const _WeightedQuality(this.quality, this.weight);
}

class _BrakeThrottleCycle {
  final double speedGainMps;
  final double peakDecelerationMps2;
  final double trafficSuppression;

  const _BrakeThrottleCycle({
    required this.speedGainMps,
    required this.peakDecelerationMps2,
    required this.trafficSuppression,
  });

  bool get trafficSuppressed => trafficSuppression > 0;
}
