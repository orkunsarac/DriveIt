import '../../../models/canonical_telemetry_point.dart';
import '../../../models/drive_session.dart';
import '../../../models/route_point.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../../drive_score/models/drive_score_algorithm_version.dart';
import '../../my_world/config/my_world_rules.dart';
import '../models/published_drive_source.dart';
import '../models/world_publish.dart';
import 'legacy_whole_drive_safety.dart';
import '../../../models/drive_score_record.dart';
import '../../../services/drive_score_storage_service.dart';
import '../../../services/drive_time_analysis.dart';

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
    this.scoreLoader = _loadScore,
  });

  final DriveTelemetryRecord? Function(String driveId) telemetryLoader;
  final DriveScoreRecord? Function(String driveId) scoreLoader;
  static DriveScoreRecord? _loadScore(String id) =>
      DriveScoreStorageService.get(driveId: id);

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
    final savedScore = scoreLoader(drive.id);
    final reliable = savedScore?.calculationMode == 'reliable_intervals';
    if ((savedScore != null &&
            (savedScore.driveId != drive.id ||
                savedScore.algorithmVersion !=
                    DriveScoreAlgorithmVersion.v1.value ||
                savedScore.telemetryDataVersion != telemetry.dataVersion)) ||
        (savedScore != null &&
            ![
              'unspecified',
              'legacy_v1',
              'reliable_intervals',
            ].contains(savedScore.calculationMode)) ||
        (reliable &&
            (drive.route.any(
                  (p) =>
                      !p.latitude.isFinite ||
                      !p.longitude.isFinite ||
                      p.latitude.abs() > 90 ||
                      p.longitude.abs() > 180,
                ) ||
                savedScore!.calculationVersion != 1 ||
                savedScore.reliabilityPolicyVersion != 1 ||
                telemetry.acquisitionMetadata['reliabilityPolicyVersion'] !=
                    1 ||
                !DriveTimeAnalysis.fromRecord(telemetry).scoreEligible ||
                telemetry.points.any(
                  (p) =>
                      ![
                        'native',
                        'geometry_estimate',
                        'held_estimate',
                        'unavailable',
                      ].contains(p.speedSource) ||
                      p.gapDurationMicros < 0,
                ))) ||
        (!reliable && !LegacyWholeDriveSafety.canBuild(drive, telemetry))) {
      return const PublishedDriveSourceBuildResult(
        PublishedDriveSourceBuildStatus.invalidCanonicalTelemetry,
      );
    }

    final endedAt = reliable
        ? DateTime.fromMicrosecondsSinceEpoch(
            telemetry.acquisitionMetadata['stopRequestedAtMicros'] as int,
            isUtc: true,
          )
        : drive.date.toUtc();
    return PublishedDriveSourceBuildResult(
      PublishedDriveSourceBuildStatus.success,
      source: PublishedDriveSource(
        schemaVersion: reliable
            ? PublishedDriveSourceSchema.reliableVersion
            : PublishedDriveSourceSchema.currentVersion,
        calculationMode: reliable ? 'reliable_intervals' : null,
        calculationVersion: reliable ? 1 : null,
        telemetryReliability: reliable
            ? {
                'reliabilityPolicyVersion': 1,
                'startedAtMicros':
                    telemetry.acquisitionMetadata['startedAtMicros'],
                'stopRequestedAtMicros':
                    telemetry.acquisitionMetadata['stopRequestedAtMicros'],
              }
            : null,
        publishId: publish.id,
        localDriveId: drive.id,
        telemetryVersion: telemetry.dataVersion,
        driveScoreAlgorithmVersion: DriveScoreAlgorithmVersion.v1.value,
        worldRulesVersion: MyWorldRules.worldRulesVersion,
        startedAt: reliable
            ? DateTime.fromMicrosecondsSinceEpoch(
                telemetry.acquisitionMetadata['startedAtMicros'] as int,
                isUtc: true,
              )
            : endedAt.subtract(Duration(seconds: drive.durationSeconds)),
        endedAt: endedAt,
        recordedDistanceMeters: drive.distance,
        rawRoute: [
          for (final point in drive.route)
            PublishedRoutePoint(
              latitude: point.latitude,
              longitude: point.longitude,
              breakBefore: reliable ? point.breakBefore : null,
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
              breakBefore: reliable ? point.breakBefore : null,
              gapDurationMicros: reliable ? point.gapDurationMicros : null,
              speedSource: reliable ? point.speedSource : null,
              accelerationReliable: reliable
                  ? point.accelerationReliable
                  : null,
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
