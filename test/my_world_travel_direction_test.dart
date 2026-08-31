import 'package:flutter_test/flutter_test.dart';

import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_trace_travel_direction.dart';
import 'package:driveit_project/features/my_world/services/world_trace_travel_direction_resolver.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';

void main() {
  const resolver = WorldTraceTravelDirectionResolver();
  final geometry = <MatchedRoadPoint>[
    const MatchedRoadPoint(latitude: 40, longitude: 29),
    const MatchedRoadPoint(latitude: 40, longitude: 29.01),
  ];
  final road = ValidatedRoad(
    id: 'road',
    driveSessionId: 'drive',
    geometry: geometry,
    sections: [
      MatchedRoadSection(
        id: 'section',
        geometry: geometry,
        distanceMeters: 850,
        confidence: 1,
        sourceTraceIndex: 0,
        sourceChunkIndex: 0,
      ),
    ],
    validDistanceMeters: 850,
    status: RoadValidationStatus.validated,
    validatedAt: DateTime(2026),
    providerId: 'test',
    confidence: 1,
    processingVersion: 1,
    directionKey: 'east',
    averageHeadingDegrees: 90,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final trace = ActiveWorldTrace(
    id: 'trace',
    sourceDriveSessionId: 'drive',
    validatedRoadId: 'road',
    matchedSectionId: 'section',
    startOffsetMeters: 0,
    endOffsetMeters: 850,
    directionKey: 'east',
    minLatitude: 40,
    maxLatitude: 40,
    minLongitude: 29,
    maxLongitude: 29.01,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    processingVersion: 1,
  );

  List<CanonicalTelemetryPoint> samples({required bool reverse}) {
    final values = reverse
        ? <double>[29.009, 29.006, 29.003, 29.001]
        : <double>[29.001, 29.003, 29.006, 29.009];
    return [
      for (var i = 0; i < values.length; i++)
        CanonicalTelemetryPoint(
          latitude: 40,
          longitude: values[i],
          timestamp: DateTime(2026).add(Duration(seconds: i + 1)),
          speedMps: 12,
          headingDegrees: reverse ? 270 : 90,
          altitudeMeters: 0,
          accuracyMeters: 3,
          distanceFromPreviousMeters: 100,
          accelerationMps2: 0,
        ),
    ];
  }

  test('forward traversal resolves from timestamped telemetry', () {
    final result = resolver.resolve(
      trace: trace,
      road: road,
      telemetry: samples(reverse: false),
    );
    expect(result.direction, WorldTraceTravelDirection.forward);
    expect(result.confidence, greaterThanOrEqualTo(.65));
  });

  test('reverse traversal resolves without mutating road geometry', () {
    final result = resolver.resolve(
      trace: trace,
      road: road,
      telemetry: samples(reverse: true),
    );
    expect(result.direction, WorldTraceTravelDirection.reverse);
    expect(road.geometry.first.longitude, 29);
  });

  test('insufficient telemetry returns unknown instead of guessing', () {
    final result = resolver.resolve(
      trace: trace,
      road: road,
      telemetry: samples(reverse: false).take(2),
    );
    expect(result.direction, WorldTraceTravelDirection.unknown);
  });
}
