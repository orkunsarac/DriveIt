import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/services/world_index_mutation_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/active_world_empty_parity.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final raw in fixture['cases'] as List) {
    final data = raw as Map<String, dynamic>;
    test('Dart empty-world parity: ${data['name']}', () {
      final sections = [
        for (final sectionRaw in data['sections'] as List)
          _section(sectionRaw as Map<String, dynamic>),
      ];
      final road = ValidatedRoad(
        id: data['road_id'] as String,
        driveSessionId: data['drive_id'] as String,
        geometry: sections.expand((section) => section.geometry).toList(),
        sections: sections,
        validDistanceMeters: sections.fold<double>(
          0,
          (sum, section) => sum + section.distanceMeters,
        ),
        status: RoadValidationStatus.validated,
        validatedAt: DateTime.utc(2026),
        providerId: 'synthetic-fixture',
        confidence: 1,
        processingVersion: data['processing_version'] as int,
        directionKey: data['direction_key'] as String,
        averageHeadingDegrees: 90,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final plan = const WorldIndexMutationPlanner().plan(
        current: WorldIndexSnapshot.empty(
          driveScoreAlgorithmVersion: 1,
          validatedRoadProcessingVersion: 2,
        ),
        challengerRoad: road,
        overlaps: const [],
        now: DateTime.utc(2026),
        algorithmVersion: DriveScoreAlgorithmVersion.v1,
      );
      final expected = data['expected'] as Map<String, dynamic>;
      expect(plan.baseGeneration, 0);
      expect(plan.resultingSnapshot.generation, expected['generation']);
      expect(plan.operationId, expected['operation_id']);
      expect(plan.resultingSnapshot.operationId, expected['operation_id']);
      expect(plan.resultingSnapshot.operationReason, 'recordProcessing');
      expect(plan.resultingSnapshot.processedDriveSessionIds, [
        data['drive_id'],
      ]);
      expect(plan.resultingSnapshot.driveScoreAlgorithmVersion, 1);
      expect(plan.resultingSnapshot.validatedRoadProcessingVersion, 6);
      final traces = plan.resultingSnapshot.traces;
      final expectedTraces = expected['traces'] as List;
      expect(traces, hasLength(expected['trace_count'] as int));
      for (var index = 0; index < traces.length; index++) {
        final trace = traces[index];
        final expectedTrace = expectedTraces[index] as Map<String, dynamic>;
        expect(trace.id, expectedTrace['id']);
        expect(trace.sourceDriveSessionId, expectedTrace['source_drive_id']);
        expect(trace.validatedRoadId, expectedTrace['validated_road_id']);
        expect(trace.matchedSectionId, expectedTrace['section_id']);
        expect(trace.startOffsetMeters, expectedTrace['start_offset_meters']);
        expect(trace.endOffsetMeters, expectedTrace['end_offset_meters']);
        expect(trace.directionKey, expectedTrace['direction_key']);
        expect(trace.processingVersion, expectedTrace['processing_version']);
        final bounds = expectedTrace['bounds'] as List;
        expect(trace.minLatitude, bounds[0]);
        expect(trace.maxLatitude, bounds[1]);
        expect(trace.minLongitude, bounds[2]);
        expect(trace.maxLongitude, bounds[3]);
      }
    });
  }
}

MatchedRoadSection _section(Map<String, dynamic> data) => MatchedRoadSection(
  id: data['id'] as String,
  distanceMeters: data['distance_meters_exact'] is String
      ? double.parse(data['distance_meters_exact'] as String)
      : (data['distance_meters'] as num).toDouble(),
  geometry: [
    for (final pair in data['geometry'] as List)
      MatchedRoadPoint(
        latitude: (pair[0] as num).toDouble(),
        longitude: (pair[1] as num).toDouble(),
      ),
  ],
  confidence: 1,
  sourceTraceIndex: 0,
  sourceChunkIndex: 0,
);
