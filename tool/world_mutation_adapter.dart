// No ownership port: invoke the actual pure My World planner.
// ignore_for_file: avoid_relative_lib_imports
import 'world_scoring_adapter.dart';
import '../lib/features/drive_score/models/drive_score_algorithm_version.dart';
import '../lib/features/my_world/models/active_world_trace.dart';
import '../lib/features/my_world/models/local_winning_road_region.dart';
import '../lib/features/my_world/models/world_index_snapshot.dart';
import '../lib/features/my_world/models/world_trace_overlap_analysis.dart';
import '../lib/features/my_world/services/world_index_mutation_planner.dart';

ActiveWorldTrace mutationTrace(Json t) => ActiveWorldTrace(
  id: t['id'],
  sourceDriveSessionId: t['sourceDriveId'],
  validatedRoadId: t['validatedRoadId'],
  matchedSectionId: t['matchedSectionId'],
  startOffsetMeters: number(t, 'startOffsetMeters'),
  endOffsetMeters: number(t, 'endOffsetMeters'),
  directionKey: t['directionKey'],
  minLatitude: number(t, 'minLatitude'),
  maxLatitude: number(t, 'maxLatitude'),
  minLongitude: number(t, 'minLongitude'),
  maxLongitude: number(t, 'maxLongitude'),
  processingVersion: t['processingVersion'],
  createdAt: DateTime.parse(t['createdAt']),
  updatedAt: DateTime.parse(t['updatedAt']),
);
Json mutationTraceJson(ActiveWorldTrace t) => {
  'id': t.id,
  'sourceDriveId': t.sourceDriveSessionId,
  'validatedRoadId': t.validatedRoadId,
  'matchedSectionId': t.matchedSectionId,
  'startOffsetMeters': t.startOffsetMeters.toString(),
  'endOffsetMeters': t.endOffsetMeters.toString(),
  'directionKey': t.directionKey,
  'minLatitude': t.minLatitude.toString(),
  'maxLatitude': t.maxLatitude.toString(),
  'minLongitude': t.minLongitude.toString(),
  'maxLongitude': t.maxLongitude.toString(),
  'processingVersion': t.processingVersion,
  'createdAt': t.createdAt.toUtc().toIso8601String(),
  'updatedAt': t.updatedAt.toUtc().toIso8601String(),
};

Json evaluateWorldMutation(Json input) {
  final now = DateTime.parse(input['now']);
  final traces = (input['traces'] as List)
      .map((t) => mutationTrace(t as Json))
      .toList();
  final byId = {for (final t in traces) t.id: t};
  final overlaps = (input['inputs'] as List).map((i) {
    final match = decodeMatch(i['match']);
    return WorldTraceOverlapAnalysis(
      existingTrace: byId[i['traceId']]!,
      matches: [match],
      winningRegions: (i['regions'] as List)
          .map(
            (r) => LocalWinningRoadRegion(
              existingDriveId: r['existingDriveId'],
              challengerDriveId: r['challengerDriveId'],
              match: match,
              startOffsetOnExistingMeters: number(
                r,
                'startOffsetOnExistingMeters',
              ),
              endOffsetOnExistingMeters: number(r, 'endOffsetOnExistingMeters'),
              startOffsetOnChallengerMeters: number(
                r,
                'startOffsetOnChallengerMeters',
              ),
              endOffsetOnChallengerMeters: number(
                r,
                'endOffsetOnChallengerMeters',
              ),
              commonStartOffsetMeters: number(r, 'commonStartOffsetMeters'),
              commonEndOffsetMeters: number(r, 'commonEndOffsetMeters'),
              winningDistanceMeters: number(r, 'winningDistanceMeters'),
              algorithmVersion: DriveScoreAlgorithmVersion.v1,
              confidence: number(r, 'confidence'),
              supportingWindowCount: r['supportingWindowCount'],
            ),
          )
          .toList(),
    );
  }).toList();
  // Group every match/region for one trace BEFORE planning. Dart's planner
  // assigns one replacement per trace; per-match planning could lose a split.
  final grouped = <String, WorldTraceOverlapAnalysis>{};
  for (final o in overlaps) {
    final previous = grouped[o.existingTrace.id];
    grouped[o.existingTrace.id] = WorldTraceOverlapAnalysis(
      existingTrace: o.existingTrace,
      matches: [...?previous?.matches, ...o.matches],
      winningRegions: [...?previous?.winningRegions, ...o.winningRegions],
    );
  }
  final plan = const WorldIndexMutationPlanner().plan(
    // Generation arithmetic is lifted to TS BigInt/SQL bigint. Planner only
    // uses generation for +1 metadata, never for ownership or trace IDs.
    current: WorldIndexSnapshot(
      generation: 0,
      operationId: 'input',
      traces: traces,
      processedDriveSessionIds: const [],
      driveScoreAlgorithmVersion: 1,
      validatedRoadProcessingVersion: 6,
      createdAt: now,
    ),
    challengerRoad: road(input['challenger']),
    overlaps: grouped.values.toList(),
    now: now,
  );
  return {
    'operationId': plan.operationId,
    'traces': plan.resultingSnapshot.traces.map(mutationTraceJson).toList(),
  };
}
