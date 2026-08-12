import 'dart:math' as math;

import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../models/active_world_trace.dart';
import '../models/local_winning_road_region.dart';
import '../models/validated_road.dart';
import '../models/world_processing.dart';
import '../models/world_trace_overlap_analysis.dart';
import '../repositories/my_world_index_repository.dart';
import '../repositories/my_world_repository.dart';
import 'local_winning_road_region_service.dart';
import 'world_index_mutation_planner.dart';
import 'world_road_overlap_service.dart';

typedef WorldTelemetryLoader = Future<List<CanonicalTelemetryPoint>> Function(
  String driveSessionId,
);

enum WorldRecordProcessingOutcome { processed, alreadyProcessed, notReady, failed }

class WorldRecordProcessingResult {
  const WorldRecordProcessingResult({
    required this.outcome,
    required this.traceCount,
    required this.reason,
  });
  final WorldRecordProcessingOutcome outcome;
  final int traceCount;
  final String? reason;
}

/// Coordinates Phase 3-5 source-of-truth services with a single copy-on-write
/// World-index commit. It performs no UI, backfill, deletion, or rebuild work.
class WorldRecordProcessingService {
  factory WorldRecordProcessingService({
    required MyWorldRepository repository,
    required MyWorldIndexRepository indexRepository,
    required WorldTelemetryLoader telemetryLoader,
    WorldRoadOverlapService overlapService = const WorldRoadOverlapService(),
    LocalWinningRoadRegionService winnerRegionService =
        const LocalWinningRoadRegionService(),
    WorldIndexMutationPlanner mutationPlanner = const WorldIndexMutationPlanner(),
    DateTime Function()? clock,
  }) => WorldRecordProcessingService._(
    repository,
    indexRepository,
    telemetryLoader,
    overlapService,
    winnerRegionService,
    mutationPlanner,
    clock ?? DateTime.now,
  );

  WorldRecordProcessingService._(
    this._repository,
    this._indexRepository,
    this._telemetryLoader,
    this._overlapService,
    this._winnerRegionService,
    this._mutationPlanner,
    this._clock,
  );

  final MyWorldRepository _repository;
  final MyWorldIndexRepository _indexRepository;
  final WorldTelemetryLoader _telemetryLoader;
  final WorldRoadOverlapService _overlapService;
  final LocalWinningRoadRegionService _winnerRegionService;
  final WorldIndexMutationPlanner _mutationPlanner;
  final DateTime Function() _clock;

  Future<WorldRecordProcessingResult> processReadyDrive(
    String driveSessionId, {
    DriveScoreAlgorithmVersion algorithmVersion =
        DriveScoreAlgorithmVersion.v1,
  }) async {
    final record = await _repository.getProcessingRecord(driveSessionId);
    if (record?.state != WorldProcessingState.readyForWorldProcessing &&
        record?.state != WorldProcessingState.processing) {
      return const WorldRecordProcessingResult(
        outcome: WorldRecordProcessingOutcome.notReady,
        traceCount: 0,
        reason: 'Drive is not ready for World record processing.',
      );
    }
    final roadId = record?.validatedRoadId;
    if (roadId == null) {
      return const WorldRecordProcessingResult(
        outcome: WorldRecordProcessingOutcome.failed,
        traceCount: 0,
        reason: 'Ready World processing record has no validated road.',
      );
    }
    final challenger = await _repository.getValidatedRoad(roadId);
    if (challenger == null) {
      return const WorldRecordProcessingResult(
        outcome: WorldRecordProcessingOutcome.failed,
        traceCount: 0,
        reason: 'Validated road is unavailable.',
      );
    }

    final snapshot = await _indexRepository.getActiveSnapshot();
    if (snapshot.hasProcessedDrive(driveSessionId)) {
      // Recovery after a crash between atomic index activation and the
      // secondary processing-record write is safe and idempotent.
      if (record?.state != WorldProcessingState.processed) {
        await _markProcessed(driveSessionId, challenger.id);
      }
      return WorldRecordProcessingResult(
        outcome: WorldRecordProcessingOutcome.alreadyProcessed,
        traceCount: snapshot.traces
            .where((trace) => trace.sourceDriveSessionId == driveSessionId)
            .length,
        reason: null,
      );
    }

    try {
      final challengerTelemetry = await _telemetryLoader(driveSessionId);
      final overlaps = await analyzeOverlaps(
        snapshot.traces,
        challenger,
        challengerTelemetry,
        algorithmVersion,
      );
      final plan = _mutationPlanner.plan(
        current: snapshot,
        challengerRoad: challenger,
        overlaps: overlaps,
        now: _clock(),
        algorithmVersion: algorithmVersion,
      );
      await _indexRepository.commit(plan);
      await _markProcessed(driveSessionId, challenger.id);
      return WorldRecordProcessingResult(
        outcome: WorldRecordProcessingOutcome.processed,
        traceCount: plan.resultingSnapshot.traces
            .where((trace) => trace.sourceDriveSessionId == driveSessionId)
            .length,
        reason: null,
      );
    } catch (error) {
      // Index mutation is copy-on-write; a failed plan or commit leaves the
      // old active generation in place. The normal DriveSession is untouched.
      await _repository.saveProcessingRecord(WorldDriveProcessingRecord(
        driveSessionId: driveSessionId,
        state: WorldProcessingState.failedRetryable,
        validatedRoadId: challenger.id,
        lastError: error.toString(),
        updatedAt: _clock().toUtc(),
      ));
      return WorldRecordProcessingResult(
        outcome: WorldRecordProcessingOutcome.failed,
        traceCount: 0,
        reason: error.toString(),
      );
    }
  }

