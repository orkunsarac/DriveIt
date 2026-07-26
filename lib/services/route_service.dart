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
    final point = LatLng(position.latitude, position.longitude);

    _lastSegmentDistance = 0;

if (_routePoints.isNotEmpty) {
  final last = _routePoints.last;

  _lastSegmentDistance = Geolocator.distanceBetween(
    last.latitude,
    last.longitude,
    point.latitude,
    point.longitude,
  );

  _totalDistance += _lastSegmentDistance;
}

    _routePoints.add(point);
  }

  Set<Polyline> buildPolylines() {
    return {
      Polyline(
        polylineId: const PolylineId('drive_route'),
        points: _routePoints,
        color: const Color(0xFF2196F3),
        width: 6,
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