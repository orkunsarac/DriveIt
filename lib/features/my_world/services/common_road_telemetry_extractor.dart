import 'dart:math' as math;

import '../../../models/canonical_telemetry_point.dart';
import '../config/my_world_rules.dart';
import '../models/common_road_match.dart';
import '../models/common_road_telemetry.dart';
import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/validated_road.dart';
import 'geo_distance.dart';
import 'world_section_offset_mapper.dart';

/// Maps canonical GPS samples to the exact validated road section that forms a
/// [CommonRoadMatch]. It deliberately projects points to matched geometry
/// rather than treating validated-road offsets as raw GPS-distance offsets.
class CommonRoadTelemetryExtractor {
  const CommonRoadTelemetryExtractor();

  CommonRoadTelemetryPair extract({
    required CommonRoadMatch match,
    required ValidatedRoad firstRoad,
    required Iterable<CanonicalTelemetryPoint> firstTelemetry,
    required ValidatedRoad secondRoad,
    required Iterable<CanonicalTelemetryPoint> secondTelemetry,
  }) => extractRange(
    match: match,
    firstRoad: firstRoad,
    firstTelemetry: firstTelemetry,
    secondRoad: secondRoad,
    secondTelemetry: secondTelemetry,
  );

  /// Extracts two canonical subsets for explicit offsets on one already
  /// matched common road. The geometry projection remains identical to the
  /// full-match path; only the requested physical window changes.
  CommonRoadTelemetryPair extractRange({
    required CommonRoadMatch match,
    required ValidatedRoad firstRoad,
    required Iterable<CanonicalTelemetryPoint> firstTelemetry,
    required ValidatedRoad secondRoad,
    required Iterable<CanonicalTelemetryPoint> secondTelemetry,
    double? firstStartOffsetMeters,
    double? firstEndOffsetMeters,
    double? secondStartOffsetMeters,
    double? secondEndOffsetMeters,
    double offsetBoundaryToleranceMeters = 0,
  }) => CommonRoadTelemetryPair(
    first: _extractSubset(
      road: firstRoad,
      sectionId: match.firstSectionId,
      startOffsetMeters: firstStartOffsetMeters ?? match.firstStartOffsetMeters,
      endOffsetMeters: firstEndOffsetMeters ?? match.firstEndOffsetMeters,
      offsetBoundaryToleranceMeters: offsetBoundaryToleranceMeters,
      telemetry: firstTelemetry,
    ),
    second: _extractSubset(
      road: secondRoad,
      sectionId: match.secondSectionId,
      startOffsetMeters:
          secondStartOffsetMeters ?? match.secondStartOffsetMeters,
      endOffsetMeters: secondEndOffsetMeters ?? match.secondEndOffsetMeters,
      offsetBoundaryToleranceMeters: offsetBoundaryToleranceMeters,
      telemetry: secondTelemetry,
    ),
  );

