import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../config/my_world_rules.dart';
import '../models/common_road_match.dart';
import '../models/common_road_score_comparison.dart';
import '../models/local_winning_road_region.dart';
import '../models/validated_road.dart';
import 'common_road_local_score_service.dart';

/// Performs temporary, in-memory local scoring windows for one common road.
/// It intentionally has no World-index, ownership, Hive, or UI dependency.
class LocalWinningRoadRegionService {
  const LocalWinningRoadRegionService({
    this.localScoreService = const CommonRoadLocalScoreService(),
  });

  final CommonRoadLocalScoreService localScoreService;

  LocalWinningRoadRegionAnalysis analyze({
    required CommonRoadMatch match,
    required ValidatedRoad existingRoad,
    required Iterable<CanonicalTelemetryPoint> existingTelemetry,
    required ValidatedRoad challengerRoad,
    required Iterable<CanonicalTelemetryPoint> challengerTelemetry,
    DriveScoreAlgorithmVersion algorithmVersion =
        DriveScoreAlgorithmVersion.v1,
  }) {
    if (!match.comparisonEligible) {
      return _empty(
        LocalRoadRegionAnalysisStatus.notEligible,
        match,
        'Common road is below the 3000 metre comparison threshold.',
      );
    }
    if (match.geometryConfidence <
        MyWorldRules.commonRoadMinimumGeometryConfidence) {
      return _empty(
        LocalRoadRegionAnalysisStatus.insufficientConfidence,
        match,
        'Common-road geometry confidence is below the required threshold.',
      );
    }

    final windows = _buildWindows(
      match: match,
      existingRoad: existingRoad,
      existingTelemetry: existingTelemetry,
      challengerRoad: challengerRoad,
      challengerTelemetry: challengerTelemetry,
      algorithmVersion: algorithmVersion,
    );
    final regions = _winningRegions(
      match: match,
      windows: windows,
      algorithmVersion: algorithmVersion,
    );
    return LocalWinningRoadRegionAnalysis(
      status: LocalRoadRegionAnalysisStatus.success,
      match: match,
      windows: List.unmodifiable(windows),
      winningRegions: List.unmodifiable(regions),
      reason: null,
    );
  }

  List<LocalRoadScoreWindow> _buildWindows({
    required CommonRoadMatch match,
    required ValidatedRoad existingRoad,
    required Iterable<CanonicalTelemetryPoint> existingTelemetry,
    required ValidatedRoad challengerRoad,
    required Iterable<CanonicalTelemetryPoint> challengerTelemetry,
    required DriveScoreAlgorithmVersion algorithmVersion,
  }) {
    final windows = <LocalRoadScoreWindow>[];
    var commonStart = 0.0;
    while (commonStart < match.commonDistanceMeters) {
      final commonEnd = _minimum(
        commonStart + MyWorldRules.localScoreAnalysisWindowMeters,
        match.commonDistanceMeters,
      );
      final existingStart = _offsetForExisting(match, commonStart);
      final existingEnd = _offsetForExisting(match, commonEnd);
      final challengerStart = _offsetForChallenger(match, commonStart);
      final challengerEnd = _offsetForChallenger(match, commonEnd);
      final comparison = localScoreService.compare(
        match: match,
        firstRoad: existingRoad,
        firstTelemetry: existingTelemetry,
        secondRoad: challengerRoad,
        secondTelemetry: challengerTelemetry,
        algorithmVersion: algorithmVersion,
        requireComparisonEligibility: false,
        firstStartOffsetMeters: existingStart,
        firstEndOffsetMeters: existingEnd,
        secondStartOffsetMeters: challengerStart,
        secondEndOffsetMeters: challengerEnd,
        offsetBoundaryToleranceMeters:
            MyWorldRules.commonRoadTelemetryOffsetBoundaryToleranceMeters,
      );
      windows.add(LocalRoadScoreWindow(
        commonStartOffsetMeters: commonStart,
        commonEndOffsetMeters: commonEnd,
        existingStartOffsetMeters: existingStart,
        existingEndOffsetMeters: existingEnd,
        challengerStartOffsetMeters: challengerStart,
        challengerEndOffsetMeters: challengerEnd,
        state: _stateFor(comparison),
        comparison: comparison,
      ));
      commonStart = commonEnd;
    }
    return windows;
  }

