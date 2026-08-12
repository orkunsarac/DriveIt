import 'driving_analysis_models.dart';

class DrivingSmoothnessScoreResult {
  final double totalScore;
  final bool applicable;
  final bool sampleSufficient;
  final int analyzedCruiseCount;
  final int ignoredCruiseCount;
  final Duration totalEligibleCruiseDuration;
  final Duration longestStableCruiseDuration;
  final double averageCruiseStability;
  final String diagnostics;
  const DrivingSmoothnessScoreResult({
    required this.totalScore,
    required this.applicable,
    required this.sampleSufficient,
    required this.analyzedCruiseCount,
    required this.ignoredCruiseCount,
    required this.totalEligibleCruiseDuration,
    required this.longestStableCruiseDuration,
    required this.averageCruiseStability,
    required this.diagnostics,
  });
}

class AccelerationPerformanceScoreResult {
  final double totalScore;
  final double rawAccelerationScore;
  final double throttleApplicationScore;
  final double settlingScore;
  final bool applicable;
  final bool sampleSufficient;
  final int analyzedAccelerationCount;
  final int ignoredAccelerationCount;
  final String diagnostics;
  const AccelerationPerformanceScoreResult({
    required this.totalScore,
    required this.rawAccelerationScore,
    required this.throttleApplicationScore,
    required this.settlingScore,
    required this.applicable,
    required this.sampleSufficient,
    required this.analyzedAccelerationCount,
    required this.ignoredAccelerationCount,
    required this.diagnostics,
  });
}

enum DrivingTransitionType {
  cruiseDecelCruise,
  cruiseCornerCruise,
  accelerationCruise,
}

class DrivingTransition {
  final DrivingTransitionType type;
  final String sourceEventId;
  final String intermediateEventId;
  final String targetEventId;
  final double quality;
  final TrafficContext trafficContext;
  const DrivingTransition({
    required this.type,
    required this.sourceEventId,
    required this.intermediateEventId,
    required this.targetEventId,
    required this.quality,
    required this.trafficContext,
  });
}

class TransitionControlScoreResult {
  final double totalScore;
  final double cruiseDecelCruiseScore;
  final double cruiseCornerCruiseScore;
  final double accelerationCruiseScore;
  final bool applicable;
  final bool sampleSufficient;
  final int analyzedTransitionCount;
  final Map<DrivingTransitionType, int> transitionTypeCounts;
  final List<DrivingTransition> transitions;
  final String diagnostics;
  const TransitionControlScoreResult({
    required this.totalScore,
    required this.cruiseDecelCruiseScore,
    required this.cruiseCornerCruiseScore,
    required this.accelerationCruiseScore,
    required this.applicable,
    required this.sampleSufficient,
    required this.analyzedTransitionCount,
    required this.transitionTypeCounts,
    required this.transitions,
    required this.diagnostics,
  });
}