  CommonRoadTelemetrySubset _extractSubset({
    required ValidatedRoad road,
    required String sectionId,
    required double startOffsetMeters,
    required double endOffsetMeters,
    required double offsetBoundaryToleranceMeters,
    required Iterable<CanonicalTelemetryPoint> telemetry,
  }) {
    final points = telemetry.toList(growable: false);
    if (points.isEmpty) {
      return _failure(
        CommonRoadTelemetryMappingStatus.insufficientTelemetry,
        'No canonical telemetry exists.',
      );
    }
    final section = _sectionFor(road, sectionId);
    if (section == null || section.geometry.length < 2) {
      return _failure(
        CommonRoadTelemetryMappingStatus.mappingFailed,
        'Matched road section is unavailable.',
      );
    }
    final sectionStart = _sectionStartOffset(road, sectionId);
    if (sectionStart == null) {
      return _failure(
        CommonRoadTelemetryMappingStatus.mappingFailed,
        'Matched road section offset is unavailable.',
      );
    }
    final geometryLength = WorldSectionOffsetMapper.geometryLength(
      section.geometry,
    );
    final canonicalLength = WorldSectionOffsetMapper.sectionLength(section);
    if (!geometryLength.isFinite ||
        geometryLength <= 0 ||
        !canonicalLength.isFinite ||
        canonicalLength <= 0) {
      return _failure(
        CommonRoadTelemetryMappingStatus.mappingFailed,
        'Matched section has no valid canonical offset axis.',
      );
    }

    // Request-local immutable segment metadata. Recomputing geodesic length
    // and bearing for every telemetry point/window dominates hosted CPU.
    // This does not spatially approximate or alter range/heading selection.
    final segments = <_ProjectionSegment>[];
    var segmentOffset = 0.0;
    for (var i = 0; i < section.geometry.length - 1; i++) {
      final start = section.geometry[i], end = section.geometry[i + 1];
      final length = GeoDistance.between(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
      if (length <= 0) continue;
      final canonicalStart =
          sectionStart +
          WorldSectionOffsetMapper.normalize(
            geometryOffsetMeters: segmentOffset,
            geometryLengthMeters: geometryLength,
            sectionLengthMeters: canonicalLength,
          );
      final canonicalEnd =
          sectionStart +
          WorldSectionOffsetMapper.normalize(
            geometryOffsetMeters: segmentOffset + length,
            geometryLengthMeters: geometryLength,
            sectionLengthMeters: canonicalLength,
          );
      // Exact monotone interval exclusion, not a spatial approximation. A
      // projection on this segment cannot be accepted outside this range.
      // Boundary-equal segments remain; self-intersections within the requested
      // offset range still undergo the unchanged distance/heading selection.
      if (canonicalEnd >= startOffsetMeters - offsetBoundaryToleranceMeters &&
          canonicalStart <= endOffsetMeters + offsetBoundaryToleranceMeters) {
        segments.add(_ProjectionSegment(start, end, length, segmentOffset));
      }
      segmentOffset += length;
    }
    final selected = <_ProjectedTelemetry>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      if (!point.hasValidCoordinate) {
        continue;
      }
      final projection = _project(
        point,
        segments,
        sectionStart,
        geometryLength,
        canonicalLength,
        startOffsetMeters,
        endOffsetMeters,
        offsetBoundaryToleranceMeters,
      );
      if (projection == null ||
          projection.distanceMeters >
              MyWorldRules.commonRoadTelemetryProjectionToleranceMeters ||
          (projection.headingDifferenceDegrees != null &&
              projection.headingDifferenceDegrees! >
                  MyWorldRules.commonRoadTelemetryHeadingToleranceDegrees) ||
          projection.roadOffsetMeters <
              startOffsetMeters - offsetBoundaryToleranceMeters ||
          projection.roadOffsetMeters >
              endOffsetMeters + offsetBoundaryToleranceMeters) {
        continue;
      }
      selected.add(_ProjectedTelemetry(index, point, projection));
    }
    if (selected.length < 2) {
      return _failure(
        CommonRoadTelemetryMappingStatus.insufficientTelemetry,
        'Fewer than two canonical samples map to the common road.',
      );
    }
    final ordered = selected.map((item) => item.point).toList(growable: false);
    for (var index = 1; index < ordered.length; index++) {
      if (!ordered[index].timestamp.isAfter(ordered[index - 1].timestamp)) {
        return _failure(
          CommonRoadTelemetryMappingStatus.mappingFailed,
          'Mapped telemetry does not preserve strict time order.',
        );
      }
    }
    final averageDistance =
        selected.fold<double>(
          0,
          (sum, item) => sum + item.projection.distanceMeters,
        ) /
        selected.length;
    final confidence =
        (1 -
                averageDistance /
                    MyWorldRules.commonRoadTelemetryProjectionToleranceMeters)
            .clamp(0.0, 1.0)
            .toDouble();
    return CommonRoadTelemetrySubset(
      status: CommonRoadTelemetryMappingStatus.success,
      telemetry: List.unmodifiable(ordered),
      startIndex: selected.first.index,
      endIndex: selected.last.index,
      mappingConfidence: confidence,
      reason: null,
    );
  }

  CommonRoadTelemetrySubset _failure(
    CommonRoadTelemetryMappingStatus status,
    String reason,
  ) => CommonRoadTelemetrySubset(
    status: status,
    telemetry: const [],
    startIndex: null,
    endIndex: null,
    mappingConfidence: 0,
    reason: reason,
  );

  MatchedRoadSection? _sectionFor(ValidatedRoad road, String sectionId) {
    if (road.sections.isNotEmpty) {
      for (final section in road.sections) {
        if (section.id == sectionId) {
          return section;
        }
      }
      return null;
    }
    return sectionId == '${road.id}:geometry'
        ? MatchedRoadSection(
            id: sectionId,
            geometry: road.geometry,
            distanceMeters: road.validDistanceMeters,
            confidence: road.confidence,
            sourceTraceIndex: 0,
            sourceChunkIndex: 0,
          )
        : null;
  }

  double? _sectionStartOffset(ValidatedRoad road, String sectionId) {
    if (road.sections.isEmpty) {
      return sectionId == '${road.id}:geometry' ? 0 : null;
    }
    var offset = 0.0;
    for (final section in road.sections) {
      if (section.id == sectionId) {
        return offset;
      }
      offset += WorldSectionOffsetMapper.sectionLength(section);
    }
    return null;
  }

