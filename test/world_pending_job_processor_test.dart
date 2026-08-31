import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_mutation_plan.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/models/world_processing.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_index_repository.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_repository.dart';
import 'package:driveit_project/features/my_world/services/my_world_validation_service.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/features/my_world/services/world_pending_job_processor.dart';
import 'package:driveit_project/features/my_world/services/world_record_processing_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending valid job creates a road and commits the World trace',
    () async {
      final repository = _MemoryWorldRepository();
      final drive = _drive('drive-1');
      final provider = _Provider(_match(distance: 5000));
      await _enqueue(repository, drive);
      final processor = _processor(repository, provider, drive);

      await processor.drain();

      expect(provider.calls, 1);
      expect(repository.roads, hasLength(1));
      expect(repository.jobs.values.single.status, WorldJobStatus.completed);
      expect(repository.record?.state, WorldProcessingState.processed);
      expect(repository.index.active.hasProcessedDrive('drive-1'), isTrue);
    },
  );

  test('two concurrent drains call the provider only once', () async {
    final repository = _MemoryWorldRepository();
    final drive = _drive('drive-2');
    final provider = _Provider(_match(distance: 2999));
    await _enqueue(repository, drive);
    final processor = _processor(repository, provider, drive);

    await Future.wait([processor.drain(), processor.drain()]);

    expect(provider.calls, 1);
    expect(repository.jobs.values.single.status, WorldJobStatus.completed);
    expect(
      repository.record?.state,
      WorldProcessingState.rejectedInsufficientValidDistance,
    );
  });

  test('retryable provider failure preserves the job and drive', () async {
    final repository = _MemoryWorldRepository();
    final drive = _drive('drive-3');
    final provider = _Provider(
      RoadMatchingResult.failure(
        kind: RoadMatchingFailureKind.network,
        message: 'offline',
      ),
    );
    await _enqueue(repository, drive);
    await _processor(repository, provider, drive).drain();

    expect(provider.calls, 1);
    expect(repository.jobs.values.single.status, WorldJobStatus.retryScheduled);
    expect(repository.jobs.values.single.retryCount, 1);
    expect(repository.record?.state, WorldProcessingState.pendingValidation);
    expect(drive.id, 'drive-3');
  });
}

WorldPendingJobProcessor _processor(
  _MemoryWorldRepository repository,
  _Provider provider,
  DriveSession drive,
) {
  final validation = MyWorldValidationService(
    repository: repository,
    roadMatching: RoadMatchingService(
      provider: provider,
      clock: () => DateTime.utc(2026, 8, 12),
    ),
    clock: () => DateTime.utc(2026, 8, 12),
  );
  return WorldPendingJobProcessor(
    repository: repository,
    validation: validation,
    recordProcessing: WorldRecordProcessingService(
      repository: repository,
      indexRepository: repository.index,
      telemetryLoader: (_) async => const [],
      clock: () => DateTime.utc(2026, 8, 12),
    ),
    driveLoader: (_) => drive,
  );
}

Future<void> _enqueue(
  _MemoryWorldRepository repository,
  DriveSession drive,
) async {
  final now = DateTime.utc(2026, 8, 12);
  await repository.enqueueIfAbsent(
    WorldPendingJob.pending(
      driveSessionId: drive.id,
      type: WorldJobType.validateRoad,
      now: now,
    ),
  );
  await repository.saveProcessingRecord(
    WorldDriveProcessingRecord(
      driveSessionId: drive.id,
      state: WorldProcessingState.pendingValidation,
      validatedRoadId: null,
      lastError: null,
      updatedAt: now,
    ),
  );
}

DriveSession _drive(String id) => DriveSession(
  id: id,
  date: DateTime.utc(2026, 8, 12),
  distance: 4000,
  durationSeconds: 600,
  averageSpeed: 24,
  maxSpeed: 60,
  mapImagePath: '',
  route: [RoutePoint(latitude: 41, longitude: 29)],
);

