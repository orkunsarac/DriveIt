import '../../my_world/config/my_world_rules.dart';
import '../../../models/canonical_telemetry_point.dart';

/// Version of the lossless source-data JSON contract, independent of scoring
/// and World processing versions.
abstract final class PublishedDriveSourceSchema {
  static const int currentVersion = 1;
  static const int reliableVersion = 2;
}

class PublishedRoutePoint {
  const PublishedRoutePoint({
    required this.latitude,
    required this.longitude,
    this.breakBefore,
  });

  final double latitude;
  final double longitude;
  final bool? breakBefore;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (breakBefore != null) 'break_before': breakBefore,
  };

  factory PublishedRoutePoint.fromJson(Map<String, dynamic> json) =>
      PublishedRoutePoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        breakBefore: json['break_before'] as bool?,
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
    this.breakBefore,
    this.gapDurationMicros,
    this.speedSource,
    this.accelerationReliable,
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
  final bool? breakBefore, accelerationReliable;
  final int? gapDurationMicros;
  final String? speedSource;

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
    if (speedSource != null) ...{
      'timestamp_micros': timestamp.toUtc().microsecondsSinceEpoch.toString(),
      'break_before': breakBefore,
      'gap_duration_micros': gapDurationMicros,
      'speed_source': speedSource,
      'acceleration_reliable': accelerationReliable,
    },
  };

  factory PublishedTelemetryPoint.fromJson(Map<String, dynamic> json) =>
      PublishedTelemetryPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: _readTimestamp(json),
        speedMps: (json['speed_mps'] as num).toDouble(),
        headingDegrees: (json['heading_degrees'] as num).toDouble(),
        altitudeMeters: (json['altitude_meters'] as num).toDouble(),
        accuracyMeters: (json['accuracy_meters'] as num).toDouble(),
        distanceFromPreviousMeters:
            (json['distance_from_previous_meters'] as num).toDouble(),
        accelerationMps2: (json['acceleration_mps2'] as num).toDouble(),
        breakBefore: json['break_before'] as bool?,
        gapDurationMicros: json['gap_duration_micros'] as int?,
        speedSource: json['speed_source'] as String?,
        accelerationReliable: json['acceleration_reliable'] as bool?,
      );

  static DateTime _readTimestamp(Map<String, dynamic> json) {
    final time = DateTime.parse(json['timestamp'] as String);
    if (json['speed_source'] != null &&
        json['timestamp_micros'] != time.microsecondsSinceEpoch.toString()) {
      throw const FormatException('Reliable timestamp evidence mismatch');
    }
    return time;
  }
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
    this.calculationMode,
    this.calculationVersion,
    Map<String, dynamic>? telemetryReliability,
  }) : rawRoute = List.unmodifiable(rawRoute),
       canonicalTelemetry = List.unmodifiable(canonicalTelemetry),
       telemetryReliability = telemetryReliability == null
           ? null
           : Map.unmodifiable(telemetryReliability) {
    validateScoreContract();
  }

  final String? calculationMode;
  final int? calculationVersion;
  final Map<String, dynamic>? telemetryReliability;

  void validateScoreContract() {
    if (schemaVersion == 1) {
      if (calculationMode != null ||
          calculationVersion != null ||
          telemetryReliability != null) {
        throw const FormatException(
          'Legacy source cannot declare reliable scoring',
        );
      }
      return;
    }
    if (schemaVersion != 2 ||
        telemetryVersion != DriveTelemetryRecord.currentDataVersion ||
        worldRulesVersion != MyWorldRules.worldRulesVersion ||
        driveScoreAlgorithmVersion != 1 ||
        calculationMode != 'reliable_intervals' ||
        calculationVersion != 1 ||
        telemetryReliability?['reliabilityPolicyVersion'] != 1 ||
        telemetryReliability?['startedAtMicros'] is! int ||
        telemetryReliability?['stopRequestedAtMicros'] is! int) {
      throw const FormatException('Unsupported or unproven scoring contract');
    }
    final start = telemetryReliability!['startedAtMicros'] as int;
    final end = telemetryReliability!['stopRequestedAtMicros'] as int;
    if (rawRoute.any(
          (p) =>
              p.breakBefore == null ||
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180,
        ) ||
        end <= start ||
        start != startedAt.microsecondsSinceEpoch ||
        end != endedAt.microsecondsSinceEpoch ||
        canonicalTelemetry.length < 2 ||
        canonicalTelemetry.any(
          (p) =>
              p.breakBefore == null ||
              p.accelerationReliable == null ||
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180 ||
              !p.speedMps.isFinite ||
              !p.headingDegrees.isFinite ||
              !p.altitudeMeters.isFinite ||
              !p.accuracyMeters.isFinite ||
              !p.distanceFromPreviousMeters.isFinite ||
              !p.accelerationMps2.isFinite ||
              p.gapDurationMicros == null ||
              p.gapDurationMicros! < 0 ||
              ![
                'native',
                'geometry_estimate',
                'held_estimate',
                'unavailable',
              ].contains(p.speedSource) ||
              p.timestamp.microsecondsSinceEpoch < start ||
              p.timestamp.microsecondsSinceEpoch > end,
        )) {
      throw const FormatException('Missing reliable telemetry evidence');
    }
    for (var i = 1; i < canonicalTelemetry.length; i++) {
      if (!canonicalTelemetry[i].timestamp.isAfter(
        canonicalTelemetry[i - 1].timestamp,
      )) {
        throw const FormatException('Unordered reliable telemetry');
      }
    }
  }

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
    if (schemaVersion == 2) ...{
      'score_calculation_mode': calculationMode,
      'score_calculation_version': calculationVersion,
      'telemetry_reliability': telemetryReliability,
    },
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
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw FormatException(
        'Unsupported source schema version: $schemaVersion',
      );
    }
    return PublishedDriveSource(
      schemaVersion: schemaVersion,
      calculationMode: json['score_calculation_mode'] as String?,
      calculationVersion: json['score_calculation_version'] as int?,
      telemetryReliability: (json['telemetry_reliability'] as Map?)
          ?.cast<String, dynamic>(),
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
