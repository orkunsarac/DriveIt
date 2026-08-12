import 'dart:math' as math;

import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/common_road_match.dart';
import 'package:driveit_project/features/my_world/models/local_winning_road_region.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/models/world_trace_overlap_analysis.dart';
import 'package:driveit_project/features/my_world/services/world_index_mutation_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = WorldIndexMutationPlanner();
  final now = DateTime.utc(2026, 8, 12);

  group('Phase 6 World index mutation planning', () {
    test('an empty World adds one full active trace for one section', () {
      final road = _road('challenger', 8000);
      final plan = planner.plan(
        current: _empty(),
        challengerRoad: road,
        overlaps: const [],
        now: now,
      );

      expect(plan.resultingSnapshot.traces, hasLength(1));
      expect(plan.resultingSnapshot.traces.single.distanceMeters, closeTo(8000, .1));
      expect(plan.resultingSnapshot.hasProcessedDrive('challenger-drive'), isTrue);
    });

    test('disconnected sections stay as independent first-record traces', () {
      final road = _road('challenger', 8000, split: true);
      final plan = planner.plan(
        current: _empty(),
        challengerRoad: road,
        overlaps: const [],
        now: now,
      );

      expect(plan.resultingSnapshot.traces, hasLength(2));
      expect(
        plan.resultingSnapshot.traces.map((trace) => trace.distanceMeters),
        everyElement(closeTo(4000, .1)),
      );
    });

    test('a middle winner splits existing into existing/challenger/existing', () {
      final existingRoad = _road('existing', 10000);
      final challenger = _road('challenger', 10000);
      final existingTrace = _trace(existingRoad, 0, 10000);
      final plan = planner.plan(
        current: _snapshot([existingTrace]),
        challengerRoad: challenger,
        overlaps: [
          _overlap(existingTrace, _match(10000), [_winner(4000, 5500)]),
        ],
        now: now,
      );

      final traces = plan.resultingSnapshot.traces;
      expect(traces, hasLength(3));
      expect(
        traces.where((trace) => trace.sourceDriveSessionId == 'existing-drive').map((trace) => trace.distanceMeters),
        unorderedEquals([4000.0, 4500.0]),
      );
      expect(
        traces.where((trace) => trace.sourceDriveSessionId == 'challenger-drive').single.distanceMeters,
        1500.0,
      );
    });

    test('start, end, and full replacements avoid empty remainders', () {
      final existingRoad = _road('existing', 5000);
      final challenger = _road('challenger', 5000);
      for (final winner in <(double, double)>[(0, 2000), (3000, 5000), (0, 5000)]) {
        final existingTrace = _trace(existingRoad, 0, 5000);
        final plan = planner.plan(
          current: _snapshot([existingTrace]),
          challengerRoad: challenger,
          overlaps: [_overlap(existingTrace, _match(5000), [_winner(winner.$1, winner.$2)])],
          now: now,
        );
        expect(plan.resultingSnapshot.traces.every((trace) => trace.distanceMeters > 0), isTrue);
        expect(
          plan.resultingSnapshot.traces.length,
          winner == (0.0, 5000.0) ? 1 : 2,
        );
      }
    });

    test('two winner regions create five alternating dynamic traces', () {
      final existingRoad = _road('existing', 10000);
      final challenger = _road('challenger', 10000);
      final trace = _trace(existingRoad, 0, 10000);
      final plan = planner.plan(
        current: _snapshot([trace]),
        challengerRoad: challenger,
        overlaps: [
          _overlap(trace, _match(10000), [_winner(1000, 1800), _winner(3500, 4300)]),
        ],
        now: now,
      );
      expect(plan.resultingSnapshot.traces, hasLength(5));
      expect(
        plan.resultingSnapshot.traces.where((trace) => trace.sourceDriveSessionId == 'existing-drive'),
        hasLength(3),
      );
      expect(
        plan.resultingSnapshot.traces.where((trace) => trace.sourceDriveSessionId == 'challenger-drive'),
        hasLength(2),
      );
    });

    test('covered short overlap stays with existing while new challenger road remains', () {
      final existingRoad = _road('existing', 300);
      final challenger = _road('challenger', 4300);
      final trace = _trace(existingRoad, 0, 300);
      final plan = planner.plan(
        current: _snapshot([trace]),
        challengerRoad: challenger,
        overlaps: [_overlap(trace, _match(300), const [])],
        now: now,
      );
      expect(plan.resultingSnapshot.traces, hasLength(2));
      expect(
        plan.resultingSnapshot.traces.singleWhere((trace) => trace.sourceDriveSessionId == 'existing-drive').distanceMeters,
        closeTo(300, .1),
      );
      final newTrace = plan.resultingSnapshot.traces.singleWhere(
        (trace) => trace.sourceDriveSessionId == 'challenger-drive',
      );
      expect(newTrace.startOffsetMeters, closeTo(300, .1));
      expect(newTrace.endOffsetMeters, closeTo(4300, .1));
    });

    test('adjacent same-source intervals merge, but different sources never merge', () {
      final road = _road('existing', 3000);
      final a = _trace(road, 0, 1500);
      final b = _trace(road, 1500, 3000);
      final challenger = _road('challenger', 1000, sectionId: 'other');
      final merged = planner.plan(
        current: _snapshot([a, b]),
        challengerRoad: challenger,
        overlaps: const [],
        now: now,
      );
      expect(
        merged.resultingSnapshot.traces.where((trace) => trace.sourceDriveSessionId == 'existing-drive'),
        hasLength(1),
      );
    });

    test('real short existing remainder survives an ownership split', () {
      final existingRoad = _road('existing', 1000);
      final challenger = _road('challenger', 1000);
      final trace = _trace(existingRoad, 0, 1000);
      final plan = planner.plan(
        current: _snapshot([trace]),
        challengerRoad: challenger,
        overlaps: [_overlap(trace, _match(1000), [_winner(500, 1000)])],
        now: now,
      );
      expect(plan.resultingSnapshot.traces.first.distanceMeters, closeTo(500, .1));
    });

    test('processing operation is deterministic and snapshot metadata advances once', () {
      final road = _road('challenger', 5000);
      final first = planner.plan(
        current: _empty(), challengerRoad: road, overlaps: const [], now: now,
      );
      final second = planner.plan(
        current: _empty(), challengerRoad: road, overlaps: const [], now: now,
      );
      expect(first.operationId, second.operationId);
      expect(first.resultingSnapshot.generation, 1);
      expect(first.resultingSnapshot.driveScoreAlgorithmVersion, 1);
      expect(first.resultingSnapshot.validatedRoadProcessingVersion, 2);
    });
  });
}