  _GeometryProjection? _project(
    CanonicalTelemetryPoint telemetry,
    List<_ProjectionSegment> segments,
    double sectionStartOffsetMeters,
    double geometryLengthMeters,
    double canonicalLengthMeters,
    double requiredStartOffsetMeters,
    double requiredEndOffsetMeters,
    double offsetBoundaryToleranceMeters,
  ) {
    _GeometryProjection? best;
    var bestIsInsideRequiredRange = false;
    for (final segment in segments) {
      final projected = _projectToSegment(telemetry, segment);
      final candidate = _GeometryProjection(
        distanceMeters: projected.distanceMeters,
        roadOffsetMeters:
            sectionStartOffsetMeters +
            WorldSectionOffsetMapper.normalize(
              geometryOffsetMeters:
                  segment.offset + segment.length * projected.ratio,
              geometryLengthMeters: geometryLengthMeters,
              sectionLengthMeters: canonicalLengthMeters,
            ),
        headingDifferenceDegrees: _headingDifference(
          telemetry.headingDegrees,
          segment.bearing,
        ),
      );
      final isInsideRequiredRange =
          candidate.roadOffsetMeters >=
              requiredStartOffsetMeters - offsetBoundaryToleranceMeters &&
          candidate.roadOffsetMeters <=
              requiredEndOffsetMeters + offsetBoundaryToleranceMeters;
      if (best == null ||
          (isInsideRequiredRange && !bestIsInsideRequiredRange) ||
          (isInsideRequiredRange == bestIsInsideRequiredRange &&
              (candidate.distanceMeters < best.distanceMeters ||
                  (_nearlyEqual(
                        candidate.distanceMeters,
                        best.distanceMeters,
                      ) &&
                      _headingIsCloser(candidate, best))))) {
        best = candidate;
        bestIsInsideRequiredRange = isInsideRequiredRange;
      }
    }
    return best;
  }

  _ProjectionOnSegment _projectToSegment(
    CanonicalTelemetryPoint point,
    _ProjectionSegment segment,
  ) {
    final latitudeScale = 111320.0;
    final x =
        (point.longitude - segment.start.longitude) * segment.longitudeScale;
    final y = (point.latitude - segment.start.latitude) * latitudeScale;
    final endX = segment.endX;
    final endY = segment.endY;
    final squaredLength = endX * endX + endY * endY;
    final ratio = squaredLength <= 0
        ? 0.0
        : ((x * endX + y * endY) / squaredLength).clamp(0.0, 1.0).toDouble();
    final projectedX = endX * ratio;
    final projectedY = endY * ratio;
    return _ProjectionOnSegment(
      ratio: ratio,
      distanceMeters: math.sqrt(
        (x - projectedX) * (x - projectedX) +
            (y - projectedY) * (y - projectedY),
      ),
    );
  }
}

class _ProjectionSegment {
  _ProjectionSegment(this.start, MatchedRoadPoint end, this.length, this.offset)
    : longitudeScale = 111320 * math.cos(_radians(start.latitude)),
      bearing = _bearingDegrees(start, end) {
    endX = (end.longitude - start.longitude) * longitudeScale;
    endY = (end.latitude - start.latitude) * 111320;
  }
  final MatchedRoadPoint start;
  final double length, offset, longitudeScale, bearing;
  late final double endX, endY;
}

class _ProjectedTelemetry {
  const _ProjectedTelemetry(this.index, this.point, this.projection);

  final int index;
  final CanonicalTelemetryPoint point;
  final _GeometryProjection projection;
}

class _GeometryProjection {
  const _GeometryProjection({
    required this.distanceMeters,
    required this.roadOffsetMeters,
    required this.headingDifferenceDegrees,
  });

  final double distanceMeters;
  final double roadOffsetMeters;
  final double? headingDifferenceDegrees;
}

class _ProjectionOnSegment {
  const _ProjectionOnSegment({
    required this.ratio,
    required this.distanceMeters,
  });

  final double ratio;
  final double distanceMeters;
}

double _radians(double degrees) => degrees * math.pi / 180;

double _bearingDegrees(MatchedRoadPoint start, MatchedRoadPoint end) {
  final longitudeDelta = _radians(end.longitude - start.longitude);
  final startLatitude = _radians(start.latitude);
  final endLatitude = _radians(end.latitude);
  final y = math.sin(longitudeDelta) * math.cos(endLatitude);
  final x =
      math.cos(startLatitude) * math.sin(endLatitude) -
      math.sin(startLatitude) *
          math.cos(endLatitude) *
          math.cos(longitudeDelta);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double? _headingDifference(double telemetryHeading, double geometryHeading) {
  if (!telemetryHeading.isFinite ||
      telemetryHeading < 0 ||
      telemetryHeading >= 360) {
    return null;
  }
  final difference = (telemetryHeading - geometryHeading).abs() % 360;
  return difference > 180 ? 360 - difference : difference;
}

bool _nearlyEqual(double first, double second, [double tolerance = 1e-6]) =>
    (first - second).abs() <= tolerance;

bool _headingIsCloser(
  _GeometryProjection candidate,
  _GeometryProjection current,
) =>
    (candidate.headingDifferenceDegrees ?? double.infinity) <
    (current.headingDifferenceDegrees ?? double.infinity);
