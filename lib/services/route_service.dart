import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteService {
  final List<LatLng> _routePoints = [];
  double _totalDistance = 0;

  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistance => _totalDistance;

  void reset() {
    _routePoints.clear();
    _totalDistance = 0;
  }

  void addPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);

    if (_routePoints.isNotEmpty) {
      final last = _routePoints.last;

      _totalDistance += Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
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
}