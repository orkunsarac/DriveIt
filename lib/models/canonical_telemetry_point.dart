import 'dart:math' as math;

/// Versioned, validated telemetry used by every post-drive analysis.
///
/// Values use SI units so later Drive Score phases do not need to guess the
/// source unit. This model deliberately contains no scoring or event state.
class CanonicalTelemetryPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speedMps;
  final double headingDegrees;
  final double altitudeMeters;
  final double accuracyMeters;
  final double distanceFromPreviousMeters;
  final double accelerationMps2;

  const CanonicalTelemetryPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speedMps,
    required this.headingDegrees,
    required this.altitudeMeters,
    required this.accuracyMeters,
    required this.distanceFromPreviousMeters,
    required this.accelerationMps2,
  });

  Map<String, dynamic> toMap() => {
    'lat': latitude,
    'lng': longitude,
    'time': timestamp.millisecondsSinceEpoch,
    'speed': speedMps,
    'heading': headingDegrees,
    'altitude': altitudeMeters,
    'accuracy': accuracyMeters,
    'distance': distanceFromPreviousMeters,
    'acceleration': accelerationMps2,
    'telemetryVersion': DriveTelemetryRecord.currentDataVersion,
  };

  static CanonicalTelemetryPoint? fromMap(Map<String, dynamic> value) {
    final latitude = value['lat'];
    final longitude = value['lng'];
    final timestamp = value['time'];
    if (latitude is! num || longitude is! num || timestamp is! num) {
      return null;
    }

    double number(String key, [double fallback = 0]) {
      final raw = value[key];
      return raw is num && raw.toDouble().isFinite ? raw.toDouble() : fallback;
    }

    final point = CanonicalTelemetryPoint(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()),
      speedMps: math.max(0, number('speed')),
      headingDegrees: number('heading', -1),
      altitudeMeters: number('altitude'),
      accuracyMeters: math.max(0, number('accuracy', 999)),
      distanceFromPreviousMeters: math.max(0, number('distance')),
      accelerationMps2: number('acceleration'),
    );
    if (!point.hasValidCoordinate) return null;
    return point;
  }

  bool get hasValidCoordinate =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

/// One persisted canonical timeline, addressed deterministically by drive ID.
class DriveTelemetryRecord {
  static const int currentDataVersion = 1;

  final String driveSessionId;
  final int dataVersion;
  final DateTime createdAt;
  final List<CanonicalTelemetryPoint> points;

  const DriveTelemetryRecord({
    required this.driveSessionId,
    required this.dataVersion,
    required this.createdAt,
    required this.points,
  });
}
