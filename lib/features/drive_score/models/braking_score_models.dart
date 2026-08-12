/// Explainable output for the Drive Score v1 braking and anticipation category.
///
/// This is an offline analysis value only. It is intentionally not a Hive
/// model and does not change the persisted DriveSession schema.
class BrakingScoreResult {
  final double totalScore;
  final double anticipationScore;
  final double brakingSeverityScore;
  final double brakeThrottleOscillationScore;
  final double stoppingQualityScore;
  final int analyzedDecelerationEventCount;
  final int analyzedStopEventCount;
  final int ignoredEventCount;
  final int emergencyOrUncertainEventCount;
  final int trafficAdjustedEventCount;
  final BrakingScoreDiagnostics diagnostics;

  const BrakingScoreResult({
    required this.totalScore,
    required this.anticipationScore,
    required this.brakingSeverityScore,
    required this.brakeThrottleOscillationScore,
    required this.stoppingQualityScore,
    required this.analyzedDecelerationEventCount,
    required this.analyzedStopEventCount,
    required this.ignoredEventCount,
    required this.emergencyOrUncertainEventCount,
    required this.trafficAdjustedEventCount,
    required this.diagnostics,
  });
}

class BrakingScoreDiagnostics {
  final bool anticipationNotApplicable;
  final bool severityNotApplicable;
  final bool oscillationNotApplicable;
  final bool stoppingQualityNotApplicable;
  final int brakeThrottleCycleCount;
  final String summary;

  const BrakingScoreDiagnostics({
    required this.anticipationNotApplicable,
    required this.severityNotApplicable,
    required this.oscillationNotApplicable,
    required this.stoppingQualityNotApplicable,
    required this.brakeThrottleCycleCount,
    required this.summary,
  });
}
