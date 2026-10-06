// Test-only calculator seam: same pattern as my_world_phase5_winning_region_test.
// This file is never imported by the deployed bridge.
// ignore_for_file: avoid_relative_lib_imports
import '../lib/features/drive_score/models/drive_score_algorithm_version.dart';
import '../lib/features/drive_score/models/drive_score_result.dart';
import '../lib/features/drive_score/services/drive_score_calculator.dart';
import '../lib/features/my_world/services/common_road_local_score_service.dart';
import '../lib/models/canonical_telemetry_point.dart';
import 'world_scoring_adapter.dart';

class ScriptedCalculator extends DriveScoreCalculator {
  ScriptedCalculator(this.scores);
  final List scores;
  int calls = 0;
  @override
  DriveScoreResult calculate({
    required Iterable<CanonicalTelemetryPoint> telemetry,
    DriveScoreAlgorithmVersion algorithmVersion = DriveScoreAlgorithmVersion.v1,
  }) {
    final value = scores[calls++];
    if (value == null) {
      calls++;
      throw StateError('synthetic invalid window');
    }
    final total = (value as num).toDouble();
    return DriveScoreResult(
      totalScore: total,
      displayScore: total.round(),
      overallConfidence: 1,
      algorithmVersion: 1,
      categories: const {},
      contributions: const {},
      diagnostics: 'synthetic',
    );
  }
}

Json evaluateScriptedRegions(Json input) => analyzeScoring(
  decodeMatch(input['match']),
  road(input['firstRoad']),
  road(input['secondRoad']),
  telemetry(input['firstTelemetry']),
  telemetry(input['secondTelemetry']),
  service: CommonRoadLocalScoreService(
    calculator: ScriptedCalculator(input['scores']),
  ),
);
