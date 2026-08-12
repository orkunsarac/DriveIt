class EnduranceScoreResult {
  final double totalScore,
      distanceKm,
      distancePotential,
      sustainedQualityFactor,
      qualityConfidence;
  final bool applicable, sampleSufficient;
  final String diagnostics;
  const EnduranceScoreResult({
    required this.totalScore,
    required this.distanceKm,
    required this.distancePotential,
    required this.sustainedQualityFactor,
    required this.qualityConfidence,
    required this.applicable,
    required this.sampleSufficient,
    required this.diagnostics,
  });
}
