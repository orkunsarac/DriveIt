import 'dart:math' as math;

import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/world_map_read_model.dart';
import 'package:driveit_project/features/my_world/models/world_trace_travel_direction.dart';
import 'package:driveit_project/features/my_world/services/geo_distance.dart';
import 'package:driveit_project/features/my_world/services/world_trace_presentation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = WorldTracePresentationService();

  ActiveWorldTrace trace(String id) => ActiveWorldTrace(
    id: id,
    sourceDriveSessionId: id,
    validatedRoadId: 'road-$id',
    matchedSectionId: 'section-$id',
    startOffsetMeters: 0,
    endOffsetMeters: 1000,
    directionKey: 'direction-$id',
    minLatitude: 40,
    maxLatitude: 40.01,
    minLongitude: 29,
    maxLongitude: 29.01,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    processingVersion: 1,
  );

  ResolvedWorldTrace resolved(
    String id,
    List<MatchedRoadPoint> geometry,
    WorldTraceTravelDirection direction,
  ) => ResolvedWorldTrace(
    trace: trace(id),
    geometry: geometry,
    visualVariant: 0,
    travelDirection: direction,
  );

  List<LatLngLike> offsets(
    List<MatchedRoadPoint> source,
    List<dynamic> rendered,
  ) => List.generate(
    source.length,
    (i) => LatLngLike(
      GeoDistance.between(
        source[i].latitude,
        source[i].longitude,
        rendered[i].latitude,
        rendered[i].longitude,
      ),
    ),
  );

  test('opposite traces receive a fixed render-time lateral separation', () {
    const source = [
      MatchedRoadPoint(latitude: 40, longitude: 29),
      MatchedRoadPoint(latitude: 40, longitude: 29.001),
      MatchedRoadPoint(latitude: 40, longitude: 29.002),
    ];
    final forward = resolved(
      'forward',
      source,
      WorldTraceTravelDirection.forward,
    );
    final reverse = resolved(
      'reverse',
      source,
      WorldTraceTravelDirection.reverse,
    );
    final a = service.renderGeometry(
      trace: forward,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: reverse,
    );
    final b = service.renderGeometry(
      trace: reverse,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: forward,
    );
    for (var i = 0; i < source.length; i++) {
      expect(
        GeoDistance.between(
          a[i].latitude,
          a[i].longitude,
          b[i].latitude,
          b[i].longitude,
        ),
        closeTo(MyWorldRules.oppositeTraceVisualOffsetMeters * 2, .1),
      );
    }
    expect(offsets(source, a).first.meters, closeTo(3, .1));
    expect(forward.geometry, orderedEquals(source));
    expect(reverse.geometry, orderedEquals(source));
  });

  test('same direction remains on source geometry', () {
    const source = [
      MatchedRoadPoint(latitude: 40, longitude: 29),
      MatchedRoadPoint(latitude: 40.0002, longitude: 29.001),
      MatchedRoadPoint(latitude: 40.0006, longitude: 29.002),
    ];
    final a = resolved('a', source, WorldTraceTravelDirection.forward);
    final b = resolved('b', source, WorldTraceTravelDirection.forward);
    expect(service.oppositeTraceIds([a, b]), isEmpty);
    final rendered = service.renderGeometry(
      trace: a,
      separateOpposite: false,
      zoom: 13,
    );
    for (var i = 0; i < source.length; i++) {
      expect(rendered[i].latitude, source[i].latitude);
      expect(rendered[i].longitude, source[i].longitude);
    }
  });

  test('opposite local tangent detects traces even when direction metadata is unknown', () {
    const source = [
      MatchedRoadPoint(latitude: 40, longitude: 29),
      MatchedRoadPoint(latitude: 40, longitude: 29.001),
      MatchedRoadPoint(latitude: 40, longitude: 29.002),
    ];
    final a = resolved('unknown-a', source, WorldTraceTravelDirection.unknown);
    final b = resolved(
      'unknown-b',
      source.reversed.toList(),
      WorldTraceTravelDirection.unknown,
    );
    final ids = service.oppositeTraceIds([a, b]);
    expect(ids, containsAll(<String>['unknown-a', 'unknown-b']));

    final renderedA = service.renderGeometry(
      trace: a,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: b,
    );
    final renderedB = service.renderGeometry(
      trace: b,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: a,
    );
    expect(
      GeoDistance.between(
        renderedA[1].latitude,
        renderedA[1].longitude,
        renderedB[1].latitude,
        renderedB[1].longitude,
      ),
      closeTo(MyWorldRules.oppositeTraceVisualOffsetMeters * 2, .1),
    );
  });

  test('stable tangent handles short segments and sharp turns', () {
    const source = [
      MatchedRoadPoint(latitude: 40, longitude: 29),
      MatchedRoadPoint(latitude: 40, longitude: 29.00001),
      MatchedRoadPoint(latitude: 40.00001, longitude: 29.00001),
      MatchedRoadPoint(latitude: 40.0001, longitude: 29.00001),
    ];
    final a = resolved('a', source, WorldTraceTravelDirection.forward);
    final b = resolved(
      'b',
      source.reversed.toList(),
      WorldTraceTravelDirection.reverse,
    );
    final rendered = service.renderGeometry(
      trace: a,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: b,
    );
    expect(rendered, hasLength(source.length));
    expect(
      offsets(source, rendered)
          .map((value) => value.meters)
          .every(
            (value) => value <= MyWorldRules.oppositeTraceVisualOffsetMeters,
          ),
      isTrue,
    );
    expect(a.geometry, orderedEquals(source));
  });

  test('45, 90 and 120 degree turns stay bounded and preserve topology', () {
    for (final degrees in [45, 90, 120]) {
      final radians = degrees * 3.141592653589793 / 180;
      final source = [
        const MatchedRoadPoint(latitude: 40, longitude: 29),
        const MatchedRoadPoint(latitude: 40.0005, longitude: 29),
        MatchedRoadPoint(
          latitude: 40.0005 + 0.0005 * math.cos(radians),
          longitude: 29 + 0.0005 * math.sin(radians),
        ),
        MatchedRoadPoint(
          latitude: 40.0005 + 0.001 * math.cos(radians),
          longitude: 29 + 0.001 * math.sin(radians),
        ),
      ];
      final forward = resolved(
        'f-$degrees',
        source,
        WorldTraceTravelDirection.forward,
      );
      final reverse = resolved(
        'r-$degrees',
        source,
        WorldTraceTravelDirection.reverse,
      );
      final rendered = service.renderGeometry(
        trace: forward,
        separateOpposite: true,
        zoom: 13,
        oppositePartner: reverse,
      );
      expect(rendered, hasLength(source.length));
      for (var i = 0; i < source.length; i++) {
        expect(
          GeoDistance.between(
            source[i].latitude,
            source[i].longitude,
            rendered[i].latitude,
            rendered[i].longitude,
          ),
          lessThanOrEqualTo(MyWorldRules.oppositeTraceVisualOffsetMeters),
        );
      }
      expect(forward.geometry, orderedEquals(source));
    }
  });

  test('long straight road uses a stable parallel offset', () {
    final source = List.generate(
      12,
      (index) => MatchedRoadPoint(latitude: 40, longitude: 29 + index * .001),
    );
    final forward = resolved(
      'straight-f',
      source,
      WorldTraceTravelDirection.forward,
    );
    final reverse = resolved(
      'straight-r',
      source,
      WorldTraceTravelDirection.reverse,
    );
    final rendered = service.renderGeometry(
      trace: forward,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: reverse,
    );
    final distances = offsets(
      source,
      rendered,
    ).map((value) => value.meters).toList();
    expect(
      distances.skip(1).every((value) => (value - distances[1]).abs() < .1),
      isTrue,
    );
    expect(
      distances[1],
      closeTo(MyWorldRules.oppositeTraceVisualOffsetMeters, .1),
    );
  });

  test('long opposite overlap keeps a stable six metre lane gap', () {
    final source = List.generate(
      20,
      (index) => MatchedRoadPoint(latitude: 40, longitude: 29 + index * .001),
    );
    final a = resolved('gazanfer-a', source, WorldTraceTravelDirection.forward);
    final b = resolved(
      'gazanfer-b',
      source.reversed.toList(),
      WorldTraceTravelDirection.reverse,
    );
    final renderedA = service.renderGeometry(
      trace: a,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: b,
    );
    final renderedB = service.renderGeometry(
      trace: b,
      separateOpposite: true,
      zoom: 13,
      oppositePartner: a,
    );
    for (var i = 0; i < source.length; i++) {
      final reverseIndex = source.length - 1 - i;
      final gap = GeoDistance.between(
        renderedA[i].latitude,
        renderedA[i].longitude,
        renderedB[reverseIndex].latitude,
        renderedB[reverseIndex].longitude,
      );
      expect(gap, closeTo(6, .12));
    }
    expect(a.geometry, orderedEquals(source));
    expect(b.geometry, orderedEquals(source.reversed));
  });
}

class LatLngLike {
  const LatLngLike(this.meters);
  final double meters;
}
