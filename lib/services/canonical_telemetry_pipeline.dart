import 'dart:math' as math;

import '../models/canonical_telemetry_point.dart';

/// Central calibration values for location validation and normalization.
/// These values define data quality only; they are not Drive Score rules.
class CanonicalTelemetryRules {
  static const double maximumAccuracyMeters = 30;
  static const double minimumSampleIntervalSeconds = .2;
  static const double maximumPlausibleSpeedMps = 70;
  static const double maximumPlausiblePositionSpeedMps = 80;
  static const double maximumPlausibleAccelerationMps2 = 8;
  static const double stationarySpeedMps = 1.5;
  static const double minimumDistanceMeters = 3;
  static const double stationaryDriftRadiusMeters = 10;
  static const double maximumNativeGeometryDifferenceMps = 8;
  static const double minimumHeadingSpeedMps = 1.5;
  static const int speedMedianWindowSize = 5;
  static const double headingSmoothingFactor = .35;
  static const double minimumAltitudeMeters = -500;
  static const double maximumAltitudeMeters = 9000;
}

class RawTelemetryInput {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double speedMps;
  final double headingDegrees;
  final double altitudeMeters;
  final double accuracyMeters;

  const RawTelemetryInput({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speedMps,
    required this.headingDegrees,
    required this.altitudeMeters,
    required this.accuracyMeters,
  });
}

/// Stateful canonicalizer for one drive.
///
/// A single instance must receive one drive's samples in arrival order. It
/// rejects invalid/out-of-order points, resolves native speed against geometry,
/// suppresses one-sample speed spikes, derives acceleration from canonical
/// speed and calculates the only distance delta used by route persistence.
class CanonicalTelemetryPipeline {
  final List<double> _speedWindow = <double>[];
  CanonicalTelemetryPoint? _previous;
  CanonicalTelemetryPoint? _distanceAnchor;

  void reset() {
    _speedWindow.clear();
    _previous = null;
    _distanceAnchor = null;
  }

  CanonicalTelemetryPoint? add(RawTelemetryInput raw) {
    if (!_isBasicInputValid(raw)) return null;
    final timestamp = raw.timestamp!;
    final previous = _previous;

    var dt = 0.0;
    var segmentDistance = 0.0;
    var geometrySpeed = 0.0;
    if (previous != null) {
      dt = timestamp.difference(previous.timestamp).inMicroseconds / 1000000;
      if (!dt.isFinite ||
          dt < CanonicalTelemetryRules.minimumSampleIntervalSeconds) {
        return null;
      }
      segmentDistance = _distanceMeters(
        previous.latitude,
        previous.longitude,
        raw.latitude,
        raw.longitude,
      );
      geometrySpeed = segmentDistance / dt;
      if (!geometrySpeed.isFinite ||
          geometrySpeed >
              CanonicalTelemetryRules.maximumPlausiblePositionSpeedMps) {
        return null;
      }
    }

    final nativeSpeed = _validNativeSpeed(raw.speedMps) ? raw.speedMps : null;
    var candidateSpeed = nativeSpeed ?? geometrySpeed;
    if (previous != null && nativeSpeed != null) {
      final tolerance = math.max(
        CanonicalTelemetryRules.maximumNativeGeometryDifferenceMps,
        geometrySpeed * .75,
      );
      if ((nativeSpeed - geometrySpeed).abs() > tolerance) {
        candidateSpeed = geometrySpeed;
      }
    }
    if (previous == null ||
        (segmentDistance < CanonicalTelemetryRules.minimumDistanceMeters &&
            candidateSpeed <= CanonicalTelemetryRules.stationarySpeedMps)) {
      candidateSpeed = 0;
    }

    _speedWindow.add(
      candidateSpeed.clamp(0, CanonicalTelemetryRules.maximumPlausibleSpeedMps),
    );
    if (_speedWindow.length > CanonicalTelemetryRules.speedMedianWindowSize) {
      _speedWindow.removeAt(0);
    }
    var canonicalSpeed = _median(_speedWindow);

    var acceleration = 0.0;
    if (previous != null) {
      acceleration = (canonicalSpeed - previous.speedMps) / dt;
      if (!acceleration.isFinite ||
          acceleration.abs() >
              CanonicalTelemetryRules.maximumPlausibleAccelerationMps2) {
        canonicalSpeed = previous.speedMps;
        acceleration = 0;
        _speedWindow[_speedWindow.length - 1] = canonicalSpeed;
      }
    }

    final distance = _canonicalDistance(raw, canonicalSpeed, timestamp);
    final heading = _canonicalHeading(
      raw,
      canonicalSpeed,
      segmentDistance,
      previous,
    );
    final altitude =
        raw.altitudeMeters.isFinite &&
            raw.altitudeMeters >=
                CanonicalTelemetryRules.minimumAltitudeMeters &&
            raw.altitudeMeters <= CanonicalTelemetryRules.maximumAltitudeMeters
        ? raw.altitudeMeters
        : previous?.altitudeMeters ?? 0;

    final point = CanonicalTelemetryPoint(
      latitude: raw.latitude,
      longitude: raw.longitude,
      timestamp: timestamp,
      speedMps: canonicalSpeed,
      headingDegrees: heading,
      altitudeMeters: altitude,
      accuracyMeters: raw.accuracyMeters,
      distanceFromPreviousMeters: distance,
      accelerationMps2: acceleration,
    );
    _previous = point;
    _distanceAnchor ??= point;
    if (distance > 0) _distanceAnchor = point;
    return point;
  }