WorldIndexSnapshot _empty() => WorldIndexSnapshot.empty(
  driveScoreAlgorithmVersion: 1,
  validatedRoadProcessingVersion: 2,
);

WorldIndexSnapshot _snapshot(List<ActiveWorldTrace> traces) => WorldIndexSnapshot(
  generation: 0,
  operationId: 'initial',
  traces: traces,
  processedDriveSessionIds: const [],
  driveScoreAlgorithmVersion: 1,
  validatedRoadProcessingVersion: 2,
  createdAt: DateTime.utc(2026, 8, 12),
);

ValidatedRoad _road(String id, double distance, {bool split = false, String? sectionId}) {
  final sections = split
      ? [
          _section('$id:a', 0, distance / 2),
          _section('$id:b', distance / 2, distance),
        ]
      : [_section(sectionId ?? '$id:geometry', 0, distance)];
  return ValidatedRoad(
    id: id,
    driveSessionId: '$id-drive',
    geometry: sections.expand((section) => section.geometry).toList(),
    sections: sections,
    validDistanceMeters: distance,
    status: RoadValidationStatus.validated,
    validatedAt: DateTime.utc(2026, 8, 12),
    providerId: 'test',
    confidence: 1,
    processingVersion: 2,
    directionKey: 'eastbound',
    averageHeadingDegrees: 90,
    createdAt: DateTime.utc(2026, 8, 12),
    updatedAt: DateTime.utc(2026, 8, 12),
  );
}

MatchedRoadSection _section(String id, double start, double end) => MatchedRoadSection(
  id: id,
  geometry: [_point(start), _point(end)],
  distanceMeters: end - start,
  confidence: 1,
  sourceTraceIndex: 0,
  sourceChunkIndex: 0,
);

ActiveWorldTrace _trace(ValidatedRoad road, double start, double end) => ActiveWorldTrace(
  id: '${road.id}:$start:$end',
  sourceDriveSessionId: road.driveSessionId,
  validatedRoadId: road.id,
  matchedSectionId: road.sections.first.id,
  startOffsetMeters: start,
  endOffsetMeters: end,
  directionKey: road.directionKey,
  minLatitude: 41,
  maxLatitude: 41,
  minLongitude: 29,
  maxLongitude: 29.2,
  createdAt: DateTime.utc(2026, 8, 12),
  updatedAt: DateTime.utc(2026, 8, 12),
  processingVersion: 2,
);

WorldTraceOverlapAnalysis _overlap(
  ActiveWorldTrace trace,
  CommonRoadMatch match,
  List<LocalWinningRoadRegion> winners,
) => WorldTraceOverlapAnalysis(existingTrace: trace, matches: [match], winningRegions: winners);

CommonRoadMatch _match(double distance) => CommonRoadMatch(
  firstDriveId: 'existing-drive',
  secondDriveId: 'challenger-drive',
  firstSectionId: 'existing:geometry',
  secondSectionId: 'challenger:geometry',
  firstStartOffsetMeters: 0,
  firstEndOffsetMeters: distance,
  secondStartOffsetMeters: 0,
  secondEndOffsetMeters: distance,
  commonStart: _point(0),
  commonEnd: _point(distance),
  commonDistanceMeters: distance,
  directionCompatible: true,
  geometryConfidence: 1,
  comparisonEligible: distance >= 1000,
  referenceGeometry: [_point(0), _point(distance)],
);

LocalWinningRoadRegion _winner(double start, double end) => LocalWinningRoadRegion(
  existingDriveId: 'existing-drive',
  challengerDriveId: 'challenger-drive',
  match: _match(10000),
  startOffsetOnExistingMeters: start,
  endOffsetOnExistingMeters: end,
  startOffsetOnChallengerMeters: start,
  endOffsetOnChallengerMeters: end,
  commonStartOffsetMeters: start,
  commonEndOffsetMeters: end,
  winningDistanceMeters: end - start,
  algorithmVersion: DriveScoreAlgorithmVersion.v1,
  confidence: 1,
  supportingWindowCount: ((end - start) / 100).round(),
);

MatchedRoadPoint _point(double meters) => MatchedRoadPoint(
  latitude: 41,
  longitude: 29 + meters / (111320 * math.cos(41 * math.pi / 180)),
  headingDegrees: 90,
);