  List<LocalWinningRoadRegion> _winningRegions({
    required CommonRoadMatch match,
    required List<LocalRoadScoreWindow> windows,
    required DriveScoreAlgorithmVersion algorithmVersion,
  }) {
    final regions = <LocalWinningRoadRegion>[];
    _WinningCandidate? candidate;
    var pendingGapMeters = 0.0;

    void finalize() {
      final value = candidate;
      if (value == null) return;
      if (value.distanceMeters >= MyWorldRules.minimumLocalWinningRegionMeters) {
        regions.add(value.toRegion(match, algorithmVersion));
      }
      candidate = null;
      pendingGapMeters = 0;
    }

    for (final window in windows) {
      if (window.state == LocalRoadWindowState.challengerBetter) {
        if (candidate == null) {
          candidate = _WinningCandidate.fromWindow(window);
        } else {
          candidate!.includeWinner(window);
        }
        pendingGapMeters = 0;
        continue;
      }
      if (candidate == null) continue;
      pendingGapMeters += window.distanceMeters;
      if (pendingGapMeters >
          MyWorldRules.localScoreWinnerGapToleranceMeters + 1e-6) {
        finalize();
      }
    }
    finalize();
    return regions;
  }

  LocalRoadWindowState _stateFor(CommonRoadScoreComparison comparison) {
    if (!comparison.comparisonValid) return LocalRoadWindowState.invalid;
    return switch (comparison.outcome) {
      CommonRoadScoreComparisonOutcome.firstWins =>
        LocalRoadWindowState.existingBetter,
      CommonRoadScoreComparisonOutcome.secondWins =>
        LocalRoadWindowState.challengerBetter,
      CommonRoadScoreComparisonOutcome.noMeaningfulDifference =>
        LocalRoadWindowState.noMeaningfulDifference,
      _ => LocalRoadWindowState.invalid,
    };
  }

  double _offsetForExisting(CommonRoadMatch match, double commonOffset) =>
      _interpolateOffset(
        match.firstStartOffsetMeters,
        match.firstEndOffsetMeters,
        match.commonDistanceMeters,
        commonOffset,
      );

  double _offsetForChallenger(CommonRoadMatch match, double commonOffset) =>
      _interpolateOffset(
        match.secondStartOffsetMeters,
        match.secondEndOffsetMeters,
        match.commonDistanceMeters,
        commonOffset,
      );

  double _interpolateOffset(
    double start,
    double end,
    double commonDistance,
    double commonOffset,
  ) {
    if (commonDistance <= 0) return start;
    return start + (end - start) * commonOffset / commonDistance;
  }

  LocalWinningRoadRegionAnalysis _empty(
    LocalRoadRegionAnalysisStatus status,
    CommonRoadMatch match,
    String reason,
  ) => LocalWinningRoadRegionAnalysis(
    status: status,
    match: match,
    windows: const [],
    winningRegions: const [],
    reason: reason,
  );
}

class _WinningCandidate {
  _WinningCandidate.fromWindow(LocalRoadScoreWindow window)
      : commonStartOffsetMeters = window.commonStartOffsetMeters,
        commonEndOffsetMeters = window.commonEndOffsetMeters,
        existingStartOffsetMeters = window.existingStartOffsetMeters,
        existingEndOffsetMeters = window.existingEndOffsetMeters,
        challengerStartOffsetMeters = window.challengerStartOffsetMeters,
        challengerEndOffsetMeters = window.challengerEndOffsetMeters,
        confidence = 1,
        supportingWindowCount = 1;

  final double commonStartOffsetMeters;
  double commonEndOffsetMeters;
  final double existingStartOffsetMeters;
  double existingEndOffsetMeters;
  final double challengerStartOffsetMeters;
  double challengerEndOffsetMeters;
  double confidence;
  int supportingWindowCount;

  double get distanceMeters => commonEndOffsetMeters - commonStartOffsetMeters;

  void includeWinner(LocalRoadScoreWindow window) {
    commonEndOffsetMeters = window.commonEndOffsetMeters;
    existingEndOffsetMeters = window.existingEndOffsetMeters;
    challengerEndOffsetMeters = window.challengerEndOffsetMeters;
    supportingWindowCount += 1;
  }

  LocalWinningRoadRegion toRegion(
    CommonRoadMatch match,
    DriveScoreAlgorithmVersion algorithmVersion,
  ) => LocalWinningRoadRegion(
    existingDriveId: match.firstDriveId,
    challengerDriveId: match.secondDriveId,
    match: match,
    startOffsetOnExistingMeters: existingStartOffsetMeters,
    endOffsetOnExistingMeters: existingEndOffsetMeters,
    startOffsetOnChallengerMeters: challengerStartOffsetMeters,
    endOffsetOnChallengerMeters: challengerEndOffsetMeters,
    commonStartOffsetMeters: commonStartOffsetMeters,
    commonEndOffsetMeters: commonEndOffsetMeters,
    winningDistanceMeters: distanceMeters,
    algorithmVersion: algorithmVersion,
    confidence: _minimum(confidence, match.geometryConfidence),
    supportingWindowCount: supportingWindowCount,
  );
}

double _minimum(double first, double second) => first < second ? first : second;
