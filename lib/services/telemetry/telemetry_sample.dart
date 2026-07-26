import 'package:google_maps_flutter/google_maps_flutter.dart';

class TelemetrySample {
  final DateTime timestamp;

  final LatLng position;

  final double speed; // km/h

  final double heading;

  final double accuracy;

  final double altitude;

  final double distanceFromPrevious;

  final double acceleration;

  const TelemetrySample({
    required this.timestamp,
    required this.position,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.altitude,
    required this.distanceFromPrevious,
    required this.acceleration,
  });
}