import '../../../models/drive_score_record.dart';
import '../../../services/drive_score_storage_service.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../models/drive_score_algorithm_version.dart';
import 'drive_score_calculator.dart';

/// Builds and persists a v1 score only after a drive and its canonical
/// telemetry are already durable. It intentionally has no UI responsibilities.
class DriveScorePersistenceCoordinator {
  const DriveScorePersistenceCoordinator({
    this.calculator = const DriveScoreCalculator(),
  });

  final DriveScoreCalculator calculator;

  /// Returns null when no canonical telemetry exists. Legacy drives therefore
  /// never acquire an invented v1 score.
  Future<DriveScoreRecord?> calculateAndPersistForDrive(String driveId) async {
    final existing = DriveScoreStorageService.get(
      driveId: driveId,
      algorithmVersion: DriveScoreAlgorithmVersion.v1.value,
    );
    if (existing != null) return existing;

    final telemetry = DriveTelemetryStorageService.get(driveId);
    if (telemetry == null || telemetry.points.length < 2) return null;

    final result = calculator.calculate(
      telemetry: telemetry.points,
      algorithmVersion: DriveScoreAlgorithmVersion.v1,
    );
    final record = DriveScoreRecord.fromResult(
      driveId: driveId,
      telemetryDataVersion: telemetry.dataVersion,
      calculatedAt: DateTime.now(),
      result: result,
    );
    await DriveScoreStorageService.save(record);
    return record;
  }

}
