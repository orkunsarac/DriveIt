import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../../../models/drive_session.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../../../services/drive_score_storage_service.dart';
import '../config/my_world_rules.dart';
import '../models/world_index_snapshot.dart';
import '../models/world_map_read_model.dart';
import '../models/validated_road.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import '../persistence/my_world_hive.dart';
import '../providers/mapbox/mapbox_road_matching_provider.dart';
import '../repositories/hive_my_world_repository.dart';
import '../repositories/hive_my_world_index_repository.dart';
import 'my_world_validation_service.dart';
import 'road_matching_service.dart';
import 'world_record_processing_service.dart';
import 'my_world_rebuild_service.dart';
import 'my_world_lifecycle_service.dart';
import 'my_world_read_service.dart';
import 'world_pending_job_processor.dart';

class MyWorldRuntime {
  const MyWorldRuntime._();

  static HiveMyWorldRepository repository() => HiveMyWorldRepository(
    Hive.box<ValidatedRoad>(MyWorldHive.validatedRoadsBoxName),
    Hive.box<WorldDriveProcessingRecord>(MyWorldHive.processingBoxName),
    Hive.box<WorldPendingJob>(MyWorldHive.pendingJobsBoxName),
  );

  static MyWorldValidationService validationService() =>
      MyWorldValidationService(
        repository: repository(),
        telemetryLoader: _loadCanonicalTelemetry,
        roadMatching: RoadMatchingService(
          provider: MapboxRoadMatchingProvider(),
        ),
      );

  static HiveMyWorldIndexRepository indexRepository() =>
      HiveMyWorldIndexRepository(
        Hive.box<WorldIndexSnapshot>(MyWorldHive.indexSnapshotsBoxName),
        Hive.box<WorldIndexPointer>(MyWorldHive.indexMetadataBoxName),
      );

  /// Explicit runtime entry point for a drive already marked
  /// readyForWorldProcessing. It is intentionally not backfill/automatic UI.
  static WorldRecordProcessingService recordProcessingService() =>
      WorldRecordProcessingService(
        repository: repository(),
        indexRepository: indexRepository(),
        telemetryLoader: _loadCanonicalTelemetry,
      );

  static MyWorldRebuildService rebuildService() => MyWorldRebuildService(
    repository: repository(),
    indexRepository: indexRepository(),
    driveLoader: () async => Hive.box<DriveSession>('drives').values.toList(),
    telemetryLoader: _loadCanonicalTelemetry,
    driveEligibility: (driveId) =>
        DriveScoreStorageService.get(driveId: driveId) != null,
  );

  static MyWorldLifecycleService worldLifecycleService() =>
      MyWorldLifecycleService(
        repository: repository(),
        indexRepository: indexRepository(),
        rebuildService: rebuildService(),
      );

  /// Read-only projection used by the Phase 8 presentation layer.
  static MyWorldReadService readService() => MyWorldReadService(
    repository: repository(),
    indexRepository: indexRepository(),
    telemetryLoader: _loadCanonicalTelemetry,
  );

  // World reads are immutable projections of a persisted snapshot. Keep the
  // last projection in memory so reopening the map (or rebuilding its route
  // chrome) does not reread every road and canonical telemetry point.
  static MyWorldMapData? _readCache;
  static Future<MyWorldMapData>? _readInFlight;

