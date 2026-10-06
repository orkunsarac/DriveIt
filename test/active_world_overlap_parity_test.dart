import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/common_road_match.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/models/world_trace_overlap_analysis.dart';
import 'package:driveit_project/features/my_world/services/world_index_mutation_planner.dart';
import 'package:driveit_project/features/my_world/services/world_road_overlap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = jsonDecode(File('test/fixtures/active_world_overlap_parity.json').readAsStringSync()) as Map;
  const overlap = WorldRoadOverlapService();
  final exported = <String, dynamic>{};
  final oracleFile = File('test/fixtures/active_world_overlap_dart_oracle.json');
  final oracle = jsonDecode(oracleFile.readAsStringSync()) as Map;
  for (final c in fixture['cases'] as List) {
    final first = road('first', c['first'] as List);
    final second = road('second', c['second'] as List);
    final matches = overlap.findCommonRoads(first, second);
    exported[c['name'] as String] = matches.map(serializeMatch).toList();
    test('Dart overlap source-of-truth: ${c['name']}', () {
      expect(matches, hasLength(c['count'] as int));
      for (final m in matches) {
        expect(m.comparisonEligible, c['eligible']);
        expect(m.ownershipCovered, isTrue);
      }
      expect(matches.map(serializeMatch).toList(), oracle[c['name']]);
    });
  }
  // Explicit test-only oracle export: stdout, synthetic geometry only.
  if (Platform.environment['WORLD_OVERLAP_EXPORT'] == '1') {
    stdout.writeln('WORLD_OVERLAP_ORACLE=${jsonEncode(exported)}');
  }
  test('partial trace coverage uses My World planner clipping, not full source', () {
    final c = (fixture['cases'] as List).firstWhere((c) => c['name'] == 'partial-active-span');
    final first = road('first', c['first'] as List), second = road('second', c['second'] as List);
    final now = DateTime.utc(2026);
    final trace = ActiveWorldTrace(id: 'trace', sourceDriveSessionId: first.driveSessionId,
      validatedRoadId: first.id, matchedSectionId: 'a', startOffsetMeters: 500,
      endOffsetMeters: 2000, directionKey: 'unrelated', minLatitude: 41,
      maxLatitude: 41, minLongitude: 29, maxLongitude: 29 + 4000 / 84000,
      createdAt: now, updatedAt: now, processingVersion: 3);
    final snapshot = WorldIndexSnapshot(generation: 1, operationId: 'previous',
      traces: [trace], processedDriveSessionIds: [first.driveSessionId],
      driveScoreAlgorithmVersion: 1, validatedRoadProcessingVersion: 6,
      createdAt: now, operationReason: 'recordProcessing');
    final plan = const WorldIndexMutationPlanner().plan(current: snapshot,
      challengerRoad: second, overlaps: [WorldTraceOverlapAnalysis(existingTrace: trace,
        matches: overlap.findCommonRoads(first, second), winningRegions: const [])],
      now: now, algorithmVersion: DriveScoreAlgorithmVersion.v1);
    final challenger = plan.resultingSnapshot.traces.where((t) => t.sourceDriveSessionId == second.driveSessionId).toList();
    expect(challenger, hasLength(1));
    expect(challenger.single.startOffsetMeters, 2000);
    expect(challenger.single.endOffsetMeters, 4000);
    expect(plan.resultingSnapshot.traces, contains(trace));
  });
}

ValidatedRoad road(String id, List sections) {
  final parsed = sections.map((s) => MatchedRoadSection(id: s['id'] as String,
    distanceMeters: (s['distance'] as num).toDouble(), geometry: [
      for (final p in s['points'] as List) MatchedRoadPoint(
        latitude: 41 + (p[1] as num) / 111320, longitude: 29 + (p[0] as num) / 84000)],
    confidence: 1, sourceTraceIndex: 0, sourceChunkIndex: 0)).toList();
  final now = DateTime.utc(2026);
  return ValidatedRoad(id: id, driveSessionId: '$id-drive', sections: parsed,
    geometry: parsed.expand((s) => s.geometry).toList(), validDistanceMeters: parsed.fold<double>(0, (a,b) => a + b.distanceMeters),
    status: RoadValidationStatus.validated, validatedAt: now, providerId: 'synthetic',
    confidence: 1, processingVersion: 3, directionKey: id, averageHeadingDegrees: 90,
    createdAt: now, updatedAt: now);
}

Map<String, dynamic> serializeMatch(CommonRoadMatch m) => {
  'firstDriveId':m.firstDriveId,'secondDriveId':m.secondDriveId,
  'firstSectionId':m.firstSectionId,'secondSectionId':m.secondSectionId,
  'firstStartOffsetMeters':m.firstStartOffsetMeters,'firstEndOffsetMeters':m.firstEndOffsetMeters,
  'secondStartOffsetMeters':m.secondStartOffsetMeters,'secondEndOffsetMeters':m.secondEndOffsetMeters,
  'commonDistanceMeters':m.commonDistanceMeters,'directionCompatible':m.directionCompatible,
  'geometryConfidence':m.geometryConfidence,'comparisonEligible':m.comparisonEligible,
  'ownershipCovered':m.ownershipCovered,
  'commonStart':{'latitude':m.commonStart.latitude,'longitude':m.commonStart.longitude},
  'commonEnd':{'latitude':m.commonEnd.latitude,'longitude':m.commonEnd.longitude},
  'referenceGeometry': [for(final p in m.referenceGeometry) {'latitude':p.latitude,'longitude':p.longitude}],
};
