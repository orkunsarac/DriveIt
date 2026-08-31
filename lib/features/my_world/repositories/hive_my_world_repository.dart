import 'package:hive/hive.dart';

import '../models/validated_road.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import 'my_world_repository.dart';

class HiveMyWorldRepository implements MyWorldSourceRepository {
  final Box<ValidatedRoad> _validatedRoads;
  final Box<WorldDriveProcessingRecord> _processing;
  final Box<WorldPendingJob> _pendingJobs;

  HiveMyWorldRepository(
    this._validatedRoads,
    this._processing,
    this._pendingJobs,
  );

  @override
  Future<void> saveValidatedRoad(ValidatedRoad road) =>
      _validatedRoads.put(road.id, road);

  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async =>
      _validatedRoads.get(id);

  @override
  Future<List<ValidatedRoad>> getValidatedRoadsForDrive(
    String driveSessionId,
  ) async => _validatedRoads.values
      .where((road) => road.driveSessionId == driveSessionId)
      .toList(growable: false);

  @override
  Future<List<ValidatedRoad>> getAllValidatedRoads() async =>
      _validatedRoads.values.toList(growable: false);

  @override
  Future<void> deleteWorldDataForDrive(String driveSessionId) async {
    final roadKeys = _validatedRoads.values
        .where((road) => road.driveSessionId == driveSessionId)
        .map((road) => road.id)
        .toList(growable: false);
    final jobKeys = _pendingJobs.values
        .where((job) => job.driveSessionId == driveSessionId)
        .map(
          (job) => WorldPendingJob.idempotencyKey(job.driveSessionId, job.type),
        )
        .toList(growable: false);
    // All three boxes are independent and Hive can batch-delete keys. This
    // keeps deletion latency bounded without changing cleanup semantics.
    await Future.wait([
      if (roadKeys.isNotEmpty) _validatedRoads.deleteAll(roadKeys),
      _processing.delete(driveSessionId),
      if (jobKeys.isNotEmpty) _pendingJobs.deleteAll(jobKeys),
    ]);
  }

  @override
  Future<void> saveProcessingRecord(WorldDriveProcessingRecord record) =>
      _processing.put(record.driveSessionId, record);

  @override
  Future<WorldDriveProcessingRecord?> getProcessingRecord(
    String driveSessionId,
  ) async => _processing.get(driveSessionId);

  @override
  Future<bool> enqueueIfAbsent(WorldPendingJob job) async {
    final key = WorldPendingJob.idempotencyKey(job.driveSessionId, job.type);
    if (_pendingJobs.containsKey(key)) return false;
    await _pendingJobs.put(key, job);
    return true;
  }

  @override
  Future<WorldPendingJob?> getPendingJob(
    String driveSessionId,
    WorldJobType type,
  ) async =>
      _pendingJobs.get(WorldPendingJob.idempotencyKey(driveSessionId, type));

  @override
  Future<void> savePendingJob(WorldPendingJob job) => _pendingJobs.put(
    WorldPendingJob.idempotencyKey(job.driveSessionId, job.type),
    job,
  );

  @override
  Future<void> saveValidationBundle({
    ValidatedRoad? road,
    required WorldDriveProcessingRecord processing,
    required WorldPendingJob job,
  }) async {
    if (road != null) await saveValidatedRoad(road);
    await saveProcessingRecord(processing);
    await savePendingJob(job);
  }

  @override
  Future<List<WorldPendingJob>> getPendingJobs() async => _pendingJobs.values
      .where(
        (job) =>
            job.status == WorldJobStatus.pending ||
            job.status == WorldJobStatus.retryScheduled,
      )
      .toList(growable: false);
}
