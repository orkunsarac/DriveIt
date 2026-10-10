import '../../../models/canonical_telemetry_point.dart';
import '../../../models/drive_session.dart';
import '../../../services/drive_time_analysis.dart';
import '../../my_world/config/my_world_rules.dart';

/// The v1 source wire format drops continuity flags. Never feed it disconnected
/// or unknown evidence. Existing server-ready sources are recovered separately.
class LegacyWholeDriveSafety {
  const LegacyWholeDriveSafety._();
  static bool canBuild(DriveSession drive, DriveTelemetryRecord? record) {
    if (record == null ||
        record.driveSessionId != drive.id ||
        record.dataVersion != DriveTelemetryRecord.currentDataVersion ||
        record.acquisitionMetadata['reliabilityPolicyVersion'] != 1 ||
        record.points.length < 2 ||
        drive.route.skip(1).any((p) => p.breakBefore)) {
      return false;
    }
    final points = record.points;
    if (points.any(
      (p) =>
          !DriveTimeAnalysis.validPoint(p) ||
          !p.speedMps.isFinite ||
          !p.headingDegrees.isFinite ||
          !p.altitudeMeters.isFinite ||
          !p.accelerationMps2.isFinite ||
          !p.distanceFromPreviousMeters.isFinite ||
          p.distanceFromPreviousMeters < 0 ||
          p.gapDurationMicros < 0,
    )) {
      return false;
    }
    for (var i = 1; i < points.length; i++) {
      if (!DriveTimeAnalysis.reliableInterval(points[i - 1], points[i])) {
        return false;
      }
    }
    return DriveTimeAnalysis.analyze(points).distanceMeters >=
        MyWorldRules.minimumValidDistanceMeters;
  }
}
