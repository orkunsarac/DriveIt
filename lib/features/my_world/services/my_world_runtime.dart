import 'package:hive/hive.dart';

import '../../../models/drive_session.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../models/world_index_snapshot.dart';
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
  );

  static Future<List<CanonicalTelemetryPoint>> _loadCanonicalTelemetry(
    String driveSessionId,
  ) async => DriveTelemetryStorageService.get(driveSessionId)?.points ?? const [];

  /// Save flow integration only enqueues local metadata. It never performs a
  /// network request, so normal drive saving remains independent from Mapbox.
  static Future<void> enqueueSavedDrive(DriveSession drive) =>
      validationService().enqueueDrive(drive);
}
