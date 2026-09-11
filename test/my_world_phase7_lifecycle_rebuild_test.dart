import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_mutation_plan.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/models/world_processing.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_index_repository.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_repository.dart';
import 'package:driveit_project/features/my_world/services/my_world_lifecycle_service.dart';
import 'package:driveit_project/features/my_world/services/my_world_rebuild_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rebuild is source-history based and deterministic', () async {
    final source = _Source(_road('drive-a'), _drive('drive-a'));
    final index = _MemoryIndex();
    final service = MyWorldRebuildService(
      repository: source,
      indexRepository: index,
      driveLoader: () async => source.drives,
      telemetryLoader: (_) async => const [],
      clock: () => DateTime.utc(2026, 8, 12),
    );

    final result = await service.rebuild(
      targetVersion: DriveScoreAlgorithmVersion.v1,
    );
    expect(result.success, isTrue);
    expect(result.resultingTraceCount, 1);
    expect(index.snapshot.operationReason, 'manualRebuild');
    expect((await service.needsRebuild(
      targetVersion: DriveScoreAlgorithmVersion.v1,
    )).needsRebuild, isFalse);
  });

  test('active-drive deletion restores an empty world atomically', () async {
    final source = _Source(_road('drive-a'), _drive('drive-a'));
    final index = _MemoryIndex();
    final rebuild = MyWorldRebuildService(
      repository: source,
      indexRepository: index,
      driveLoader: () async => source.drives,
      telemetryLoader: (_) async => const [],
    );
    await rebuild.rebuild(targetVersion: DriveScoreAlgorithmVersion.v1);
    var deleted = false;
    final lifecycle = MyWorldLifecycleService(
      repository: source,
      indexRepository: index,
      rebuildService: rebuild,
    );
    final info = await lifecycle.getDriveLifecycleInfo('drive-a');
    expect(info.hasActiveTrace, isTrue);
    await lifecycle.deleteDriveSafely(
      driveId: 'drive-a',
      deleteSource: () async => deleted = true,
    );
    expect(deleted, isTrue);
    expect(index.snapshot.traces, isEmpty);
  });
}

DriveSession _drive(String id) => DriveSession(
  id: id,
  date: DateTime.utc(2026, 1, 1),
  distance: 5000,
  durationSeconds: 100,
  averageSpeed: 100,
  maxSpeed: 100,
  mapImagePath: '',
  route: const [],
);

ValidatedRoad _road(String driveId) {
  const geometry = [
    MatchedRoadPoint(latitude: 41, longitude: 29, headingDegrees: 90),
    MatchedRoadPoint(latitude: 41, longitude: 29.04, headingDegrees: 90),
  ];
  return ValidatedRoad(
    id: '$driveId-road',
    driveSessionId: driveId,
    geometry: geometry,
    sections: const [MatchedRoadSection(
      id: 'section', geometry: geometry, distanceMeters: 5000,
      confidence: 1, sourceTraceIndex: 0, sourceChunkIndex: 0,
    )],
    validDistanceMeters: 5000,
    status: RoadValidationStatus.validated,
    validatedAt: DateTime.utc(2026, 1, 1),
    providerId: 'test',
    confidence: 1,
    processingVersion: MyWorldRules.validatedRoadProcessingVersion,
    directionKey: 'east', averageHeadingDegrees: 90,
    createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class _Source implements MyWorldSourceRepository {
  _Source(this.road, this.drive);
  final ValidatedRoad road;
  final DriveSession drive;
  List<DriveSession> get drives => [drive];
  @override Future<List<ValidatedRoad>> getAllValidatedRoads() async => [road];
  @override Future<ValidatedRoad?> getValidatedRoad(String id) async => id == road.id ? road : null;
  @override Future<List<ValidatedRoad>> getValidatedRoadsForDrive(String id) async => id == drive.id ? [road] : [];
  @override Future<void> deleteWorldDataForDrive(String id) async {}
  @override Future<void> saveValidatedRoad(ValidatedRoad value) async {}
  @override Future<void> saveProcessingRecord(WorldDriveProcessingRecord value) async {}
  @override Future<WorldDriveProcessingRecord?> getProcessingRecord(String id) async => null;
  @override Future<bool> enqueueIfAbsent(WorldPendingJob job) async => true;
  @override Future<WorldPendingJob?> getPendingJob(String id, WorldJobType type) async => null;
  @override Future<void> savePendingJob(WorldPendingJob job) async {}
  @override Future<List<WorldPendingJob>> getPendingJobs() async => [];
  @override Future<void> saveValidationBundle({ValidatedRoad? road, required WorldDriveProcessingRecord processing, required WorldPendingJob job}) async {}
}

class _MemoryIndex implements MyWorldIndexRepository {
  WorldIndexSnapshot snapshot = WorldIndexSnapshot.empty(
    driveScoreAlgorithmVersion: 1, validatedRoadProcessingVersion: 2,
  );
  @override Future<WorldIndexSnapshot> getActiveSnapshot() async => snapshot;
  @override Future<void> commit(WorldIndexMutationPlan plan) async => snapshot = plan.resultingSnapshot;
  @override Future<List<ActiveWorldTrace>> getActiveTraces() async => snapshot.traces;
  @override Future<List<ActiveWorldTrace>> getActiveTracesForDrive(String id) async => snapshot.traces.where((t) => t.sourceDriveSessionId == id).toList();
  @override Future<List<ActiveWorldTrace>> getActiveTracesInBounds({required double minLatitude, required double maxLatitude, required double minLongitude, required double maxLongitude}) async => snapshot.traces;
  @override Future<bool> hasActiveTraceForDrive(String id) async => (await getActiveTracesForDrive(id)).isNotEmpty;
  @override Future<double> activeDistanceForDrive(String id) async => (await getActiveTracesForDrive(id)).fold<double>(0, (s, t) => s + t.distanceMeters);
  @override Future<double> totalWorldDistance() async => snapshot.traces.fold<double>(0, (s, t) => s + t.distanceMeters);
}
