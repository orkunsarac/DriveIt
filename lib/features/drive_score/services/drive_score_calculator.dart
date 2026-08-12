import '../../../models/canonical_telemetry_point.dart';
import '../models/braking_score_models.dart';
import '../models/drive_score_algorithm_version.dart';
import '../models/drive_score_result.dart';
import 'acceleration_performance_engine.dart';
import 'braking_score_engine.dart';
import 'cornering_score_engine.dart';
import 'drive_phase_analyzer.dart';
import 'drive_score_engine.dart';
import 'driving_smoothness_engine.dart';
import 'endurance_score_engine.dart';
import 'tempo_performance_engine.dart';
import 'transition_control_engine.dart';

/// Runs the complete Drive Score pipeline entirely in memory.
///
/// It accepts canonical telemetry directly, has no DriveSession dependency,
/// and deliberately never creates a Hive record. Persistence is handled by
/// [DriveScorePersistenceCoordinator].
class DriveScoreCalculator {
  const DriveScoreCalculator({
    this.phaseAnalyzer = const DrivePhaseAnalyzer(),
    this.brakingEngine = const BrakingScoreEngine(),
    this.tempoEngine = const TempoPerformanceEngine(),
    this.corneringEngine = const CorneringScoreEngine(),
    this.smoothnessEngine = const DrivingSmoothnessEngine(),
    this.accelerationEngine = const AccelerationPerformanceEngine(),
    this.transitionEngine = const TransitionControlEngine(),
    this.enduranceEngine = const EnduranceScoreEngine(),
    this.scoreEngine = const DriveScoreEngine(),
  });

  final DrivePhaseAnalyzer phaseAnalyzer;
  final BrakingScoreEngine brakingEngine;
  final TempoPerformanceEngine tempoEngine;
  final CorneringScoreEngine corneringEngine;
  final DrivingSmoothnessEngine smoothnessEngine;
  final AccelerationPerformanceEngine accelerationEngine;
  final TransitionControlEngine transitionEngine;
  final EnduranceScoreEngine enduranceEngine;
  final DriveScoreEngine scoreEngine;

  DriveScoreResult calculate({
    required Iterable<CanonicalTelemetryPoint> telemetry,
    DriveScoreAlgorithmVersion algorithmVersion =
        DriveScoreAlgorithmVersion.v1,
  }) {
    final points = telemetry.toList(growable: false);
    if (points.length < 2) {
      throw const InsufficientDriveScoreTelemetryException();
    }
    if (points.any((point) => !point.hasValidCoordinate)) {
      throw const InvalidDriveScoreTelemetryException();
    }

    return switch (algorithmVersion) {
      DriveScoreAlgorithmVersion.v1 => _calculateV1(points),
    };
  }

  DriveScoreResult calculateForVersion({
    required Iterable<CanonicalTelemetryPoint> telemetry,
    required int algorithmVersion,
  }) => calculate(
    telemetry: telemetry,
    algorithmVersion: DriveScoreAlgorithmVersion.fromValue(algorithmVersion),
  );

  DriveScoreResult _calculateV1(List<CanonicalTelemetryPoint> telemetry) {
    final analysis = phaseAnalyzer.analyze(
      driveSessionId: 'in-memory-drive-score',
      telemetry: telemetry,
    );
    final braking = brakingEngine.score(analysis);
    final tempo = tempoEngine.score(analysis);
    final cornering = corneringEngine.score(analysis);
    final smoothness = smoothnessEngine.score(analysis);
    final acceleration = accelerationEngine.score(analysis);
    final transition = transitionEngine.score(analysis);

    final qualityCategories = <String, DriveScoreCategoryStatus>{
      'brakingAnticipation': DriveScoreCategoryStatus(
        score: braking.totalScore,
        maximum: 350,
        applicable: !_allBrakingSignalsNotApplicable(braking),
        sampleSufficient: braking.analyzedDecelerationEventCount > 0 ||
            braking.analyzedStopEventCount > 0,
      ),
      'tempoPerformance': DriveScoreCategoryStatus(
        score: tempo.totalScore,
        maximum: 150,
        applicable: tempo.diagnostics.sampleSufficient,
        sampleSufficient: tempo.diagnostics.sampleSufficient,
      ),
      'corneringPerformance': DriveScoreCategoryStatus(
        score: cornering.totalScore,
        maximum: 150,
        applicable: cornering.applicable,
        sampleSufficient: cornering.sampleSufficient,
      ),
      'drivingSmoothness': DriveScoreCategoryStatus(
        score: smoothness.totalScore,
        maximum: 100,
        applicable: smoothness.applicable,
        sampleSufficient: smoothness.sampleSufficient,
      ),
      'accelerationPerformance': DriveScoreCategoryStatus(
        score: acceleration.totalScore,
        maximum: 50,
        applicable: acceleration.applicable,
        sampleSufficient: acceleration.sampleSufficient,
      ),
      'transitionControl': DriveScoreCategoryStatus(
        score: transition.totalScore,
        maximum: 50,
        applicable: transition.applicable,
        sampleSufficient: transition.sampleSufficient,
      ),
    };
    final endurance = enduranceEngine.score(
      distanceKm: tempo.totalDistanceKm,
      qualityCategories: qualityCategories.values,
    );
    return scoreEngine.aggregate(<String, DriveScoreCategoryStatus>{
      ...qualityCategories,
      'drivingEndurance': DriveScoreCategoryStatus(
        score: endurance.totalScore,
        maximum: 150,
        applicable: endurance.applicable,
        sampleSufficient: endurance.sampleSufficient,
      ),
    });
  }

  bool _allBrakingSignalsNotApplicable(BrakingScoreResult braking) =>
      braking.diagnostics.anticipationNotApplicable &&
      braking.diagnostics.severityNotApplicable &&
      braking.diagnostics.oscillationNotApplicable &&
      braking.diagnostics.stoppingQualityNotApplicable;
}

class InsufficientDriveScoreTelemetryException implements Exception {
  const InsufficientDriveScoreTelemetryException();

  @override
  String toString() => 'At least two canonical telemetry points are required.';
}

class InvalidDriveScoreTelemetryException implements Exception {
  const InvalidDriveScoreTelemetryException();

  @override
  String toString() => 'Canonical telemetry contains an invalid coordinate.';
}
