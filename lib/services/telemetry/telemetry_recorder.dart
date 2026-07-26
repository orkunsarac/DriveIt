import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'telemetry_sample.dart';

class TelemetryRecorder {

  final List<TelemetrySample> _samples = [];

  List<TelemetrySample> get samples =>
      List.unmodifiable(_samples);

  void clear() {
    _samples.clear();
  }

  void add({
    required Position position,
    required double distance,
    required double acceleration,
  }) {

    _samples.add(
      TelemetrySample(
        timestamp: DateTime.now(),
        position: LatLng(
          position.latitude,
          position.longitude,
        ),
        speed: position.speed * 3.6,
        heading: position.heading,
        accuracy: position.accuracy,
        altitude: position.altitude,
        distanceFromPrevious: distance,
        acceleration: acceleration,
      ),
    );
  }
}