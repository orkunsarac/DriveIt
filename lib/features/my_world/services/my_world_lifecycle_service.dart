// The lifecycle service intentionally keeps public dependency parameter names.
// ignore_for_file: prefer_initializing_formals

import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../models/world_drive_lifecycle.dart';
import '../models/world_rebuild_result.dart';
import '../repositories/my_world_index_repository.dart';
import '../repositories/my_world_repository.dart';
import 'my_world_rebuild_service.dart';

typedef DeleteDriveSource = Future<void> Function();

/// Coordinates source-drive deletion with an atomic World snapshot update.
class MyWorldLifecycleService {
  const MyWorldLifecycleService({
    required MyWorldSourceRepository repository,
    required MyWorldIndexRepository indexRepository,
    required MyWorldRebuildService rebuildService,
  }) : _repository = repository,
       _indexRepository = indexRepository,
       _rebuildService = rebuildService;

  final MyWorldSourceRepository _repository;
  final MyWorldIndexRepository _indexRepository;
  final MyWorldRebuildService _rebuildService;

  Future<WorldDriveLifecycleInfo> getDriveLifecycleInfo(String driveId) async {
    final traces = await _indexRepository.getActiveTracesForDrive(driveId);
    return WorldDriveLifecycleInfo(
      hasActiveTrace: traces.isNotEmpty,
      activeTraceCount: traces.length,
      activeDistanceMeters: traces.fold(
        0,
        (sum, trace) => sum + trace.distanceMeters,
      ),
    );
  }

  Future<void> deleteDriveSafely({
    required String driveId,
    required DeleteDriveSource deleteSource,
    DriveScoreAlgorithmVersion targetVersion = DriveScoreAlgorithmVersion.v1,
  }) async {
    // Read the active traces once. The previous flow queried the same Hive
    // snapshot twice before starting the (already necessary) recovery rebuild.
    final active = await _indexRepository.getActiveTracesForDrive(driveId);
    final info = WorldDriveLifecycleInfo(
      hasActiveTrace: active.isNotEmpty,
      activeTraceCount: active.length,
      activeDistanceMeters: active.fold(
        0,
        (sum, trace) => sum + trace.distanceMeters,
      ),
    );
    if (info.hasActiveTrace) {
      final rebuilt = await _rebuildService.rebuild(
        targetVersion: targetVersion,
        reason: 'driveDeletionRestore',
        excludedDriveIds: {driveId},
        restrictToBounds: active
            .map(
              (trace) => WorldRebuildBounds(
                minLatitude: trace.minLatitude,
                maxLatitude: trace.maxLatitude,
                minLongitude: trace.minLongitude,
                maxLongitude: trace.maxLongitude,
              ),
            )
            .toList(growable: false),
      );
      if (!rebuilt.success) {
        throw StateError(rebuilt.failureReason ?? 'World restore failed.');
      }
    }
    // Source data is intentionally retained until the World snapshot is safe.
    await deleteSource();
    await _repository.deleteWorldDataForDrive(driveId);
  }
}
