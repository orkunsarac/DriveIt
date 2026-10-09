/// A location sample used only for post-drive analysis.
///
/// Route persistence intentionally remains latitude/longitude-only. These
/// samples are collected during the active drive and are reduced to
/// [DriveMetrics] before the session is saved.
class DriveTelemetrySample {
  final double latitude;
  final double longitude;
  final double speedMps;
  final double accuracyMeters;
  final double heading;
  final double altitudeMeters;
  final DateTime timestamp;
  final double? canonicalAccelerationMps2;
  final bool accelerationReliable;
  final bool breakBefore;

  const DriveTelemetrySample({
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.accuracyMeters,
    required this.heading,
    required this.altitudeMeters,
    required this.timestamp,
    this.canonicalAccelerationMps2,
    this.accelerationReliable = true,
    this.breakBefore = false,
  });
}
