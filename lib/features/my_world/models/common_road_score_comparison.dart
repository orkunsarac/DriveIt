import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../../../features/drive_score/models/drive_score_result.dart';
import 'common_road_match.dart';

enum CommonRoadScoreComparisonOutcome {
  firstWins,
  secondWins,
  noMeaningfulDifference,
  notEligible,
  insufficientTelemetry,
  mappingFailed,
  unsupportedAlgorithmVersion,
  calculationFailed,
}

class CommonRoadScoreComparison {
  const CommonRoadScoreComparison({
    required this.firstDriveId,
    required this.secondDriveId,
    required this.match,
    required this.algorithmVersion,
    required this.firstLocalScore,
    required this.secondLocalScore,
    required this.scoreDifference,
    required this.relativeDifference,
    required this.outcome,
    required this.comparisonValid,
    required this.reason,
  });

  final String firstDriveId;
  final String secondDriveId;
  final CommonRoadMatch match;
  final DriveScoreAlgorithmVersion algorithmVersion;
  final DriveScoreResult? firstLocalScore;
  final DriveScoreResult? secondLocalScore;

  /// Signed second-minus-first score delta.
  final double? scoreDifference;

  /// Signed score delta relative to the lower non-zero score.
  final double? relativeDifference;
  final CommonRoadScoreComparisonOutcome outcome;
  final bool comparisonValid;
  final String? reason;
}
