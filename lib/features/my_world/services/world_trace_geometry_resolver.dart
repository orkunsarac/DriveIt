import '../models/active_world_trace.dart';
import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/validated_road.dart';
import 'geo_distance.dart';

/// Resolves an active index reference without mutating World persistence.
class WorldTraceGeometryResolver {
  const WorldTraceGeometryResolver();

  List<MatchedRoadPoint> resolve({
    required ActiveWorldTrace trace,
    required ValidatedRoad road,
  }) {
    if (trace.validatedRoadId != road.id ||
        trace.sourceDriveSessionId != road.driveSessionId ||
        trace.endOffsetMeters <= trace.startOffsetMeters) {
      return const [];
    }

    final sections = road.sections.isNotEmpty
        ? road.sections
        : <MatchedRoadSection>[
            MatchedRoadSection(
              id: '${road.id}:geometry',
              geometry: road.geometry,
              distanceMeters: road.validDistanceMeters,
              confidence: road.confidence,
              sourceTraceIndex: 0,
              sourceChunkIndex: 0,
            ),
          ];

    var sectionStart = 0.0;
    MatchedRoadSection? target;
    for (final section in sections) {
      if (section.id == trace.matchedSectionId) {
        target = section;
        break;
      }
      sectionStart += section.distanceMeters;
    }
    if (target == null || target.geometry.length < 2) return const [];

    final sectionDistance = target.distanceMeters;
    if (!sectionDistance.isFinite || sectionDistance <= 0) return const [];
    final localStart = trace.startOffsetMeters - sectionStart;
    final localEnd = trace.endOffsetMeters - sectionStart;
    const epsilon = .5;
    if (localStart < -epsilon || localEnd > sectionDistance + epsilon) {
      return const [];
    }

    final cumulative = <double>[0];
    for (var i = 1; i < target.geometry.length; i++) {
      final previous = target.geometry[i - 1];
      final current = target.geometry[i];
      final distance = GeoDistance.between(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      if (!distance.isFinite) return const [];
      cumulative.add(cumulative.last + distance);
    }
    final geometryDistance = cumulative.last;
    if (geometryDistance <= epsilon) return const [];

    final clippedStart = localStart.clamp(0.0, sectionDistance);
    final clippedEnd = localEnd.clamp(0.0, sectionDistance);
    if (clippedEnd - clippedStart <= epsilon) return const [];
    final geometryStart = clippedStart / sectionDistance * geometryDistance;
    final geometryEnd = clippedEnd / sectionDistance * geometryDistance;
    final output = <MatchedRoadPoint>[
      _pointAt(target.geometry, cumulative, geometryStart),
    ];
    for (var i = 1; i < target.geometry.length - 1; i++) {
      if (cumulative[i] > geometryStart && cumulative[i] < geometryEnd) {
        output.add(target.geometry[i]);
      }
    }
    output.add(_pointAt(target.geometry, cumulative, geometryEnd));
    return List.unmodifiable(output);
  }

  MatchedRoadPoint _pointAt(
    List<MatchedRoadPoint> points,
    List<double> cumulative,
    double targetDistance,
  ) {
    if (targetDistance <= 0) return points.first;
    if (targetDistance >= cumulative.last) return points.last;
    var upper = 1;
    while (upper < cumulative.length && cumulative[upper] < targetDistance) {
      upper++;
    }
    final lower = upper - 1;
    final span = cumulative[upper] - cumulative[lower];
    final ratio = span <= 0 ? 0.0 : (targetDistance - cumulative[lower]) / span;
    final a = points[lower];
    final b = points[upper];
    return MatchedRoadPoint(
      latitude: a.latitude + (b.latitude - a.latitude) * ratio,
      longitude: a.longitude + (b.longitude - a.longitude) * ratio,
      headingDegrees: _nullableInterpolate(
        a.headingDegrees,
        b.headingDegrees,
        ratio,
      ),
      providerRoadReference:
          a.providerRoadReference ?? b.providerRoadReference,
      confidence: _nullableInterpolate(a.confidence, b.confidence, ratio),
    );
  }

  double? _nullableInterpolate(double? a, double? b, double ratio) {
    if (a == null) return b;
    if (b == null) return a;
    return a + (b - a) * ratio;
  }
}
