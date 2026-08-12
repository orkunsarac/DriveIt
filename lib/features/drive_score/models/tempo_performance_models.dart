import 'dart:core';

/// Runtime/offline result for only the 150-point Tempo & Performance category.
/// It deliberately is not persisted until the final Drive Score engine exists.
class TempoPerformanceScoreResult {
  final double totalScore;
  final double cruisingSpeedScore;
  final double maxSpeedScore;
  final double distanceTimeScore;
  final double averageCruisingSpeedKmh;
  final double validatedMaxSpeedKmh;
  final double totalDistanceKm;
  final Duration totalElapsedDuration;
  final Duration movingDuration;
  final Duration stoppedDuration;
  final int analyzedSampleCount;
  final int ignoredSampleCount;
  final TempoPerformanceDiagnostics diagnostics;

  const TempoPerformanceScoreResult({
    required this.totalScore,
    required this.cruisingSpeedScore,
    required this.maxSpeedScore,
    required this.distanceTimeScore,
    required this.averageCruisingSpeedKmh,
    required this.validatedMaxSpeedKmh,
    required this.totalDistanceKm,
    required this.totalElapsedDuration,
    required this.movingDuration,
    required this.stoppedDuration,
    required this.analyzedSampleCount,
    required this.ignoredSampleCount,
    required this.diagnostics,
  });
}

class TempoPerformanceDiagnostics {
  final bool sampleSufficient;
  final double confidence;
  final bool cruisingSpeedNotApplicable;
  final bool maxSpeedNotApplicable;
  final bool distanceTimeNotApplicable;
  final int validatedMaxSpeedSupportingSampleCount;
  final String summary;

  const TempoPerformanceDiagnostics({
    required this.sampleSufficient,
    required this.confidence,
    required this.cruisingSpeedNotApplicable,
    required this.maxSpeedNotApplicable,
    required this.distanceTimeNotApplicable,
    required this.validatedMaxSpeedSupportingSampleCount,
    required this.summary,
  });
}
