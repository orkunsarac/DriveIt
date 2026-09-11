// The explicit constructor assignments keep the public factory parameter
// names stable while the service fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

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
typedef WorldCanonicalTelemetryLoader =
    Future<List<CanonicalTelemetryPoint>> Function(String driveSessionId);
typedef WorldDriveEligibility = bool Function(String driveSessionId);

/// Explicit, source-history rebuild. It stages the complete result in memory
/// and activates one copy-on-write snapshot only after all invariants pass.
class MyWorldRebuildService {
  MyWorldRebuildService({
    required MyWorldSourceRepository repository,
    required MyWorldIndexRepository indexRepository,
    required WorldDriveHistoryLoader driveLoader,
    required WorldCanonicalTelemetryLoader telemetryLoader,
    WorldIndexMutationPlanner mutationPlanner =
        const WorldIndexMutationPlanner(),
    WorldRecordProcessingService? processingService,
    WorldDriveEligibility? driveEligibility,
    DateTime Function()? clock,
  }) : _repository = repository,
       _indexRepository = indexRepository,
       _driveLoader = driveLoader,
       _telemetryLoader = telemetryLoader,
       _mutationPlanner = mutationPlanner,
       _processingService = processingService,
       _driveEligibility = driveEligibility ?? ((_) => true),
       _clock = clock ?? DateTime.now;

  final MyWorldSourceRepository _repository;
  final MyWorldIndexRepository _indexRepository;
  final WorldDriveHistoryLoader _driveLoader;
  final WorldCanonicalTelemetryLoader _telemetryLoader;
  final WorldIndexMutationPlanner _mutationPlanner;
  final WorldRecordProcessingService? _processingService;
  final WorldDriveEligibility _driveEligibility;
  final DateTime Function() _clock;

