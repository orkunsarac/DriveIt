import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../../../features/drive_score/services/drive_score_calculator.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_time_analysis.dart';
import '../config/my_world_rules.dart';
import '../models/common_road_match.dart';
import '../models/common_road_score_comparison.dart';
import '../models/common_road_telemetry.dart';
import '../models/validated_road.dart';
import 'common_road_telemetry_extractor.dart';

/// Scores one eligible common road in memory with the normal Drive Score
/// pipeline. It has no persistence or World-record responsibilities.
class CommonRoadLocalScoreService {
  const CommonRoadLocalScoreService({
    this.telemetryExtractor = const CommonRoadTelemetryExtractor(),
    this.calculator = const DriveScoreCalculator(),
  });

  final CommonRoadTelemetryExtractor telemetryExtractor;
  final DriveScoreCalculator calculator;

  CommonRoadScoreComparison compare({
    required CommonRoadMatch match,
    required ValidatedRoad firstRoad,
    required Iterable<CanonicalTelemetryPoint> firstTelemetry,
    required ValidatedRoad secondRoad,
    required Iterable<CanonicalTelemetryPoint> secondTelemetry,
    DriveScoreAlgorithmVersion algorithmVersion = DriveScoreAlgorithmVersion.v1,
    bool requireComparisonEligibility = true,
    double? firstStartOffsetMeters,
    double? firstEndOffsetMeters,
    double? secondStartOffsetMeters,
    double? secondEndOffsetMeters,
    double offsetBoundaryToleranceMeters = 0,
    bool reliableIntervalsOnly = false,
  }) {
    if (requireComparisonEligibility && !match.comparisonEligible) {
      return _result(
        match: match,
        algorithmVersion: algorithmVersion,
        outcome: CommonRoadScoreComparisonOutcome.notEligible,
        reason: 'Common road is below the 3000 metre comparison threshold.',
      );
    }
    final telemetry = telemetryExtractor.extractRange(
      match: match,
      firstRoad: firstRoad,
      firstTelemetry: firstTelemetry,
      secondRoad: secondRoad,
      secondTelemetry: secondTelemetry,
      firstStartOffsetMeters: firstStartOffsetMeters,
      firstEndOffsetMeters: firstEndOffsetMeters,
      secondStartOffsetMeters: secondStartOffsetMeters,
      secondEndOffsetMeters: secondEndOffsetMeters,
      offsetBoundaryToleranceMeters: offsetBoundaryToleranceMeters,
    );
    if (!telemetry.isUsable) {
      final failedMapping =
          telemetry.first.status ==
              CommonRoadTelemetryMappingStatus.mappingFailed ||
          telemetry.second.status ==
              CommonRoadTelemetryMappingStatus.mappingFailed;
      return _result(
        match: match,
        algorithmVersion: algorithmVersion,
        outcome: failedMapping
            ? CommonRoadScoreComparisonOutcome.mappingFailed
            : CommonRoadScoreComparisonOutcome.insufficientTelemetry,
        reason:
            telemetry.first.reason ??
            telemetry.second.reason ??
            'Common-road telemetry could not be extracted.',
      );
    }
    if (reliableIntervalsOnly &&
        (!_reliableWindow(telemetry.first.telemetry) ||
            !_reliableWindow(telemetry.second.telemetry))) {
      return _result(
        match: match,
        algorithmVersion: algorithmVersion,
        outcome: CommonRoadScoreComparisonOutcome.insufficientTelemetry,
        reason:
            'Reliable comparison window has a telemetry gap or too few samples.',
      );
    }
    try {
      final first = reliableIntervalsOnly
          ? calculator.calculateReliable(telemetry: telemetry.first.telemetry)
          : calculator.calculate(
              telemetry: telemetry.first.telemetry,
              algorithmVersion: algorithmVersion,
            );
      final second = reliableIntervalsOnly
          ? calculator.calculateReliable(telemetry: telemetry.second.telemetry)
          : calculator.calculate(
              telemetry: telemetry.second.telemetry,
              algorithmVersion: algorithmVersion,
            );
      final difference = second.totalScore - first.totalScore;
      final denominator = first.totalScore < second.totalScore
          ? first.totalScore
          : second.totalScore;
      final relative = denominator <= 0 ? 0.0 : difference / denominator;
      final firstWins =
          first.totalScore >=
          second.totalScore *
              (1 + MyWorldRules.minimumMeaningfulScoreImprovementRatio);
      final secondWins =
          second.totalScore >=
          first.totalScore *
              (1 + MyWorldRules.minimumMeaningfulScoreImprovementRatio);
      return CommonRoadScoreComparison(
        firstDriveId: match.firstDriveId,
        secondDriveId: match.secondDriveId,
        match: match,
        algorithmVersion: algorithmVersion,
        firstLocalScore: first,
        secondLocalScore: second,
        scoreDifference: difference,
        relativeDifference: relative,
        outcome: firstWins
            ? CommonRoadScoreComparisonOutcome.firstWins
            : secondWins
            ? CommonRoadScoreComparisonOutcome.secondWins
            : CommonRoadScoreComparisonOutcome.noMeaningfulDifference,
        comparisonValid: true,
        reason: null,
      );
    } on UnsupportedDriveScoreAlgorithmVersion catch (error) {
      return _result(
        match: match,
        algorithmVersion: algorithmVersion,
        outcome: CommonRoadScoreComparisonOutcome.unsupportedAlgorithmVersion,
        reason: error.toString(),
      );
    } on InsufficientDriveScoreTelemetryException catch (error) {
      return _result(
        match: match,
        algorithmVersion: algorithmVersion,
        outcome: CommonRoadScoreComparisonOutcome.insufficientTelemetry,
        reason: error.toString(),
      );
    } catch (error) {
      return _result(
        match: match,
        algorithmVersion: algorithmVersion,
        outcome: CommonRoadScoreComparisonOutcome.calculationFailed,
        reason: error.toString(),
      );
    }
  }

  bool _reliableWindow(List<CanonicalTelemetryPoint> points) {
    // A winner must be backed by a continuous, adequately sampled physical
    // window. A break within this 500 m window invalidates it; World region
    // grouping must not bridge that missing evidence.
    if (points.length < 6 ||
        points.any(
          (point) =>
              !DriveTimeAnalysis.reliableSpeed(point) ||
              point.speedSource == 'legacy',
        )) {
      return false;
    }
    for (var i = 1; i < points.length; i++) {
      if (!DriveTimeAnalysis.reliableInterval(points[i - 1], points[i])) {
        return false;
      }
    }
    return true;
  }

  CommonRoadScoreComparison _result({
    required CommonRoadMatch match,
    required DriveScoreAlgorithmVersion algorithmVersion,
    required CommonRoadScoreComparisonOutcome outcome,
    required String reason,
  }) => CommonRoadScoreComparison(
    firstDriveId: match.firstDriveId,
    secondDriveId: match.secondDriveId,
    match: match,
    algorithmVersion: algorithmVersion,
    firstLocalScore: null,
    secondLocalScore: null,
    scoreDifference: null,
    relativeDifference: null,
    outcome: outcome,
    comparisonValid: false,
    reason: reason,
  );
}
