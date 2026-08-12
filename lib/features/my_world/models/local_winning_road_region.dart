import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import 'common_road_match.dart';
import 'common_road_score_comparison.dart';

enum LocalRoadWindowState {
  existingBetter,
  challengerBetter,
  noMeaningfulDifference,
  invalid,
}

enum LocalRoadRegionAnalysisStatus {
  success,
  notEligible,
  insufficientConfidence,
}

/// One temporary, non-persisted physical window used only during Phase 5.
class LocalRoadScoreWindow {
  const LocalRoadScoreWindow({
    required this.commonStartOffsetMeters,
    required this.commonEndOffsetMeters,
    required this.existingStartOffsetMeters,
    required this.existingEndOffsetMeters,
    required this.challengerStartOffsetMeters,
    required this.challengerEndOffsetMeters,
    required this.state,
    required this.comparison,
  });

  final double commonStartOffsetMeters;
  final double commonEndOffsetMeters;
  final double existingStartOffsetMeters;
  final double existingEndOffsetMeters;
  final double challengerStartOffsetMeters;
  final double challengerEndOffsetMeters;
  final LocalRoadWindowState state;
  final CommonRoadScoreComparison comparison;

  double get distanceMeters => commonEndOffsetMeters - commonStartOffsetMeters;
}

/// A challenger-winning physical road span after temporary windows and small
/// gaps have been merged. This is a domain result, not a World ownership row.
class LocalWinningRoadRegion {
  const LocalWinningRoadRegion({
    required this.existingDriveId,
    required this.challengerDriveId,
    required this.match,
    required this.startOffsetOnExistingMeters,
    required this.endOffsetOnExistingMeters,
    required this.startOffsetOnChallengerMeters,
    required this.endOffsetOnChallengerMeters,
    required this.commonStartOffsetMeters,
    required this.commonEndOffsetMeters,
    required this.winningDistanceMeters,
    required this.algorithmVersion,
    required this.confidence,
    required this.supportingWindowCount,
  });

  final String existingDriveId;
  final String challengerDriveId;
  final CommonRoadMatch match;
  final double startOffsetOnExistingMeters;
  final double endOffsetOnExistingMeters;
  final double startOffsetOnChallengerMeters;
  final double endOffsetOnChallengerMeters;
  final double commonStartOffsetMeters;
  final double commonEndOffsetMeters;
  final double winningDistanceMeters;
  final DriveScoreAlgorithmVersion algorithmVersion;
  final double confidence;
  final int supportingWindowCount;
}

class LocalWinningRoadRegionAnalysis {
  const LocalWinningRoadRegionAnalysis({
    required this.status,
    required this.match,
    required this.windows,
    required this.winningRegions,
    required this.reason,
  });

  final LocalRoadRegionAnalysisStatus status;
  final CommonRoadMatch match;
  final List<LocalRoadScoreWindow> windows;
  final List<LocalWinningRoadRegion> winningRegions;
  final String? reason;
}
