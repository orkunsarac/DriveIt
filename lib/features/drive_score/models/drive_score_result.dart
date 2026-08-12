enum DriveScoreContributionSource {
  actual,
  neutralNotApplicable,
  neutralInsufficient,
}

class DriveScoreCategoryStatus {
  final double score, maximum;
  final bool applicable, sampleSufficient;
  const DriveScoreCategoryStatus({
    required this.score,
    required this.maximum,
    required this.applicable,
    required this.sampleSufficient,
  });
}

class DriveScoreCategoryContribution {
  final DriveScoreCategoryStatus status;
  final double contribution;
  final DriveScoreContributionSource source;
  const DriveScoreCategoryContribution({
    required this.status,
    required this.contribution,
    required this.source,
  });
}

class DriveScoreResult {
  final double totalScore, overallConfidence;
  final int displayScore, algorithmVersion;
  final Map<String, DriveScoreCategoryStatus> categories;
  final Map<String, DriveScoreCategoryContribution> contributions;
  final String diagnostics;
  const DriveScoreResult({
    required this.totalScore,
    required this.displayScore,
    required this.overallConfidence,
    required this.algorithmVersion,
    required this.categories,
    required this.contributions,
    required this.diagnostics,
  });
}
