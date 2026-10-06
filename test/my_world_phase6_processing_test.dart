// Match the standalone adapter's relative domain library identity.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../tool/world_scoring_adapter.dart' as adapter;
import '../lib/features/drive_score/models/drive_score_algorithm_version.dart';
import '../lib/features/my_world/models/active_world_trace.dart';
import '../lib/features/my_world/models/matched_road_point.dart';
import '../lib/features/my_world/models/matched_road_section.dart';
import '../lib/features/my_world/models/validated_road.dart';
import '../lib/features/my_world/models/world_index_mutation_plan.dart';
import '../lib/features/my_world/models/world_index_snapshot.dart';
import '../lib/features/my_world/models/world_pending_job.dart';
import '../lib/features/my_world/models/world_processing.dart';
import '../lib/features/my_world/repositories/my_world_index_repository.dart';
import '../lib/features/my_world/repositories/my_world_repository.dart';
import '../lib/features/my_world/services/world_record_processing_service.dart';
import '../lib/features/my_world/services/world_index_mutation_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real processing orchestration clips active span before scoring eligibility',
    () async {
      final fixture =
          (jsonDecode(
                    File(
                      'test/fixtures/active_world_scoring.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .first;
      final existing = adapter.road(fixture['firstRoad']),
          challenger = adapter.road(fixture['secondRoad']);
      final repository = _WorldRepository(challenger, incumbent: existing);
      final service = WorldRecordProcessingService(
        repository: repository,
        indexRepository: _IndexRepository(),
        telemetryLoader: (_) async =>
            adapter.telemetry(fixture['firstTelemetry']),
      );
      for (final span in [2000.0, 2999.0, 3000.0]) {
        final trace = ActiveWorldTrace(
          id: 'trace',
          sourceDriveSessionId: existing.driveSessionId,
          validatedRoadId: existing.id,
          matchedSectionId: existing.sections.first.id,
          startOffsetMeters: 500,
          endOffsetMeters: 500 + span,
          directionKey: 'east',
          minLatitude: 0,
          maxLatitude: 0,
          minLongitude: 0,
          maxLongitude: .04,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          processingVersion: 3,
        );
        final analyses = await service.analyzeOverlaps(
          [trace],
          challenger,
          adapter.telemetry(fixture['secondTelemetry']),
          DriveScoreAlgorithmVersion.v1,
        );
        expect(analyses, hasLength(1));
        expect(analyses.single.matches.single.commonDistanceMeters, span);
        expect(analyses.single.matches.single.comparisonEligible, span >= 3000);
        if (span < 3000) {
          expect(analyses.single.winningRegions, isEmpty);
          final snapshot = WorldIndexSnapshot(
            generation: 1,
            operationId: 'previous',
            traces: [trace],
            processedDriveSessionIds: [existing.driveSessionId],
            driveScoreAlgorithmVersion: 1,
            validatedRoadProcessingVersion: 6,
            createdAt: DateTime.utc(2026),
          );
          final plan = const WorldIndexMutationPlanner().plan(
            current: snapshot,
            challengerRoad: challenger,
            overlaps: analyses,
            now: DateTime.utc(2026),
          );
          // Incumbent ownership survives even if the challenger would win a
          // full-source comparison. Only uncovered >=1km pieces can be added.
          expect(plan.resultingSnapshot.traces, contains(trace));
          expect(
            plan.resultingSnapshot.traces
                .where(
                  (t) => t.sourceDriveSessionId == challenger.driveSessionId,
                )
                .every(
                  (t) =>
                      t.endOffsetMeters <= trace.startOffsetMeters ||
                      t.startOffsetMeters >= trace.endOffsetMeters,
                ),
            isTrue,
          );
          expect(
            const WorldIndexMutationPlanner()
                .plan(
                  current: snapshot,
                  challengerRoad: challenger,
                  overlaps: analyses,
                  now: DateTime.utc(2026),
                )
                .resultingSnapshot
                .traces
                .map((t) => t.id),
            orderedEquals(plan.resultingSnapshot.traces.map((t) => t.id)),
          );
        } else {
          expect(analyses.single.winningRegions, isNotEmpty);
          expect(
            analyses.single.winningRegions.every(
              (r) =>
                  r.startOffsetOnExistingMeters >= 500 &&
                  r.endOffsetOnExistingMeters <= 500 + span,
            ),
            isTrue,
          );
        }
      }
    },
  );
  group('Phase 6 record processing commit order', () {
    test('marks a ready drive processed only after index commit', () async {
      final road = _road();
      final repository = _WorldRepository(road);
      final index = _IndexRepository();
      final service = WorldRecordProcessingService(
        repository: repository,
        indexRepository: index,
        telemetryLoader: (_) async => const [],
        clock: () => DateTime.utc(2026, 8, 12),
      );

      final result = await service.processReadyDrive('drive');

      expect(result.outcome, WorldRecordProcessingOutcome.processed);
      expect(index.active.hasProcessedDrive('drive'), isTrue);
      expect(repository.record.state, WorldProcessingState.processed);
    });

    test(
      'a commit failure keeps the old snapshot and never marks processed',
      () async {
        final road = _road();
        final repository = _WorldRepository(road);
        final index = _IndexRepository(failCommit: true);
        final service = WorldRecordProcessingService(
          repository: repository,
          indexRepository: index,
          telemetryLoader: (_) async => const [],
          clock: () => DateTime.utc(2026, 8, 12),
        );

        final result = await service.processReadyDrive('drive');

        expect(result.outcome, WorldRecordProcessingOutcome.failed);
        expect(index.active.generation, 0);
        expect(repository.record.state, WorldProcessingState.failedRetryable);
      },
    );
  });
}

class _WorldRepository implements MyWorldRepository {
  _WorldRepository(this.road, {this.incumbent})
    : record = WorldDriveProcessingRecord(
        driveSessionId: 'drive',
        state: WorldProcessingState.readyForWorldProcessing,
        validatedRoadId: road.id,
        lastError: null,
        updatedAt: DateTime.utc(2026, 8, 12),
      );

  final ValidatedRoad road;
  final ValidatedRoad? incumbent;
  late WorldDriveProcessingRecord record;

  @override
  Future<bool> enqueueIfAbsent(WorldPendingJob job) async => false;
  @override
  Future<WorldPendingJob?> getPendingJob(
    String driveSessionId,
    WorldJobType type,
  ) async => null;
  @override
  Future<List<WorldPendingJob>> getPendingJobs() async => const [];
  @override
  Future<WorldDriveProcessingRecord?> getProcessingRecord(
    String driveSessionId,
  ) async => record;
  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async => id == road.id
      ? road
      : id == incumbent?.id
      ? incumbent
      : null;
  @override
  Future<List<ValidatedRoad>> getValidatedRoadsForDrive(
    String driveSessionId,
  ) async => [road];
  @override
  Future<void> savePendingJob(WorldPendingJob job) async {}
  @override
  Future<void> saveProcessingRecord(WorldDriveProcessingRecord value) async =>
      record = value;
  @override
  Future<void> saveValidatedRoad(ValidatedRoad road) async {}
  @override
  Future<void> saveValidationBundle({
    ValidatedRoad? road,
    required WorldDriveProcessingRecord processing,
    required WorldPendingJob job,
  }) async => record = processing;
}

class _IndexRepository implements MyWorldIndexRepository {
  _IndexRepository({this.failCommit = false});
  final bool failCommit;
  WorldIndexSnapshot active = WorldIndexSnapshot.empty(
    driveScoreAlgorithmVersion: 1,
    validatedRoadProcessingVersion: 2,
  );

  @override
  Future<void> commit(WorldIndexMutationPlan plan) async {
    if (failCommit) throw StateError('simulated snapshot failure');
    active = plan.resultingSnapshot;
  }

  @override
  Future<double> activeDistanceForDrive(String driveSessionId) async => 0;
  @override
  Future<List<ActiveWorldTrace>> getActiveTraces() async => active.traces;
  @override
  Future<List<ActiveWorldTrace>> getActiveTracesForDrive(
    String driveSessionId,
  ) async => const [];
  @override
  Future<List<ActiveWorldTrace>> getActiveTracesInBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async => const [];
  @override
  Future<WorldIndexSnapshot> getActiveSnapshot() async => active;
  @override
  Future<bool> hasActiveTraceForDrive(String driveSessionId) async => false;
  @override
  Future<double> totalWorldDistance() async => 0;
}

ValidatedRoad _road() {
  const geometry = [
    MatchedRoadPoint(latitude: 41, longitude: 29, headingDegrees: 90),
    MatchedRoadPoint(latitude: 41, longitude: 29.04, headingDegrees: 90),
  ];
  return ValidatedRoad(
    id: 'road',
    driveSessionId: 'drive',
    geometry: geometry,
    sections: const [
      MatchedRoadSection(
        id: 'section',
        geometry: geometry,
        distanceMeters: 3000,
        confidence: 1,
        sourceTraceIndex: 0,
        sourceChunkIndex: 0,
      ),
    ],
    validDistanceMeters: 3000,
    status: RoadValidationStatus.validated,
    validatedAt: DateTime.utc(2026, 8, 12),
    providerId: 'test',
    confidence: 1,
    processingVersion: 2,
    directionKey: 'east',
    averageHeadingDegrees: 90,
    createdAt: DateTime.utc(2026, 8, 12),
    updatedAt: DateTime.utc(2026, 8, 12),
  );
}