  static Future<MyWorldMapData> readWorldData() async {
    final snapshot = await indexRepository().getActiveSnapshot();
    final cached = _readCache;
    if (cached != null && cached.snapshotGeneration == snapshot.generation) {
      return cached;
    }
    final active = _readInFlight;
    if (active != null) return active;
    final future = readService().load().then((data) {
      _readCache = data;
      return data;
    });
    _readInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_readInFlight, future)) _readInFlight = null;
    }
  }

  static Future<List<CanonicalTelemetryPoint>> _loadCanonicalTelemetry(
    String driveSessionId,
  ) async =>
      DriveTelemetryStorageService.get(driveSessionId)?.points ?? const [];

  /// Save flow integration only enqueues local metadata. It never performs a
  /// network request, so normal drive saving remains independent from Mapbox.
  static Future<void> enqueueSavedDrive(DriveSession drive) =>
      validationService().enqueueDrive(drive);

  static WorldPendingJobProcessor pendingJobProcessor() =>
      WorldPendingJobProcessor(
        repository: repository(),
        validation: validationService(),
        recordProcessing: recordProcessingService(),
        driveLoader: (id) => Hive.box<DriveSession>('drives').get(id),
        driveEligibility: (driveId) =>
            DriveScoreStorageService.get(driveId: driveId) != null,
      );

  /// Reconciles persisted drives with the durable World queue before draining.
  ///
  /// Older drives (or drives saved while the World Hive boxes were not yet
  /// available) may exist without a validation job.  Re-enqueuing is safe:
  /// `enqueueDrive` is idempotent and skips drives that already have a
  /// successful validation result.
  static Future<void> drainPendingJobs() async {
    if (_drainInFlight != null) return _drainInFlight!;
    final operation = _drainPendingJobs();
    _drainInFlight = operation.whenComplete(() => _drainInFlight = null);
    return _drainInFlight!;
  }

  static Future<void>? _drainInFlight;

  static Future<void> _drainPendingJobs() async {
    if (Hive.isBoxOpen('drives')) {
      final drives = Hive.box<DriveSession>('drives').values.toList();
      for (final drive in drives) {
        if (DriveScoreStorageService.get(driveId: drive.id) == null) continue;
        await enqueueSavedDrive(drive);
      }
    }
    await pendingJobProcessor().drain();
    await _ensureCurrentValidatedRoadProjection();
    await _cleanupScorelessWorldTraces();
  }

  static Future<void> _ensureCurrentValidatedRoadProjection() async {
    try {
      final snapshot = await indexRepository().getActiveSnapshot();
      if (snapshot.processedDriveSessionIds.isEmpty) return;
      final roads = await repository().getAllValidatedRoads();
      final currentByDrive = <String, ValidatedRoad>{};
      for (final road in roads) {
        if (road.processingVersion !=
            MyWorldRules.validatedRoadProcessingVersion) {
          continue;
        }
        currentByDrive[road.driveSessionId] = road;
      }
      if (!snapshot.processedDriveSessionIds.every(
        currentByDrive.containsKey,
      )) {
        return;
      }
      final staleProjection = snapshot.traces.any(
        (trace) =>
            currentByDrive[trace.sourceDriveSessionId]?.id !=
            trace.validatedRoadId,
      );
      if (!staleProjection) return;
      final result = await rebuildService().rebuild(
        targetVersion: DriveScoreAlgorithmVersion.v1,
        reason: 'validatedRoadProcessingVersionChanged',
      );
      if (result.success) _readCache = null;
      if (kDebugMode) {
        debugPrint(
          '[WORLD_REBUILD_AUDIT] validatedRoadMigration=true '
          'targetRoadVersion=${MyWorldRules.validatedRoadProcessingVersion} '
          'success=${result.success} traceCount=${result.resultingTraceCount}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WORLD_REBUILD_AUDIT] validatedRoadMigrationFailed=$error');
      }
    }
  }

  static Future<void> _cleanupScorelessWorldTraces() async {
    try {
      final snapshot = await indexRepository().getActiveSnapshot();
      final hasScorelessTrace = snapshot.processedDriveSessionIds.any(
        (id) => DriveScoreStorageService.get(driveId: id) == null,
      );
      if (!hasScorelessTrace) return;
      await rebuildService().rebuild(
        targetVersion: DriveScoreAlgorithmVersion.v1,
        reason: 'scorelessWorldTraceCleanup',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WORLD_REBUILD_AUDIT] scorelessCleanupFailed=$error');
      }
    }
  }

  /// Ensures the persisted World index is rebuilt when the scoring or World
  /// rule version changes. This is deliberately awaited during app startup so
  /// the first World read cannot race an old snapshot.
  static Future<void> ensureCurrentWorldIndex() async {
    final service = rebuildService();
    final index = indexRepository();
    late final WorldIndexSnapshot beforeSnapshot;
    try {
      beforeSnapshot = await index.getActiveSnapshot();
    } catch (_) {
      beforeSnapshot = WorldIndexSnapshot.empty(
        driveScoreAlgorithmVersion: DriveScoreAlgorithmVersion.v1.value,
        validatedRoadProcessingVersion: 2,
      );
    }
    final pointer = Hive.box<WorldIndexPointer>(
      MyWorldHive.indexMetadataBoxName,
    ).get('active_generation');
    final need = await service.needsRebuild(
      targetVersion: DriveScoreAlgorithmVersion.v1,
    );
    if (kDebugMode) {
      debugPrint(
        '[WORLD_REBUILD_AUDIT] startupCheck=true '
        'pointerExists=${pointer != null} '
        'pointerGeneration=${pointer?.activeGeneration ?? 'none'} '
        'needsRebuildBefore=${need.needsRebuild} '
        'needsRebuildReason=${need.reason ?? 'none'} '
        'activeSnapshotVersion=${beforeSnapshot.validatedRoadProcessingVersion} '
        'activeSnapshotGeneration=${beforeSnapshot.generation} '
        'activeTraceCount=${beforeSnapshot.traces.length}',
      );
    }
    if (!need.needsRebuild) return;
    final startedAt = DateTime.now().toUtc();
    if (kDebugMode) {
      debugPrint(
        '[WORLD_REBUILD_AUDIT] rebuildInvoked=true rebuildStartedAt=$startedAt',
      );
    }
    try {
      final result = await service.rebuild(
        targetVersion: DriveScoreAlgorithmVersion.v1,
        reason: need.reason ?? 'startupVersionMismatch',
      );
      final afterSnapshot = await index.getActiveSnapshot();
      final afterPointer = Hive.box<WorldIndexPointer>(
        MyWorldHive.indexMetadataBoxName,
      ).get('active_generation');
      final afterNeed = await service.needsRebuild(
        targetVersion: DriveScoreAlgorithmVersion.v1,
      );
      if (kDebugMode) {
        debugPrint(
          '[WORLD_REBUILD_AUDIT] rebuildCompleted=${result.success} '
          'rebuildFailed=${!result.success} '
          'pointerGeneration=${afterPointer?.activeGeneration ?? 'none'} '
          'activeSnapshotVersion=${afterSnapshot.validatedRoadProcessingVersion} '
          'activeSnapshotGeneration=${afterSnapshot.generation} '
          'activeTraceCount=${afterSnapshot.traces.length} '
          'needsRebuildAfter=${afterNeed.needsRebuild}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[WORLD_REBUILD_AUDIT] rebuildCompleted=false rebuildFailed=true error=$error',
        );
      }
    }
  }
}