  bool _isBasicInputValid(RawTelemetryInput raw) =>
      raw.timestamp != null &&
      raw.latitude.isFinite &&
      raw.longitude.isFinite &&
      raw.latitude.abs() <= 90 &&
      raw.longitude.abs() <= 180 &&
      raw.accuracyMeters.isFinite &&
      raw.accuracyMeters >= 0 &&
      raw.accuracyMeters <= CanonicalTelemetryRules.maximumAccuracyMeters;

  bool _validNativeSpeed(double speed) =>
      speed.isFinite &&
      speed >= 0 &&
      speed <= CanonicalTelemetryRules.maximumPlausibleSpeedMps;

  double _canonicalDistance(
    RawTelemetryInput raw,
    double canonicalSpeed,
    DateTime timestamp,
  ) {
    final anchor = _distanceAnchor;
    if (anchor == null) return 0;
    final distance = _distanceMeters(
      anchor.latitude,
      anchor.longitude,
      raw.latitude,
      raw.longitude,
    );
    if (distance < CanonicalTelemetryRules.minimumDistanceMeters) return 0;
    if (canonicalSpeed <= CanonicalTelemetryRules.stationarySpeedMps &&
        distance < CanonicalTelemetryRules.stationaryDriftRadiusMeters) {
      return 0;
    }
    final dt = timestamp.difference(anchor.timestamp).inMicroseconds / 1000000;
    if (dt <= 0 ||
        distance / dt >
            CanonicalTelemetryRules.maximumPlausiblePositionSpeedMps) {
      return 0;
    }
    return distance;
  }

  double _canonicalHeading(
    RawTelemetryInput raw,
    double speed,
    double segmentDistance,
    CanonicalTelemetryPoint? previous,
  ) {
    final moving =
        speed >= CanonicalTelemetryRules.minimumHeadingSpeedMps ||
        segmentDistance >= CanonicalTelemetryRules.minimumDistanceMeters;
    if (!moving) return previous?.headingDegrees ?? 0;

    double candidate;
    if (_validHeading(raw.headingDegrees)) {
      candidate = raw.headingDegrees;
    } else if (previous != null && segmentDistance > 0) {
      candidate = _bearingDegrees(
        previous.latitude,
        previous.longitude,
        raw.latitude,
        raw.longitude,
      );
    } else {
      return previous?.headingDegrees ?? 0;
    }

    final old = previous?.headingDegrees;
    if (old == null || !_validHeading(old)) return candidate;
    final delta = ((candidate - old + 540) % 360) - 180;
    return (old +
            delta * CanonicalTelemetryRules.headingSmoothingFactor +
            360) %
        360;
  }

  bool _validHeading(double heading) =>
      heading.isFinite && heading >= 0 && heading < 360;

  double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _distanceMeters(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadius = 6371000.0;
    final lat1 = firstLatitude * math.pi / 180;
    final lat2 = secondLatitude * math.pi / 180;
    final deltaLat = (secondLatitude - firstLatitude) * math.pi / 180;
    final deltaLng = (secondLongitude - firstLongitude) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _bearingDegrees(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    final lat1 = firstLatitude * math.pi / 180;
    final lat2 = secondLatitude * math.pi / 180;
    final deltaLng = (secondLongitude - firstLongitude) * math.pi / 180;
    final y = math.sin(deltaLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
