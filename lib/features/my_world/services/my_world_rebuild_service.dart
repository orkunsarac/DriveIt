// The explicit constructor assignments keep the public factory parameter
// names stable while the service fields remain private.
// ignore_for_file: prefer_initializing_formals

import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../models/drive_session.dart';
import '../config/my_world_rules.dart';
import '../models/validated_road.dart';
import '../models/world_index_mutation_plan.dart';
import '../models/world_index_snapshot.dart';
import '../models/world_rebuild_result.dart';
import '../repositories/my_world_index_repository.dart';
import '../repositories/my_world_repository.dart';
import 'world_index_mutation_planner.dart';
import 'world_record_processing_service.dart';

typedef WorldDriveHistoryLoader = Future<List<DriveSession>> Function();
typedef WorldCanonicalTelemetryLoader = Future<List<CanonicalTelemetryPoint>>
    Function(String driveSessionId);

/// Explicit, source-history rebuild. It stages the complete result in memory
/// and activates one copy-on-write snapshot only after all invariants pass.
class MyWorldRebuildService {
  MyWorldRebuildService({
    required MyWorldSourceRepository repository,
    required MyWorldIndexRepository indexRepository,
    required WorldDriveHistoryLoader driveLoader,
    required WorldCanonicalTelemetryLoader telemetryLoader,
    WorldIndexMutationPlanner mutationPlanner = const WorldIndexMutationPlanner(),
    WorldRecordProcessingService? processingService,
    DateTime Function()? clock,
  })  : _repository = repository,
        _indexRepository = indexRepository,
        _driveLoader = driveLoader,
        _telemetryLoader = telemetryLoader,
        _mutationPlanner = mutationPlanner,
        _processingService = processingService,
        _clock = clock ?? DateTime.now;

  final MyWorldSourceRepository _repository;
  final MyWorldIndexRepository _indexRepository;
  final WorldDriveHistoryLoader _driveLoader;
  final WorldCanonicalTelemetryLoader _telemetryLoader;
  final WorldIndexMutationPlanner _mutationPlanner;
  final WorldRecordProcessingService? _processingService;
  final DateTime Function() _clock;

