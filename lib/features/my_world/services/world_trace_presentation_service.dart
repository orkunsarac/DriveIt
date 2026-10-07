import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/my_world_rules.dart';
import '../models/world_map_read_model.dart';
import '../models/world_trace_travel_direction.dart';

/// Presentation-only helpers for World traces. Offset geometry is temporary;
/// persisted ownership geometry is never changed.
class WorldTracePresentationService {
  const WorldTracePresentationService();

  Set<String> oppositeTraceIds(List<ResolvedWorldTrace> traces) {
    final result = <String>{};
    for (var i = 0; i < traces.length; i++) {
      for (var j = i + 1; j < traces.length; j++) {
        if (_isOppositeNearPair(traces[i], traces[j])) {
          result
            ..add(traces[i].trace.id)
            ..add(traces[j].trace.id);
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

  List<LatLng> renderGeometry({
    required ResolvedWorldTrace trace,
    required bool separateOpposite,
    required double zoom,
    ResolvedWorldTrace? oppositePartner,
  }) => renderPoints(
    id: trace.trace.id,
    points: _sourceLatLng(trace),
    separateOpposite: separateOpposite,
    zoom: zoom,
    partnerId: oppositePartner?.trace.id,
    partnerPoints: oppositePartner == null
        ? null
        : _sourceLatLng(oppositePartner),
  );

  /// Geometry-only adapter shared with the server-backed Planet map. No local
  /// ownership/model fabrication or telemetry is needed for presentation.
  List<LatLng> renderPoints({
    required String id,
    required List<LatLng> points,
    required bool separateOpposite,
    required double zoom,
    String? partnerId,
    List<LatLng>? partnerPoints,
  }) {
    if (!separateOpposite || points.length < 2 || zoom < 6) {
      return points;
    }
    final requestedOffset = MyWorldRules.oppositeTraceVisualOffsetMeters;
    final side = partnerId == null || id.compareTo(partnerId) < 0 ? 1.0 : -1.0;
    final referencePoints = partnerPoints == null
        ? points
        : (id.compareTo(partnerId!) <= 0 ? points : partnerPoints);
    final referenceTangents = _tangentField(referencePoints);
    return points
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final point = entry.value;
          final referenceIndex = partnerPoints == null
              ? index
              : _nearestIndex(point, referencePoints);
          final tangent = referenceTangents[referenceIndex];
          final turnScale = _cornerOffsetScale(referencePoints, referenceIndex);
          final metres = requestedOffset * turnScale;
          final angle = (tangent + 90 * side) * math.pi / 180;
          final latOffset = metres * math.cos(angle) / 111320;
          final lonScale = 111320 * math.cos(point.latitude * math.pi / 180);
          final lonOffset = lonScale.abs() < 1
              ? 0
              : metres * math.sin(angle) / lonScale;
          return LatLng(
            point.latitude + latOffset,
            point.longitude + lonOffset,
          );
        })
        .toList(growable: false);
  }

  List<double> _tangentField(List<dynamic> points) {
    final result = <double>[];
    for (var index = 0; index < points.length; index++) {
      var tangent = _stableLocalBearing(points, index);
      if (result.isNotEmpty) {
        tangent = _limitAngleStep(
          result.last,
          tangent,
          MyWorldRules.oppositeTraceMaximumNormalTurnDegrees,
        );
      }
      result.add(tangent);
    }
    return result;
  }

  List<LatLng> _sourceLatLng(ResolvedWorldTrace trace) => trace.geometry
      .map((point) => LatLng(point.latitude, point.longitude))
      .toList(growable: false);

  bool oppositeGeometry(List<LatLng> a, List<LatLng> b) {
    if (a.length < 2 || b.length < 2) return false;
    double low(List<LatLng> p, bool lat) =>
        p.map((v) => lat ? v.latitude : v.longitude).reduce(math.min);
    double high(List<LatLng> p, bool lat) =>
        p.map((v) => lat ? v.latitude : v.longitude).reduce(math.max);
    if (low(a, true) > high(b, true) ||
        high(a, true) < low(b, true) ||
        low(a, false) > high(b, false) ||
        high(a, false) < low(b, false)) {
      return false;
    }
    final index = a.length ~/ 2;
    return _angleDifference(
          _stableLocalBearing(a, index),
          _stableLocalBearing(b, _nearestIndex(a[index], b)),
        ).abs() >=
        150;
  }

  double _stableLocalBearing(List<dynamic> points, int index) {
    final origin = points[index];
    dynamic before = origin;
    dynamic after = origin;
    var beforeIndex = index - 1;
    while (beforeIndex >= 0) {
      if (_distance(origin, points[beforeIndex]) >=
          MyWorldRules.oppositeTraceTangentWindowMeters) {
        before = points[beforeIndex];
        break;
      }
      beforeIndex--;
    }
    var afterIndex = index + 1;
    while (afterIndex < points.length) {
      if (_distance(origin, points[afterIndex]) >=
          MyWorldRules.oppositeTraceTangentWindowMeters) {
        after = points[afterIndex];
        break;
      }
      afterIndex++;
    }
    if (identical(before, origin) && !identical(after, origin)) before = origin;
    if (identical(after, origin) && !identical(before, origin)) after = origin;
    return _bearing(
      before.latitude,
      before.longitude,
      after.latitude,
      after.longitude,
    );
  }

  double _cornerOffsetScale(List<dynamic> points, int index) {
    if (index == 0 || index + 1 >= points.length) return 1;
    final incoming = _bearing(
      points[index - 1].latitude,
      points[index - 1].longitude,
      points[index].latitude,
      points[index].longitude,
    );
    final outgoing = _bearing(
      points[index].latitude,
      points[index].longitude,
      points[index + 1].latitude,
      points[index + 1].longitude,
    );
    final turn = _angleDifference(outgoing, incoming).abs();
    if (turn <= MyWorldRules.oppositeTraceCornerStartDegrees) return 1;
    return math.max(
      MyWorldRules.minimumCornerOffsetScale,
      math.sin((180 - math.min(turn, 170)) * math.pi / 360),
    );
  }

  double _limitAngleStep(double previous, double current, double maxStep) {
    final delta = _angleDifference(current, previous);
    if (delta.abs() <= maxStep) return current;
    return (previous + delta.sign * maxStep + 360) % 360;
  }

  bool _isOppositeNearPair(ResolvedWorldTrace a, ResolvedWorldTrace b) {
    if (a.geometry.length < 2 || b.geometry.length < 2) return false;
    if (!a.trace.intersectsBounds(
      minLatitude: b.trace.minLatitude,
      maxLatitude: b.trace.maxLatitude,
      minLongitude: b.trace.minLongitude,
      maxLongitude: b.trace.maxLongitude,
    )) {
      return false;
    }
    final metadataOpposite =
        a.travelDirection != WorldTraceTravelDirection.unknown &&
        b.travelDirection != WorldTraceTravelDirection.unknown &&
        a.travelDirection != b.travelDirection;
    final aIndex = a.geometry.length ~/ 2;
    final bIndex = _nearestIndex(a.geometry[aIndex], b.geometry);
    final localDifference = _angleDifference(
      _stableLocalBearing(a.geometry, aIndex),
      _stableLocalBearing(b.geometry, bIndex),
    ).abs();
    final geometryOpposite = localDifference >= 150;
    if (kDebugMode && (metadataOpposite || geometryOpposite)) {
      debugPrint(
        '[WORLD_OPPOSITE_RENDER] a=${a.trace.id} b=${b.trace.id} '
        'metadataOpposite=$metadataOpposite localTangentDifference=${localDifference.toStringAsFixed(1)} '
        'geometryOpposite=$geometryOpposite',
      );
    }
    return metadataOpposite || geometryOpposite;
  }

  int _nearestIndex(dynamic point, List<dynamic> points) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final distance = _distance(point, points[index]);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    return best;
  }

  double _distance(dynamic a, dynamic b) {
    final dLat = (a.latitude - b.latitude) * 111320;
    final dLon =
        (a.longitude - b.longitude) *
        111320 *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(p2);
    final x =
        math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _angleDifference(double a, double b) => ((a - b + 540) % 360) - 180;
}
