class FlowReport {
  final double score;

  final double cruiseSpeed;

  final double speedStability;

  final int oscillationCount;

  const FlowReport({
    required this.score,
    required this.cruiseSpeed,
    required this.speedStability,
    required this.oscillationCount,
  });
}