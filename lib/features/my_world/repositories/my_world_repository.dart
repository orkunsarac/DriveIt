import '../models/validated_road.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';

abstract interface class MyWorldRepository {
  Future<void> saveValidatedRoad(ValidatedRoad road);

  Future<ValidatedRoad?> getValidatedRoad(String id);

  Future<List<ValidatedRoad>> getValidatedRoadsForDrive(String driveSessionId);

  Future<void> saveProcessingRecord(WorldDriveProcessingRecord record);

  Future<WorldDriveProcessingRecord?> getProcessingRecord(
    String driveSessionId,
  );

  /// Returns false when the same logical job already exists.
  Future<bool> enqueueIfAbsent(WorldPendingJob job);

  Future<WorldPendingJob?> getPendingJob(
    String driveSessionId,
    WorldJobType type,
  );

  Future<void> savePendingJob(WorldPendingJob job);

  /// Hive has no multi-box transaction. Implementations persist the durable
  /// road first, then its state, then the job marker so retry can repair an
  /// interrupted write without another provider request.
  Future<void> saveValidationBundle({
    ValidatedRoad? road,
    required WorldDriveProcessingRecord processing,
    required WorldPendingJob job,
  });

  Future<List<WorldPendingJob>> getPendingJobs();
}

abstract interface class MyWorldSourceRepository extends MyWorldRepository {
  Future<List<ValidatedRoad>> getAllValidatedRoads();

  Future<void> deleteWorldDataForDrive(String driveSessionId);
}
