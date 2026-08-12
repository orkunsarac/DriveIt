class CorneringPerformanceScoreResult {
  final double totalScore;
  final double speedRetentionScore;
  final double entryQualityScore;
  final double exitQualityScore;
  final double stabilityScore;
  final int analyzedCornerCount;
  final int ignoredCornerCount;
  final int lowConfidenceCornerCount;
  final double averageCornerQuality;
  final bool applicable;
  final bool sampleSufficient;
  final List<CornerScoreContribution> contributions;
  final String diagnostics;

  const CorneringPerformanceScoreResult({
    required this.totalScore,
    required this.speedRetentionScore,
    required this.entryQualityScore,
    required this.exitQualityScore,
    required this.stabilityScore,
    required this.analyzedCornerCount,
    required this.ignoredCornerCount,
    required this.lowConfidenceCornerCount,
    required this.averageCornerQuality,
    required this.applicable,
    required this.sampleSufficient,
    required this.contributions,
    required this.diagnostics,
  });
}

class CornerScoreContribution {
  final String cornerEventId;
  final double entrySpeedKmh;
  final double apexSpeedKmh;
  final double exitSpeedKmh;
  final double headingChangeDegrees;
  final double estimatedRadiusMeters;
  final double sharpness;
  final double confidence;
  final double speedRetentionQuality;
  final double entryQuality;
  final double exitQuality;
  final double stabilityQuality;
  final List<String> overlapEventIds;
  final bool trafficSoftened;

  const CornerScoreContribution({
    required this.cornerEventId,
    required this.entrySpeedKmh,
    required this.apexSpeedKmh,
    required this.exitSpeedKmh,
    required this.headingChangeDegrees,
    required this.estimatedRadiusMeters,
    required this.sharpness,
    required this.confidence,
    required this.speedRetentionQuality,
    required this.entryQuality,
    required this.exitQuality,
    required this.stabilityQuality,
    required this.overlapEventIds,
    required this.trafficSoftened,
  });
}