  Future<WorldRebuildResult> rebuild({
    required DriveScoreAlgorithmVersion targetVersion,
    String reason = 'manualRebuild',
    Set<String> excludedDriveIds = const {},
    List<WorldRebuildBounds>? restrictToBounds,
  }) async {
    if (targetVersion != DriveScoreAlgorithmVersion.v1) {
      throw UnsupportedDriveScoreAlgorithmVersion(targetVersion.value);
    }
    var indexCorrupt = false;
    late final WorldIndexSnapshot base;
    try {
      base = await _indexRepository.getActiveSnapshot();
    } catch (_) {
      indexCorrupt = true;
      base = WorldIndexSnapshot.empty(
        driveScoreAlgorithmVersion: targetVersion.value,
        validatedRoadProcessingVersion: MyWorldRules.validatedRoadProcessingVersion,
      );
    }
    final drives = await _driveLoader();
    final driveById = {for (final drive in drives) drive.id: drive};
    final roads = await _repository.getAllValidatedRoads();
    final eligible = roads.where((road) {
      final drive = driveById[road.driveSessionId];
      return drive != null &&
          !excludedDriveIds.contains(road.driveSessionId) &&
          _roadInScope(road, restrictToBounds) &&
          (road.status == RoadValidationStatus.validated ||
              road.status == RoadValidationStatus.partiallyValidated) &&
          road.validDistanceMeters >= MyWorldRules.minimumValidDistanceMeters;
    }).toList()
      ..sort((a, b) {
        final date = driveById[a.driveSessionId]!.date
            .compareTo(driveById[b.driveSessionId]!.date);
        return date != 0 ? date : a.driveSessionId.compareTo(b.driveSessionId);
      });

    var staged = WorldIndexSnapshot.empty(
      driveScoreAlgorithmVersion: targetVersion.value,
      validatedRoadProcessingVersion: MyWorldRules.validatedRoadProcessingVersion,
    );
    if (restrictToBounds != null) {
      final retained = base.traces.where((trace) {
        final traceBounds = WorldRebuildBounds(
          minLatitude: trace.minLatitude,
          maxLatitude: trace.maxLatitude,
          minLongitude: trace.minLongitude,
          maxLongitude: trace.maxLongitude,
        );
        return !restrictToBounds.any((bounds) => bounds.containsBounds(traceBounds));
      }).toList(growable: false);
      staged = staged.copyWith(
        traces: retained,
        processedDriveSessionIds: base.processedDriveSessionIds
            .where((id) => !excludedDriveIds.contains(id))
            .toList(growable: false),
      );
    }
    var processed = 0;
    var skipped = drives.length - eligible.map((road) => road.driveSessionId).toSet().length;
    var missing = 0;
    try {
      final processor = _processingService ?? WorldRecordProcessingService(
        repository: _repository,
        indexRepository: _indexRepository,
        telemetryLoader: _telemetryLoader,
      );
      for (final road in eligible) {
        final telemetry = await _telemetryLoader(road.driveSessionId);
        final overlaps = await processor.analyzeOverlaps(
          staged.traces,
          road,
          telemetry,
          targetVersion,
        );
        final plan = _mutationPlanner.plan(
          current: staged,
          challengerRoad: road,
          overlaps: overlaps,
          now: _clock(),
          algorithmVersion: targetVersion,
        );
        staged = plan.resultingSnapshot;
        processed++;
      }
      missing = roads.where((road) => !eligible.contains(road)).length;
      final resultSnapshot = staged.copyWith(
        generation: base.generation + 1,
        operationId: 'world:rebuild:${_clock().toUtc().microsecondsSinceEpoch}',
        createdAt: _clock().toUtc(),
        operationReason: reason,
      );
      final plan = WorldIndexMutationPlan(
          operationId: resultSnapshot.operationId,
          sourceDriveSessionId: 'rebuild',
          baseGeneration: base.generation,
          tracesToRemove: base.traces,
          tracesToCreate: resultSnapshot.traces,
          resultingSnapshot: resultSnapshot,
        );
      if (indexCorrupt && _indexRepository is WorldIndexRecoveryRepository) {
        await (_indexRepository as WorldIndexRecoveryRepository)
            .activateRecoverySnapshot(resultSnapshot);
      } else {
        await _indexRepository.commit(plan);
      }
      return WorldRebuildResult(
        success: true,
        totalDrivesScanned: drives.length,
        drivesProcessed: processed,
        drivesSkipped: skipped,
        missingValidationCount: missing,
        resultingTraceCount: resultSnapshot.traces.length,
        totalWorldDistanceMeters: resultSnapshot.traces.fold(0, (s, t) => s + t.distanceMeters),
        targetAlgorithmVersion: targetVersion.value,
      );
    } catch (error) {
      return WorldRebuildResult(
        success: false,
        totalDrivesScanned: drives.length,
        drivesProcessed: processed,
        drivesSkipped: skipped,
        missingValidationCount: missing,
        resultingTraceCount: base.traces.length,
        totalWorldDistanceMeters: base.traces.fold(0, (s, t) => s + t.distanceMeters),
        targetAlgorithmVersion: targetVersion.value,
        failureReason: error.toString(),
      );
    }
  }

  bool _roadInScope(ValidatedRoad road, List<WorldRebuildBounds>? bounds) {
    if (bounds == null || bounds.isEmpty) return true;
    final points = road.sections.isNotEmpty
        ? road.sections.expand((section) => section.geometry)
        : road.geometry;
    if (points.isEmpty) return false;
    final roadBounds = WorldRebuildBounds(
      minLatitude: points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b),
      maxLatitude: points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b),
      minLongitude: points.map((point) => point.longitude).reduce((a, b) => a < b ? a : b),
      maxLongitude: points.map((point) => point.longitude).reduce((a, b) => a > b ? a : b),
    );
    return bounds.any((candidate) => candidate.containsBounds(roadBounds));
  }

  Future<WorldRebuildNeed> needsRebuild({
    required DriveScoreAlgorithmVersion targetVersion,
  }) async {
    try {
      final snapshot = await _indexRepository.getActiveSnapshot();
      return WorldRebuildNeed(
        needsRebuild: snapshot.driveScoreAlgorithmVersion != targetVersion.value,
        reason: snapshot.driveScoreAlgorithmVersion == targetVersion.value
            ? null
            : 'scoreAlgorithmChanged',
      );
    } catch (_) {
      return const WorldRebuildNeed(
        needsRebuild: true,
        reason: 'worldIndexCorrupt',
      );
    }
  }
}
