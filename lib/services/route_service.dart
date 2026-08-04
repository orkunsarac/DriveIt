import '../models/route_point.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteService {
  final List<LatLng> _routePoints = [];
  double _totalDistance = 0;

  double _lastSegmentDistance = 0;

  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistance => _totalDistance;
  double get lastSegmentDistance => _lastSegmentDistance;

  void reset() {
    _routePoints.clear();
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

  bool addCoordinate(
    double latitude,
    double longitude, {
    double? accuracy,
  }) {
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

  Set<Polyline> buildPolylines() {
    return {
      Polyline(
        polylineId: const PolylineId('drive_route'),
        points: _routePoints,
        color: const Color(0xFF2196F3),
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  List<RoutePoint> getRouteForSave() {
    return _routePoints
        .map(
          (p) => RoutePoint(
            latitude: p.latitude,
            longitude: p.longitude,
          ),
        )
        .toList();
  }
    Set<Polyline> get polylines => buildPolylines();

    double get distance => _totalDistance;
}
