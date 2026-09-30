import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/services/gps_route_preprocessor.dart';
import 'package:driveit_project/features/my_world/services/map_matching_chunker.dart';
import 'package:driveit_project/features/world_publish/models/published_drive_source.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';

List<RoutePoint> _route(dynamic encoded) {
  if (encoded is List) {
    return [
      for (final pair in encoded)
        RoutePoint(
          latitude: (pair[0] as num).toDouble(),
          longitude: (pair[1] as num).toDouble(),
        ),
    ];
  }
  final linear = (encoded as Map)['linear'] as Map;
  return [
    for (var i = 0; i < (linear['count'] as int); i++)
      RoutePoint(
        latitude:
            (linear['latitude'] as num).toDouble() +
            i * (linear['latitude_step'] as num).toDouble(),
        longitude: (linear['longitude'] as num).toDouble(),
      ),
  ];
}

List<int> _indices(dynamic encoded) {
  if (encoded is Map) return (encoded['indices'] as List).cast<int>();
  final range = (encoded as List).cast<int>();
  return [for (var i = range[0]; i <= range[1]; i++) i];
}

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/world_server_parity.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  test('shared fixture pins current Dart source/version constants', () {
    final rules = fixture['rules'] as Map<String, dynamic>;
    expect(
      rules['source_schema_version'],
      PublishedDriveSourceSchema.currentVersion,
    );
    expect(rules['telemetry_version'], DriveTelemetryRecord.currentDataVersion);
    expect(
      rules['drive_score_algorithm_version'],
      DriveScoreAlgorithmVersion.v1.value,
    );
    expect(rules['world_rules_version'], MyWorldRules.worldRulesVersion);
    expect(
      rules['validated_road_processing_version'],
      MyWorldRules.validatedRoadProcessingVersion,
    );
    expect(
      rules['minimum_valid_distance_meters'],
      MyWorldRules.minimumValidDistanceMeters,
    );
    expect(
      rules['minimum_useful_point_distance_meters'],
      MyWorldRules.minimumUsefulPointDistanceMeters,
    );
    expect(
      rules['maximum_plausible_point_jump_meters'],
      MyWorldRules.maximumPlausiblePointJumpMeters,
    );
    expect(
      rules['maximum_plausible_gap_average_speed_mps'],
      MyWorldRules.maximumPlausibleGapAverageSpeedMps,
    );
    expect(
      rules['canonical_route_alignment_tolerance_meters'],
      MyWorldRules.canonicalRouteAlignmentToleranceMeters,
    );
    expect(
      rules['map_matching_maximum_coordinates'],
      MyWorldRules.mapMatchingMaximumCoordinates,
    );
    expect(
      rules['map_matching_chunk_overlap'],
      MyWorldRules.mapMatchingChunkOverlap,
    );
    expect(
      rules['map_matching_radius_meters'],
      MyWorldRules.mapMatchingRadiusMeters,
    );
    expect(
      rules['chunk_geometry_merge_tolerance_meters'],
      MyWorldRules.chunkGeometryMergeToleranceMeters,
    );
    expect(
      rules['map_matching_timeout_ms'],
      MyWorldRules.mapMatchingTimeout.inMilliseconds,
    );
  });

  for (final scenario in fixture['cases'] as List) {
    final data = scenario as Map<String, dynamic>;
    test('Dart preprocessing/chunk parity: ${data['name']}', () {
      final route = _route(data['route']);
      final telemetry = [
        for (final item in data['telemetry'] as List)
          CanonicalTelemetryPoint(
            latitude: (item[0] as num).toDouble(),
            longitude: (item[1] as num).toDouble(),
            timestamp: DateTime.parse(item[2] as String),
            speedMps: 0,
            headingDegrees: 0,
            altitudeMeters: 0,
            accuracyMeters: 0,
            distanceFromPreviousMeters: 0,
            accelerationMps2: 0,
          ),
      ];
      final result = const GpsRoutePreprocessor().clean(
        route,
        canonicalTelemetry: telemetry,
      );
      final expected = data['expected'] as Map;
      expect(result.inputPointCount, expected['input']);
      expect(result.acceptedPointCount, expected['accepted']);
      expect(result.invalidPointCount, expected['invalid']);
      expect(result.tooClosePointCount, expected['too_close']);
      expect(result.jumpSplitCount, expected['jump_splits']);
      expect(result.plausibleGapContinuationCount, expected['plausible_gaps']);
      final expectedTraces = expected['traces'] as List;
      expect(result.traces.length, expectedTraces.length);
      for (var t = 0; t < result.traces.length; t++) {
        final expectedPoints = _indices(expectedTraces[t]);
        expect(result.traces[t].index, t);
        expect(result.traces[t].points.length, expectedPoints.length);
        for (var p = 0; p < expectedPoints.length; p++) {
          final actual = result.traces[t].points[p];
          final source = route[expectedPoints[p]];
          expect(actual.latitude, source.latitude);
          expect(actual.longitude, source.longitude);
        }
      }
      final chunks = const MapMatchingChunker().build(result.traces);
      final expectedChunks = expected['chunks'] as List;
      expect(chunks.length, expectedChunks.length);
      for (var c = 0; c < chunks.length; c++) {
        final expectedPoints = _indices(expectedChunks[c]);
        expect(chunks[c].points.length, expectedPoints.length);
        for (var p = 0; p < expectedPoints.length; p++) {
          final actual = chunks[c].points[p];
          final source = route[expectedPoints[p]];
          expect(actual.latitude, source.latitude);
          expect(actual.longitude, source.longitude);
        }
      }
    });
  }
}
