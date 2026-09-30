import '../../../models/canonical_telemetry_point.dart';
import '../../../models/drive_session.dart';
import '../../../models/route_point.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../../drive_score/models/drive_score_algorithm_version.dart';
import '../../my_world/config/my_world_rules.dart';
import '../models/published_drive_source.dart';
import '../models/world_publish.dart';

enum PublishedDriveSourceBuildStatus {
  success,
  missingCanonicalTelemetry,
  invalidCanonicalTelemetry,
  invalidDrive,
  publishDriveMismatch,
}

class PublishedDriveSourceBuildResult {
  const PublishedDriveSourceBuildResult(this.status, {this.source});

  final PublishedDriveSourceBuildStatus status;
  final PublishedDriveSource? source;
}

/// Reads existing local data and builds a source snapshot. It performs no
/// upload, World processing, or persistence mutation.
class PublishedDriveSourceBuilder {
  const PublishedDriveSourceBuilder({
    this.telemetryLoader = DriveTelemetryStorageService.get,
  });

  final DriveTelemetryRecord? Function(String driveId) telemetryLoader;

  PublishedDriveSourceBuildResult build({
    required DriveSession drive,
    required WorldPublish publish,
  }) {
    if (publish.localDriveId != drive.id) {
      return const PublishedDriveSourceBuildResult(
        PublishedDriveSourceBuildStatus.publishDriveMismatch,
      );
    }
    if (drive.id.trim().isEmpty ||
        publish.id.trim().isEmpty ||
        drive.durationSeconds <= 0 ||
        !drive.distance.isFinite ||
        drive.distance < 0 ||
        !_hasUsableRawRoute(drive.route)) {
      return const PublishedDriveSourceBuildResult(
        PublishedDriveSourceBuildStatus.invalidDrive,
      );
    }
    final telemetry = telemetryLoader(drive.id);
    if (telemetry == null || telemetry.points.length < 2) {
      return const PublishedDriveSourceBuildResult(
        PublishedDriveSourceBuildStatus.missingCanonicalTelemetry,
      );
    }
    if (telemetry.driveSessionId != drive.id ||
        telemetry.dataVersion <= 0 ||
        telemetry.points.any((point) => !_isUsableTelemetryPoint(point))) {
      return const PublishedDriveSourceBuildResult(
        PublishedDriveSourceBuildStatus.invalidCanonicalTelemetry,
      );
    }

    final endedAt = drive.date.toUtc();
    return PublishedDriveSourceBuildResult(
      PublishedDriveSourceBuildStatus.success,
      source: PublishedDriveSource(
        schemaVersion: PublishedDriveSourceSchema.currentVersion,
        publishId: publish.id,
        localDriveId: drive.id,
        telemetryVersion: telemetry.dataVersion,
        driveScoreAlgorithmVersion: DriveScoreAlgorithmVersion.v1.value,
        worldRulesVersion: MyWorldRules.worldRulesVersion,
        startedAt: endedAt.subtract(Duration(seconds: drive.durationSeconds)),
        endedAt: endedAt,
        recordedDistanceMeters: drive.distance,
        rawRoute: [
          for (final point in drive.route)
            PublishedRoutePoint(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
        ],
        canonicalTelemetry: [
          for (final point in telemetry.points)
            PublishedTelemetryPoint(
              latitude: point.latitude,
              longitude: point.longitude,
              timestamp: point.timestamp.toUtc(),
              speedMps: point.speedMps,
              headingDegrees: point.headingDegrees,
              altitudeMeters: point.altitudeMeters,
              accuracyMeters: point.accuracyMeters,
              distanceFromPreviousMeters: point.distanceFromPreviousMeters,
              accelerationMps2: point.accelerationMps2,
            ),
        ],
      ),
    );
  }

  bool _hasUsableRawRoute(List<RoutePoint> route) {
    if (route.length < 2) return false;
    RoutePoint? firstUsable;
    var hasDistinctUsablePoint = false;
    for (final point in route) {
      if (!point.latitude.isFinite || !point.longitude.isFinite) return false;
      if (point.latitude.abs() > 90 || point.longitude.abs() > 180) continue;
      firstUsable ??= point;
      if (point.latitude != firstUsable.latitude ||
          point.longitude != firstUsable.longitude) {
        hasDistinctUsablePoint = true;
      }
    }
    return hasDistinctUsablePoint;
  }

  bool _isUsableTelemetryPoint(CanonicalTelemetryPoint point) =>
      point.hasValidCoordinate &&
      point.speedMps.isFinite &&
      point.headingDegrees.isFinite &&
      point.altitudeMeters.isFinite &&
      point.accuracyMeters.isFinite &&
      point.distanceFromPreviousMeters.isFinite &&
      point.accelerationMps2.isFinite;
}