RoadMatchingResult _match({required double distance}) {
  const geometry = [
    MatchedRoadPoint(latitude: 41, longitude: 29, headingDegrees: 90),
    MatchedRoadPoint(latitude: 41, longitude: 29.01, headingDegrees: 90),
  ];
  return RoadMatchingResult(
    sections: [
      MatchedRoadSection(
        id: 'section',
        geometry: geometry,
        distanceMeters: distance,
        confidence: .9,
        sourceTraceIndex: 0,
        sourceChunkIndex: 0,
      ),
    ],
    geometry: geometry,
    validDistanceMeters: distance,
    status: RoadValidationStatus.validated,
    confidence: .9,
    directionKey: 'east',
    averageHeadingDegrees: 90,
    errorMessage: null,
  );
}

class _Provider implements RoadMatchingProvider {
  _Provider(this.result);
  final RoadMatchingResult result;
  int calls = 0;

  @override
  String get providerId => 'test-provider';

  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    calls++;
    return result;
  }
}

class _MemoryWorldRepository implements MyWorldRepository {
  final Map<String, ValidatedRoad> roads = {};
  final Map<String, WorldPendingJob> jobs = {};
  WorldDriveProcessingRecord? record;
  final _MemoryIndex index = _MemoryIndex();

  @override
  Future<bool> enqueueIfAbsent(WorldPendingJob job) async {
    final key = WorldPendingJob.idempotencyKey(job.driveSessionId, job.type);
    if (jobs.containsKey(key)) return false;
    jobs[key] = job;
    return true;
  }

  @override
  Future<WorldPendingJob?> getPendingJob(
    String driveSessionId,
    WorldJobType type,
  ) async => jobs[WorldPendingJob.idempotencyKey(driveSessionId, type)];
  @override
  Future<List<WorldPendingJob>> getPendingJobs() async => jobs.values
      .where(
        (j) =>
            j.status == WorldJobStatus.pending ||
            j.status == WorldJobStatus.retryScheduled,
      )
      .toList();
  @override
  Future<WorldDriveProcessingRecord?> getProcessingRecord(
    String driveSessionId,
  ) async => record;
  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async => roads[id];
  @override
  Future<List<ValidatedRoad>> getValidatedRoadsForDrive(
    String driveSessionId,
  ) async =>
      roads.values.where((r) => r.driveSessionId == driveSessionId).toList();
  @override
  Future<void> savePendingJob(WorldPendingJob job) async =>
      jobs[WorldPendingJob.idempotencyKey(job.driveSessionId, job.type)] = job;
  @override
  Future<void> saveProcessingRecord(WorldDriveProcessingRecord value) async =>
      record = value;
  @override
  Future<void> saveValidatedRoad(ValidatedRoad road) async =>
      roads[road.id] = road;
  @override
  Future<void> saveValidationBundle({
    ValidatedRoad? road,
    required WorldDriveProcessingRecord processing,
    required WorldPendingJob job,
  }) async {
    if (road != null) roads[road.id] = road;
    record = processing;
    jobs[WorldPendingJob.idempotencyKey(job.driveSessionId, job.type)] = job;
  }
}

class _MemoryIndex implements MyWorldIndexRepository {
  WorldIndexSnapshot active = WorldIndexSnapshot.empty(
    driveScoreAlgorithmVersion: 1,
    validatedRoadProcessingVersion: 2,
  );
  @override
  Future<WorldIndexSnapshot> getActiveSnapshot() async => active;
  @override
  Future<void> commit(WorldIndexMutationPlan plan) async =>
      active = plan.resultingSnapshot;
  @override
  Future<List<ActiveWorldTrace>> getActiveTraces() async => active.traces;
  @override
  Future<List<ActiveWorldTrace>> getActiveTracesForDrive(String id) async =>
      active.traces.where((t) => t.sourceDriveSessionId == id).toList();
  @override
  Future<List<ActiveWorldTrace>> getActiveTracesInBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async => active.traces;
  @override
  Future<bool> hasActiveTraceForDrive(String id) async =>
      (await getActiveTracesForDrive(id)).isNotEmpty;
  @override
  Future<double> activeDistanceForDrive(String id) async =>
      (await getActiveTracesForDrive(
        id,
      )).fold<double>(0, (s, t) => s + t.distanceMeters);
  @override
  Future<double> totalWorldDistance() async =>
      active.traces.fold<double>(0, (s, t) => s + t.distanceMeters);
}
