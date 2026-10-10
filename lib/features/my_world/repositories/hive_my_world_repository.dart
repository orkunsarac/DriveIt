import 'package:hive/hive.dart';

import '../models/validated_road.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import 'my_world_repository.dart';
import 'world_source_snapshot_repository.dart';
import '../../../services/world_source_access.dart';
import '../../../services/local_lifecycle_journal.dart';

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
      LocalLifecycleJournal.serialized(() async {
        if (LocalLifecycleJournal.worldHasDeletion(road.driveSessionId)) return;
        await _validatedRoads.put(road.id, road);
        await _validatedRoads.flush();
        if (Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName)) {
          await WorldSourceSnapshotRepository(
            Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
          ).attachRoad(road);
        }
      });

  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async {
    final stored = _validatedRoads.get(id);
    if (stored != null) return stored;
    for (final source in WorldSourceAccess.drives()) {
      for (final road
          in WorldSourceAccess.snapshot(source.id)?.roads ??
              const <ValidatedRoad>[]) {
        if (road.id == id) return road;
      }
    }
    return null;
  }

  @override
  Future<List<ValidatedRoad>> getValidatedRoadsForDrive(
    String driveSessionId,
  ) async => (await getAllValidatedRoads())
      .where((road) => road.driveSessionId == driveSessionId)
      .toList(growable: false);

  @override
  Future<List<ValidatedRoad>> getAllValidatedRoads() async {
    final roads = {for (final road in _validatedRoads.values) road.id: road};
    for (final drive in WorldSourceAccess.drives()) {
      for (final road
          in WorldSourceAccess.snapshot(drive.id)?.roads ??
              const <ValidatedRoad>[]) {
        roads.putIfAbsent(road.id, () => road);
      }
    }
    return roads.values.toList(growable: false);
  }

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
    await Future.wait([
      _validatedRoads.flush(),
      _processing.flush(),
      _pendingJobs.flush(),
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
  Future<bool> enqueueIfAbsent(WorldPendingJob job) =>
      LocalLifecycleJournal.serialized(() async {
        if (LocalLifecycleJournal.worldHasDeletion(job.driveSessionId)) {
          return false;
        }
        final key = WorldPendingJob.idempotencyKey(
          job.driveSessionId,
          job.type,
        );
        if (_pendingJobs.containsKey(key)) return false;
        await _pendingJobs.put(key, job);
        return true;
      });

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
            !LocalLifecycleJournal.worldHasDeletion(job.driveSessionId) &&
            (job.status == WorldJobStatus.pending ||
                job.status == WorldJobStatus.retryScheduled),
      )
      .toList(growable: false);
}
