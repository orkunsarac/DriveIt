import '../models/route_point.dart';
import '../models/canonical_telemetry_point.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteService {
  final List<LatLng> _routePoints = [];
  final Set<int> _breaks = {};
  double _totalDistance = 0;

  double _lastSegmentDistance = 0;

  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistance => _totalDistance;
  double get lastSegmentDistance => _lastSegmentDistance;

  void reset() {
    _routePoints.clear();
    _breaks.clear();
    _totalDistance = 0;
    _lastSegmentDistance = 0;
  }

  void addPosition(Position position) {
    addCoordinate(
      position.latitude,
      position.longitude,
      accuracy: position.accuracy,
    );
  }

  bool addCoordinate(double latitude, double longitude, {double? accuracy}) {
    final point = LatLng(latitude, longitude);
    _lastSegmentDistance = 0;
    if (accuracy != null && (!accuracy.isFinite || accuracy > 30)) return false;
    if (_routePoints.isEmpty) {
      _routePoints.add(point);
      return true;
    }

    final last = _routePoints.last;
    _lastSegmentDistance = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      latitude,
      longitude,
    );

    // Suppress stationary GPS drift and impossible jumps. Google Maps joins
    // consecutive accepted samples; no artificial interpolation is needed.
    if (_lastSegmentDistance < 3 || _lastSegmentDistance > 120) {
      _lastSegmentDistance = 0;
      return false;
    }

    _totalDistance += _lastSegmentDistance;
    _routePoints.add(point);
    return true;
  }

  /// Adds an already validated point without applying a second distance
  /// policy. Stationary telemetry remains available to analysis but is not
  /// duplicated in the visual/persisted route geometry.
  bool addCanonicalPoint(CanonicalTelemetryPoint point) {
    final coordinate = LatLng(point.latitude, point.longitude);
    _lastSegmentDistance = 0;
    if (_routePoints.isEmpty) {
      _routePoints.add(coordinate);
      return true;
    }
    if (point.breakBefore) {
      _breaks.add(_routePoints.length);
      _routePoints.add(coordinate);
      return true;
    }
    if (point.distanceFromPreviousMeters <= 0) return false;
    _lastSegmentDistance = point.distanceFromPreviousMeters;
    _totalDistance += point.distanceFromPreviousMeters;
    _routePoints.add(coordinate);
    return true;
  }

  Set<Polyline> buildPolylines() {
    final segments = <List<LatLng>>[];
    for (var i = 0; i < _routePoints.length; i++) {
      if (segments.isEmpty || _breaks.contains(i)) segments.add([]);
      segments.last.add(_routePoints[i]);
    }
    return {
      for (var i = 0; i < segments.length; i++)
        if (segments[i].length >= 2)
          Polyline(
            polylineId: PolylineId('drive_route_$i'),
            points: segments[i],
            color: const Color(0xFF2196F3),
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
    };
  }

  List<RoutePoint> getRouteForSave() {
    return [
      for (var i = 0; i < _routePoints.length; i++)
        RoutePoint(
          latitude: _routePoints[i].latitude,
          longitude: _routePoints[i].longitude,
          breakBefore: _breaks.contains(i),
        ),
    ];
  }

  Set<Polyline> get polylines => buildPolylines();

  double get distance => _totalDistance;
}
