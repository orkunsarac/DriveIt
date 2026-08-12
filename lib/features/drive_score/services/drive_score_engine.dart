import '../models/drive_score_result.dart';
import '../config/drive_score_aggregation_calibration.dart';

class DriveScoreEngine {
  static const int algorithmVersion = 1;
  const DriveScoreEngine();
  DriveScoreResult aggregate(Map<String, DriveScoreCategoryStatus> categories) {
    final contributions = <String, DriveScoreCategoryContribution>{};
    var actualSufficientCount = 0;
    for (final entry in categories.entries) {
      final status = entry.value;
      final source = status.applicable && status.sampleSufficient
          ? DriveScoreContributionSource.actual
          : !status.applicable
          ? DriveScoreContributionSource.neutralNotApplicable
          : DriveScoreContributionSource.neutralInsufficient;
      final contribution = source == DriveScoreContributionSource.actual
          ? status.score
          : status.maximum *
                DriveScoreAggregationCalibration
                    .neutralCategoryContributionRatio;
      if (source == DriveScoreContributionSource.actual) {
        actualSufficientCount++;
      }
      contributions[entry.key] = DriveScoreCategoryContribution(
        status: status,
        contribution: contribution,
        source: source,
      );
    }
    final score = contributions.values
        .fold<double>(0, (sum, item) => sum + item.contribution)
        .clamp(0, 1000)
        .toDouble();
    return DriveScoreResult(
      totalScore: score,
      displayScore: score.round(),
      overallConfidence: (actualSufficientCount / categories.length)
          .clamp(0, 1)
          .toDouble(),
      algorithmVersion: algorithmVersion,
      categories: Map.unmodifiable(categories),
      contributions: Map.unmodifiable(contributions),
      diagnostics:
          'Actual scores plus neutral contributions for unavailable evidence.',
    );
  }
}