  Future<WorldRebuildResult> rebuild({
    required DriveScoreAlgorithmVersion targetVersion,
    String reason = 'manualRebuild',
    Set<String> excludedDriveIds = const {},
    List<WorldRebuildBounds>? restrictToBounds,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[WORLD_RULES] minimumValidatedDrive=${MyWorldRules.minimumValidDistanceMeters.toInt()} '
        'minimumComparableOverlap=${MyWorldRules.minimumCommonWorldDistanceMeters.toInt()} '
        'minimumWinningRegion=${MyWorldRules.minimumLocalWinningRegionMeters.toInt()} '
        'minimumActiveTrace=${MyWorldRules.minimumActiveTraceMeters.toInt()} '
        'minimumRemainder=${MyWorldRules.minimumVisibleRemainderMeters.toInt()} '
        'gapMerge=${MyWorldRules.localScoreWinnerGapToleranceMeters.toInt()} '
        'version=${MyWorldRules.worldRulesVersion}',
      );
    }
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
        validatedRoadProcessingVersion: MyWorldRules.worldRulesVersion,
      );
    }
    final drives = await _driveLoader();
    final driveById = {for (final drive in drives) drive.id: drive};
    final roads = await _repository.getAllValidatedRoads();
    final eligible =
        roads.where((road) {
          final drive = driveById[road.driveSessionId];
          return drive != null &&
              _driveEligibility(road.driveSessionId) &&
              road.processingVersion ==
                  MyWorldRules.validatedRoadProcessingVersion &&
              !excludedDriveIds.contains(road.driveSessionId) &&
              _roadInScope(road, restrictToBounds) &&
              (road.status == RoadValidationStatus.validated ||
                  road.status == RoadValidationStatus.partiallyValidated) &&
              road.validDistanceMeters >=
                  MyWorldRules.minimumValidDistanceMeters;
        }).toList()..sort((a, b) {
          final date = driveById[a.driveSessionId]!.date.compareTo(
            driveById[b.driveSessionId]!.date,
          );
          return date != 0
              ? date
              : a.driveSessionId.compareTo(b.driveSessionId);
        });

    var staged = WorldIndexSnapshot.empty(
      driveScoreAlgorithmVersion: targetVersion.value,
      validatedRoadProcessingVersion: MyWorldRules.worldRulesVersion,
    );
    if (restrictToBounds != null) {
      final retained = base.traces
          .where((trace) {
            final traceBounds = WorldRebuildBounds(
              minLatitude: trace.minLatitude,
              maxLatitude: trace.maxLatitude,
              minLongitude: trace.minLongitude,
              maxLongitude: trace.maxLongitude,
            );
            return !restrictToBounds.any(
              (bounds) => bounds.containsBounds(traceBounds),
            );
          })
          .toList(growable: false);
      staged = staged.copyWith(
        traces: retained,
        processedDriveSessionIds: base.processedDriveSessionIds
            .where((id) => !excludedDriveIds.contains(id))
            .toList(growable: false),
      );
    }
    var processed = 0;
    var skipped =
        drives.length -
        eligible.map((road) => road.driveSessionId).toSet().length;
    final eligibleDriveIds = eligible
        .map((road) => road.driveSessionId)
        .toSet();
    final skippedUnder5Km = drives.where((drive) {
      if (eligibleDriveIds.contains(drive.id)) return false;
      final driveRoads = roads.where((road) => road.driveSessionId == drive.id);
      return driveRoads.isNotEmpty &&
          driveRoads.every(
            (road) =>
                road.validDistanceMeters <
                MyWorldRules.minimumValidDistanceMeters,
          );
    }).length;
    var missing = 0;
    try {
      final processor =
          _processingService ??
          WorldRecordProcessingService(
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
      if (kDebugMode) {
        debugPrint(
          '[WORLD_REBUILD] driveCount=${drives.length} '
          'eligibleDriveCount=${eligible.map((road) => road.driveSessionId).toSet().length} '
          'skippedUnder5km=$skippedUnder5Km '
          'activeTraceCount=${resultSnapshot.traces.length} '
          'uniqueSourceDriveCount=${resultSnapshot.traces.map((t) => t.sourceDriveSessionId).toSet().length} '
          'displayedWorldDriveCount=${resultSnapshot.traces.length} '
          'activeDistanceMeters=${resultSnapshot.traces.fold<double>(0, (s, t) => s + t.distanceMeters).toStringAsFixed(1)} '
          'generation=${resultSnapshot.generation}',
        );
        debugPrint(
          '[WORLD_COUNT] activeTraceCount=${resultSnapshot.traces.length} '
          'uniqueSourceDriveCount=${resultSnapshot.traces.map((t) => t.sourceDriveSessionId).toSet().length} '
          'displayedWorldDriveCount=${resultSnapshot.traces.length}',
        );
        for (final trace in resultSnapshot.traces.where(
          (trace) =>
              trace.distanceMeters < MyWorldRules.minimumActiveTraceMeters,
        )) {
          debugPrint(
            '[WORLD_SHORT_TRACE] traceId=${trace.id} '
            'sourceDriveId=${trace.sourceDriveSessionId} '
            'lengthMeters=${trace.distanceMeters} visible=false',
          );
        }
      }
      return WorldRebuildResult(
        success: true,
        totalDrivesScanned: drives.length,
        drivesProcessed: processed,
        drivesSkipped: skipped,
        missingValidationCount: missing,
        resultingTraceCount: resultSnapshot.traces.length,
        totalWorldDistanceMeters: resultSnapshot.traces.fold(
          0,
          (s, t) => s + t.distanceMeters,
        ),
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
        totalWorldDistanceMeters: base.traces.fold(
          0,
          (s, t) => s + t.distanceMeters,
        ),
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
      minLatitude: points
          .map((point) => point.latitude)
          .reduce((a, b) => a < b ? a : b),
      maxLatitude: points
          .map((point) => point.latitude)
          .reduce((a, b) => a > b ? a : b),
      minLongitude: points
          .map((point) => point.longitude)
          .reduce((a, b) => a < b ? a : b),
      maxLongitude: points
          .map((point) => point.longitude)
          .reduce((a, b) => a > b ? a : b),
    );
    return bounds.any((candidate) => candidate.containsBounds(roadBounds));
  }

  Future<WorldRebuildNeed> needsRebuild({
    required DriveScoreAlgorithmVersion targetVersion,
  }) async {
    try {
      final snapshot = await _indexRepository.getActiveSnapshot();
      final scoreVersionChanged =
          snapshot.driveScoreAlgorithmVersion != targetVersion.value;
      final worldRulesChanged =
          snapshot.validatedRoadProcessingVersion !=
          MyWorldRules.worldRulesVersion;
      return WorldRebuildNeed(
        needsRebuild: scoreVersionChanged || worldRulesChanged,
        reason: scoreVersionChanged
            ? 'scoreAlgorithmChanged'
            : worldRulesChanged
            ? 'worldRulesChanged'
            : null,
      );
    } catch (_) {
      return const WorldRebuildNeed(
        needsRebuild: true,
        reason: 'worldIndexCorrupt',
      );
    }
  }
}