  Future<List<WorldTraceOverlapAnalysis>> analyzeOverlaps(
    List<ActiveWorldTrace> traces,
    ValidatedRoad challenger,
    List<CanonicalTelemetryPoint> challengerTelemetry,
    DriveScoreAlgorithmVersion algorithmVersion,
  ) async {
    final output = <WorldTraceOverlapAnalysis>[];
    final cache = <String, _ExistingRoadData?>{};
    for (final trace in _candidateTraces(traces, challenger)) {
      // A road-wide direction key is metadata for the full source drive and
      // may differ when two drives share only a subsection. The Phase 3
      // geometry service remains the source of truth for same-direction
      // compatibility at the actual overlapping section.
      final existing = await _existingRoadData(trace, cache);
      if (existing == null) continue;
      final matches = _overlapService.findCommonRoads(existing.road, challenger);
      if (matches.isEmpty) continue;
      final regions = <LocalWinningRoadRegion>[];
      for (final match in matches.where((match) => match.comparisonEligible)) {
        final analysis = _winnerRegionService.analyze(
          match: match,
          existingRoad: existing.road,
          existingTelemetry: existing.telemetry,
          challengerRoad: challenger,
          challengerTelemetry: challengerTelemetry,
          algorithmVersion: algorithmVersion,
        );
        if (analysis.status == LocalRoadRegionAnalysisStatus.success) {
          regions.addAll(analysis.winningRegions);
        }
      }
      output.add(WorldTraceOverlapAnalysis(
        existingTrace: trace,
        matches: matches,
        winningRegions: regions,
      ));
    }
    return output;
  }

  Future<_ExistingRoadData?> _existingRoadData(
    ActiveWorldTrace trace,
    Map<String, _ExistingRoadData?> cache,
  ) async {
    if (cache.containsKey(trace.validatedRoadId)) return cache[trace.validatedRoadId];
    final road = await _repository.getValidatedRoad(trace.validatedRoadId);
    if (road == null) return cache[trace.validatedRoadId] = null;
    final telemetry = await _telemetryLoader(trace.sourceDriveSessionId);
    return cache[trace.validatedRoadId] = _ExistingRoadData(road, telemetry);
  }

  Iterable<ActiveWorldTrace> _candidateTraces(
    List<ActiveWorldTrace> traces,
    ValidatedRoad challenger,
  ) {
    final geometry = challenger.sections.isNotEmpty
        ? challenger.sections.expand((section) => section.geometry)
        : challenger.geometry;
    if (geometry.isEmpty) return const [];
    var minLatitude = geometry.first.latitude;
    var maxLatitude = minLatitude;
    var minLongitude = geometry.first.longitude;
    var maxLongitude = minLongitude;
    for (final point in geometry.skip(1)) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }
    // Coarse filtering avoids full Phase 3 geometry comparison for unrelated
    // World traces; precise same-road/direction validation still belongs to
    // WorldRoadOverlapService.
    return traces.where(
      (trace) => trace.intersectsBounds(
        minLatitude: minLatitude,
        maxLatitude: maxLatitude,
        minLongitude: minLongitude,
        maxLongitude: maxLongitude,
      ),
    );
  }

  Future<void> _markProcessed(String driveSessionId, String roadId) =>
      _repository.saveProcessingRecord(WorldDriveProcessingRecord(
        driveSessionId: driveSessionId,
        state: WorldProcessingState.processed,
        validatedRoadId: roadId,
        lastError: null,
        updatedAt: _clock().toUtc(),
      ));
}

class _ExistingRoadData {
  const _ExistingRoadData(this.road, this.telemetry);
  final ValidatedRoad road;
  final List<CanonicalTelemetryPoint> telemetry;
}
