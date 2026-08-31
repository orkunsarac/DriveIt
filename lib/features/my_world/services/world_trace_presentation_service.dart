import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/world_map_read_model.dart';

/// Presentation-only helpers for world traces. Persisted geometry is never
/// changed by this service.
class WorldTracePresentationService {
  const WorldTracePresentationService();

  Set<String> oppositeTraceIds(List<ResolvedWorldTrace> traces) {
    final result = <String>{};
    for (var i = 0; i < traces.length; i++) {
      for (var j = i + 1; j < traces.length; j++) {
        final a = traces[i];
        final b = traces[j];
        if (_isOppositeNearPair(a, b)) {
          result..add(a.trace.id)..add(b.trace.id);
        }
      }
    }
    return result;
  }

  Map<String, ResolvedWorldTrace> oppositePartnerMap(
    List<ResolvedWorldTrace> traces,
  ) {
    final result = <String, ResolvedWorldTrace>{};
    for (var i = 0; i < traces.length; i++) {
      for (var j = i + 1; j < traces.length; j++) {
        final a = traces[i];
        final b = traces[j];
        if (_isOppositeNearPair(a, b)) {
          result[a.trace.id] = b;
          result[b.trace.id] = a;
        }
      }
    }
    return result;
  }

  ResolvedWorldTrace? oppositePartner(
    ResolvedWorldTrace trace,
    List<ResolvedWorldTrace> traces,
  ) {
    for (final candidate in traces) {
      if (candidate.trace.id == trace.trace.id) continue;
      if (_isOppositeNearPair(trace, candidate)) return candidate;
    }
    return null;
  }

  List<LatLng> renderGeometry({
    required ResolvedWorldTrace trace,
    required bool separateOpposite,
    required double zoom,
    ResolvedWorldTrace? oppositePartner,
  }) {
    if (!separateOpposite || trace.geometry.length < 2 || zoom < 6) {
      return trace.geometry
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);
    }
    // A few screen pixels at normal zoom, deliberately reduced when zoomed
    // out. This is never written to Hive or fed into ownership comparisons.
    final metres = zoom >= 15
        ? 5.0
        : (zoom >= 13 ? 4.0 : (zoom >= 11 ? 2.8 : 1.2));
    final direction = _bearing(
      trace.geometry.first.latitude,
      trace.geometry.first.longitude,
      trace.geometry.last.latitude,
      trace.geometry.last.longitude,
    );
    final side = oppositePartner == null ||
            trace.trace.id.compareTo(oppositePartner.trace.id) < 0
        ? 1.0
        : -1.0;
    final angle = (direction + 90 * side) * math.pi / 180;
    return trace.geometry.map((p) {
          if (oppositePartner != null &&
              _nearestDistance(p, oppositePartner.geometry) > 15) {
            return LatLng(p.latitude, p.longitude);
          }
          final latOffset = metres * math.cos(angle) / 111320;
          final lonScale = 111320 * math.cos(p.latitude * math.pi / 180);
          final lonOffset = lonScale.abs() < 1 ? 0 : metres * math.sin(angle) / lonScale;
          return LatLng(p.latitude + latOffset, p.longitude + lonOffset);
        })
        .toList(growable: false);
  }

  double _nearestDistance(dynamic point, List<dynamic> points) => points
      .map((candidate) => _distance(point, candidate))
      .reduce(math.min);

  bool _isOppositeNearPair(ResolvedWorldTrace a, ResolvedWorldTrace b) {
    if (a.geometry.length < 2 || b.geometry.length < 2) return false;
    final boundsOverlap = a.trace.intersectsBounds(
      minLatitude: b.trace.minLatitude,
      maxLatitude: b.trace.maxLatitude,
      minLongitude: b.trace.minLongitude,
      maxLongitude: b.trace.maxLongitude,
    );
    if (!boundsOverlap) return false;
    // Require local proximity and opposite local tangents over a continuous
    // run; endpoint/whole-trace bearings are insufficient at intersections.
    var continuousMeters = 0.0;
    var bestContinuousMeters = 0.0;
    for (var i = 1; i < a.geometry.length; i++) {
      final point = a.geometry[i];
      final previous = a.geometry[i - 1];
      final nearestIndex = _nearestIndex(point, b.geometry);
      final nearest = b.geometry[nearestIndex];
      final proximity = _distance(point, nearest);
      final aHeading = _bearing(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      final bPrevious = nearestIndex == 0
          ? b.geometry.first
          : b.geometry[nearestIndex - 1];
      final bNext = nearestIndex + 1 >= b.geometry.length
          ? b.geometry.last
          : b.geometry[nearestIndex + 1];
      final bHeading = _bearing(
        bPrevious.latitude,
        bPrevious.longitude,
        bNext.latitude,
        bNext.longitude,
      );
      final opposite = proximity <= 15 &&
          _angleDifference(aHeading, bHeading).abs() >= 150;
      final segmentMeters = _distance(previous, point);
      if (opposite) {
        continuousMeters += segmentMeters;
        bestContinuousMeters = math.max(bestContinuousMeters, continuousMeters);
      } else {
        continuousMeters = 0;
      }
    }
    return bestContinuousMeters >= 60;
  }

  int _nearestIndex(dynamic point, List<dynamic> points) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final candidate = _distance(point, points[i]);
      if (candidate < distance) {
        distance = candidate;
        best = i;
      }
    }
    return best;
  }

  double _distance(dynamic a, dynamic b) {
    final dLat = (a.latitude - b.latitude) * 111320;
    final dLon = (a.longitude - b.longitude) *
        111320 * math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _angleDifference(double a, double b) => ((a - b + 540) % 360) - 180;
}
