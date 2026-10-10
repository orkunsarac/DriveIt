// The lifecycle service intentionally keeps public dependency parameter names.
// ignore_for_file: prefer_initializing_formals

import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../models/world_drive_lifecycle.dart';
import '../repositories/my_world_index_repository.dart';
import '../repositories/my_world_repository.dart';
import 'my_world_rebuild_service.dart';
import '../../../services/independent_deletion_service.dart';

typedef DeleteDriveSource = Future<void> Function();

/// Keeps History deletion independent of World through verified protection.
class MyWorldLifecycleService {
  const MyWorldLifecycleService({
    required MyWorldSourceRepository repository,
    required MyWorldIndexRepository indexRepository,
    required MyWorldRebuildService rebuildService,
  }) : _indexRepository = indexRepository;

  final MyWorldIndexRepository _indexRepository;

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
    await IndependentDeletionService.deleteHistory(
      driveId,
      removeHistory: deleteSource,
    );
  }
}
