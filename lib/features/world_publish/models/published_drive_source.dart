/// Version of the lossless source-data JSON contract, independent of scoring
/// and World processing versions.
abstract final class PublishedDriveSourceSchema {
  static const int currentVersion = 1;
}

class PublishedRoutePoint {
  const PublishedRoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory PublishedRoutePoint.fromJson(Map<String, dynamic> json) =>
      PublishedRoutePoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

class PublishedTelemetryPoint {
  const PublishedTelemetryPoint({
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

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speedMps;
  final double headingDegrees;
  final double altitudeMeters;
  final double accuracyMeters;
  final double distanceFromPreviousMeters;
  final double accelerationMps2;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'speed_mps': speedMps,
    'heading_degrees': headingDegrees,
    'altitude_meters': altitudeMeters,
    'accuracy_meters': accuracyMeters,
    'distance_from_previous_meters': distanceFromPreviousMeters,
    'acceleration_mps2': accelerationMps2,
  };

  factory PublishedTelemetryPoint.fromJson(Map<String, dynamic> json) =>
      PublishedTelemetryPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        speedMps: (json['speed_mps'] as num).toDouble(),
        headingDegrees: (json['heading_degrees'] as num).toDouble(),
        altitudeMeters: (json['altitude_meters'] as num).toDouble(),
        accuracyMeters: (json['accuracy_meters'] as num).toDouble(),
        distanceFromPreviousMeters:
            (json['distance_from_previous_meters'] as num).toDouble(),
        accelerationMps2: (json['acceleration_mps2'] as num).toDouble(),
      );
}

/// A snapshot of the recorded inputs needed to replay the World pipeline.
/// Every nested point is immutable and both lists preserve their source order.
class PublishedDriveSource {
  PublishedDriveSource({
    required this.schemaVersion,
    required this.publishId,
    required this.localDriveId,
    required this.telemetryVersion,
    required this.driveScoreAlgorithmVersion,
    required this.worldRulesVersion,
    required this.startedAt,
    required this.endedAt,
    required this.recordedDistanceMeters,
    required List<PublishedRoutePoint> rawRoute,
    required List<PublishedTelemetryPoint> canonicalTelemetry,
  }) : rawRoute = List.unmodifiable(rawRoute),
       canonicalTelemetry = List.unmodifiable(canonicalTelemetry);

  final int schemaVersion;
  final String publishId;
  final String localDriveId;
  final int telemetryVersion;
  final int driveScoreAlgorithmVersion;
  final int worldRulesVersion;
  final DateTime startedAt;
  final DateTime endedAt;
  final double recordedDistanceMeters;
  final List<PublishedRoutePoint> rawRoute;
  final List<PublishedTelemetryPoint> canonicalTelemetry;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'publish_id': publishId,
    'local_drive_id': localDriveId,
    'telemetry_version': telemetryVersion,
    'drive_score_algorithm_version': driveScoreAlgorithmVersion,
    'world_rules_version': worldRulesVersion,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'recorded_distance_meters': recordedDistanceMeters,
    'raw_route': rawRoute.map((point) => point.toJson()).toList(),
    'canonical_telemetry': canonicalTelemetry
        .map((point) => point.toJson())
        .toList(),
  };

  factory PublishedDriveSource.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'] as int;
    if (schemaVersion != PublishedDriveSourceSchema.currentVersion) {
      throw FormatException(
        'Unsupported source schema version: $schemaVersion',
      );
    }
    return PublishedDriveSource(
      schemaVersion: schemaVersion,
      publishId: json['publish_id'] as String,
      localDriveId: json['local_drive_id'] as String,
      telemetryVersion: json['telemetry_version'] as int,
      driveScoreAlgorithmVersion: json['drive_score_algorithm_version'] as int,
      worldRulesVersion: json['world_rules_version'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      recordedDistanceMeters: (json['recorded_distance_meters'] as num)
          .toDouble(),
      rawRoute: (json['raw_route'] as List)
          .map(
            (point) => PublishedRoutePoint.fromJson(
              (point as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      canonicalTelemetry: (json['canonical_telemetry'] as List)
          .map(
            (point) => PublishedTelemetryPoint.fromJson(
              (point as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}
