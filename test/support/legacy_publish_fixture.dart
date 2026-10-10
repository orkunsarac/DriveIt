import 'package:driveit_project/models/canonical_telemetry_point.dart';

/// Continuous >=5km evidence for legacy API serialization tests, not real data.
DriveTelemetryRecord legacyPublishFixture(
  String id, {
  double distance = 6000,
}) => DriveTelemetryRecord(
  driveSessionId: id,
  dataVersion: 1,
  createdAt: DateTime.utc(2026),
  acquisitionMetadata: const {'reliabilityPolicyVersion': 1},
  points: [
    for (var i = 0; i <= 200; i++)
      CanonicalTelemetryPoint(
        latitude: 40 + i * .0002,
        longitude: 29,
        timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
        speedMps: 30,
        headingDegrees: 0,
        altitudeMeters: 0,
        accuracyMeters: 5,
        distanceFromPreviousMeters: i == 0 ? 0 : distance / 200,
        accelerationMps2: 0,
        speedSource: 'gps',
      ),
  ],
);
