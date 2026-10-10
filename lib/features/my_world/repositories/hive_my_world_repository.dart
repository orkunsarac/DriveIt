// Named public dependency parameters are deliberately distinct from fields.
// ignore_for_file: prefer_initializing_formals
import 'package:hive/hive.dart';
import '../../../services/local_source_writer_fence.dart';

import '../models/validated_road.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import 'my_world_repository.dart';
import 'world_source_snapshot_repository.dart';
import '../../../services/world_source_access.dart';
import '../../../services/local_lifecycle_journal.dart';

class HiveMyWorldRepository implements MyWorldSourceRepository {
  /// A scoped caller supplies every lifecycle/source dependency. There is no
  /// optional global fallback in this constructor.
  HiveMyWorldRepository.scoped(
    Box<ValidatedRoad> validatedRoads,
    Box<WorldDriveProcessingRecord> processing,
    Box<WorldPendingJob> pendingJobs, {
    required WorldSourceSnapshotRepository sources,
    required bool Function(String) deleted,
    required bool Function(String) hasDeletion,
    required Future<void> Function(Future<void> Function()) serialized,
  }) : _validatedRoads = SourceWriterBoundary.box('world_jobs', validatedRoads),
       _processing = SourceWriterBoundary.box('world_jobs', processing),
       _pendingJobs = SourceWriterBoundary.box('world_jobs', pendingJobs),
       _sources = sources,
       _deleted = deleted,
       _hasDeletion = hasDeletion,
       _serialized = serialized;
  final WorldSourceSnapshotRepository? _sources;
  final bool Function(String)? _deleted;
  final bool Function(String)? _hasDeletion;
  final Future<void> Function(Future<void> Function())? _serialized;
  bool _worldHasDeletion(String id) =>
      _hasDeletion?.call(id) ?? LocalLifecycleJournal.worldHasDeletion(id);
  Future<T> _serialize<T>(Future<T> Function() action) async {
    if (_serialized == null) return LocalLifecycleJournal.serialized(action);
    late T result;
    await _serialized(() async {
      result = await action();
    });
    return result;
  }

  final Box<ValidatedRoad> _validatedRoads;
  final Box<WorldDriveProcessingRecord> _processing;
  final Box<WorldPendingJob> _pendingJobs;

  HiveMyWorldRepository(
    Box<ValidatedRoad> validatedRoads,
    Box<WorldDriveProcessingRecord> processing,
    Box<WorldPendingJob> pendingJobs,
  ) : _validatedRoads = SourceWriterBoundary.box('world_jobs', validatedRoads),
      _processing = SourceWriterBoundary.box('world_jobs', processing),
      _pendingJobs = SourceWriterBoundary.box('world_jobs', pendingJobs),
      _sources = null,
      _deleted = null,
      _hasDeletion = null,
      _serialized = null;

  @override
  Future<void> saveValidatedRoad(ValidatedRoad road) => _serialize(() async {
    if (_worldHasDeletion(road.driveSessionId)) return;
    await _validatedRoads.put(road.id, road);
    await _validatedRoads.flush();
    if (_sources != null) {
      await _sources.attachRoad(road);
    } else if (Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName)) {
      await WorldSourceSnapshotRepository(
        Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
      ).attachRoad(road);
    }
  });

  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async {
    final stored = _validatedRoads.get(id);
    if (stored != null) return stored;
    if (_sources != null) {
      for (final source in _sources.getAll()) {
        for (final road in source.roads) {
          if (road.id == id) return road;
        }
      }
      return null;
    }
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
    if (_sources != null) {
      for (final source in _sources.getAll()) {
        for (final road in source.roads) {
          roads.putIfAbsent(road.id, () => road);
        }
      }
      return roads.values.toList(growable: false);
    }
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
  Future<void> deleteWorldDataForDrive(String driveSessionId) =>
      SourceWriterBoundary.run(
        'world_jobs',
        () => _deleteWorldDataForDrive(driveSessionId),
        path: _validatedRoads.path,
      );
  Future<void> _deleteWorldDataForDrive(String driveSessionId) async {
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
  Future<void> saveProcessingRecord(WorldDriveProcessingRecord record) {
    if (_serialized == null) {
      return _processing.put(record.driveSessionId, record);
    }
    return _serialize(() async {
      if (_worldHasDeletion(record.driveSessionId)) return;
      await _processing.put(record.driveSessionId, record);
      await _processing.flush();
    });
  }

  @override
  Future<WorldDriveProcessingRecord?> getProcessingRecord(
    String driveSessionId,
  ) async => _deleted?.call(driveSessionId) == true
      ? null
      : _processing.get(driveSessionId);

  @override
  Future<bool> enqueueIfAbsent(WorldPendingJob job) => _serialize(() async {
    if (_worldHasDeletion(job.driveSessionId)) {
      return false;
    }
    final key = WorldPendingJob.idempotencyKey(job.driveSessionId, job.type);
    if (_pendingJobs.containsKey(key)) return false;
    await _pendingJobs.put(key, job);
    if (_serialized != null) await _pendingJobs.flush();
    return true;
  });

  @override
  Future<WorldPendingJob?> getPendingJob(
    String driveSessionId,
    WorldJobType type,
  ) async =>
      _pendingJobs.get(WorldPendingJob.idempotencyKey(driveSessionId, type));

  @override
  Future<void> savePendingJob(WorldPendingJob job) {
    final key = WorldPendingJob.idempotencyKey(job.driveSessionId, job.type);
    if (_serialized == null) return _pendingJobs.put(key, job);
    return _serialize(() async {
      if (_worldHasDeletion(job.driveSessionId)) return;
      await _pendingJobs.put(key, job);
      await _pendingJobs.flush();
    });
  }

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
            !_worldHasDeletion(job.driveSessionId) &&
            (job.status == WorldJobStatus.pending ||
                job.status == WorldJobStatus.retryScheduled),
      )
      .toList(growable: false);
}
