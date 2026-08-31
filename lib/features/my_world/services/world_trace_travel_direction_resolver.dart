import 'dart:math' as math;

import '../../../models/canonical_telemetry_point.dart';
import '../config/my_world_rules.dart';
import '../models/active_world_trace.dart';
import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/validated_road.dart';
import '../models/world_trace_travel_direction.dart';
import 'geo_distance.dart';

/// Resolves the direction in which the source drive traversed an active World
/// span. This is intentionally read-only and presentation-only.
class WorldTraceTravelDirectionResolver {
  const WorldTraceTravelDirectionResolver();

  // Direction is presentation metadata, not a full map-match operation. A
  // bounded, evenly spaced sample is sufficient to determine signed travel
  // progression while avoiding an O(telemetry x road-geometry) scan for long
  // drives (which can contain thousands of points in each list).
  static const int _maxProjectionSamples = 96;

  WorldTraceTravelDirectionResult resolve({
    required ActiveWorldTrace trace,
    required ValidatedRoad road,
    required Iterable<CanonicalTelemetryPoint> telemetry,
  }) {
    final sectionInfo = _sectionInfo(trace, road);
    if (sectionInfo == null) {
      return const WorldTraceTravelDirectionResult.unknown();
    }
    final points = _samplePoints(telemetry);
    if (points.length < 3) {
      return const WorldTraceTravelDirectionResult.unknown();
    }
    final offsets = <double>[];
    for (final point in points) {
      final projection = _project(point, sectionInfo.geometry);
      if (projection == null ||
          projection.distanceMeters >
              MyWorldRules.commonRoadTelemetryProjectionToleranceMeters) {
        continue;
      }
      final globalOffset = sectionInfo.startOffsetMeters + projection.offset;
      if (globalOffset >= trace.startOffsetMeters - 5 &&
          globalOffset <= trace.endOffsetMeters + 5) {
        offsets.add(globalOffset);
      }
    }
    if (offsets.length < 3) {
      return const WorldTraceTravelDirectionResult.unknown();
    }

    var positive = 0;
    var negative = 0;
    var signedProgression = 0.0;
    for (var i = 1; i < offsets.length; i++) {
      final delta = offsets[i] - offsets[i - 1];
      if (delta.abs() < 8) continue;
      signedProgression += delta;
      if (delta > 0) {
        positive++;
      } else {
        negative++;
      }
    }
    final totalVotes = positive + negative;
    if (totalVotes < 2 || signedProgression.abs() < 20) {
      return WorldTraceTravelDirectionResult(
        direction: WorldTraceTravelDirection.unknown,
        confidence: 0,
        projectedSampleCount: offsets.length,
        signedProgressionMeters: signedProgression,
        firstProjectedOffset: offsets.first,
        lastProjectedOffset: offsets.last,
      );
    }
    final dominant = math.max(positive, negative);
    final confidence = (dominant / totalVotes).clamp(0.0, 1.0).toDouble();
    if (confidence < .65) {
      return WorldTraceTravelDirectionResult(
        direction: WorldTraceTravelDirection.unknown,
        confidence: confidence,
        projectedSampleCount: offsets.length,
        signedProgressionMeters: signedProgression,
        firstProjectedOffset: offsets.first,
        lastProjectedOffset: offsets.last,
      );
    }
    return WorldTraceTravelDirectionResult(
      direction: signedProgression > 0
          ? WorldTraceTravelDirection.forward
          : WorldTraceTravelDirection.reverse,
      confidence: confidence,
      projectedSampleCount: offsets.length,
      signedProgressionMeters: signedProgression,
      firstProjectedOffset: offsets.first,
      lastProjectedOffset: offsets.last,
    );
  }

  List<CanonicalTelemetryPoint> _samplePoints(
    Iterable<CanonicalTelemetryPoint> source,
  ) {
    final points = source.toList(growable: false);
    if (points.length <= _maxProjectionSamples) return points;
    final result = <CanonicalTelemetryPoint>[points.first];
    final interior = _maxProjectionSamples - 2;
    for (var i = 1; i <= interior; i++) {
      final index = (i * (points.length - 1) / (interior + 1)).round();
      result.add(points[index]);
    }
    result.add(points.last);
    return result;
  }

  _SectionInfo? _sectionInfo(ActiveWorldTrace trace, ValidatedRoad road) {
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
    var startOffset = 0.0;
    for (final section in sections) {
      if (section.id == trace.matchedSectionId) {
        if (section.geometry.length < 2) return null;
        return _SectionInfo(startOffset, section.geometry);
      }
      startOffset += section.distanceMeters;
    }
    return null;
  }

  _Projection? _project(
    CanonicalTelemetryPoint point,
    List<MatchedRoadPoint> geometry,
  ) {
    _Projection? best;
    var segmentOffset = 0.0;
    for (var i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];
      final length = GeoDistance.between(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
      if (length <= 0 || !length.isFinite) continue;
      final projection = _projectToSegment(point, start, end);
      final candidate = _Projection(
        distanceMeters: projection.distanceMeters,
        offset: segmentOffset + length * projection.ratio,
      );
      if (best == null || candidate.distanceMeters < best.distanceMeters) {
        best = candidate;
      }
      segmentOffset += length;
    }
    return best;
  }

  _SegmentProjection _projectToSegment(
    CanonicalTelemetryPoint point,
    MatchedRoadPoint start,
    MatchedRoadPoint end,
  ) {
    final cosLat = math.cos(start.latitude * math.pi / 180);
    final x = (point.longitude - start.longitude) * 111320 * cosLat;
    final y = (point.latitude - start.latitude) * 111320;
    final ex = (end.longitude - start.longitude) * 111320 * cosLat;
    final ey = (end.latitude - start.latitude) * 111320;
    final denominator = ex * ex + ey * ey;
    final ratio = denominator <= 0
        ? 0.0
        : (x * ex + y * ey) / denominator.clamp(0.0001, double.infinity);
    final clamped = ratio.clamp(0.0, 1.0).toDouble();
    final distance = math.sqrt(
      math.pow(x - ex * clamped, 2) + math.pow(y - ey * clamped, 2),
    );
    return _SegmentProjection(ratio: clamped, distanceMeters: distance);
  }
}

class _SectionInfo {
  const _SectionInfo(this.startOffsetMeters, this.geometry);
  final double startOffsetMeters;
  final List<MatchedRoadPoint> geometry;
}

class _Projection {
  const _Projection({required this.distanceMeters, required this.offset});
  final double distanceMeters;
  final double offset;
}

class _SegmentProjection {
  const _SegmentProjection({required this.ratio, required this.distanceMeters});
  final double ratio;
  final double distanceMeters;
}
