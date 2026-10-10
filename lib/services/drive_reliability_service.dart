import 'drive_telemetry_storage_service.dart';
import 'drive_time_analysis.dart';

/// Existing telemetry metadata is the authority; no new box/schema or writes.
class DriveReliabilityService {
  static DriveTimeAnalysis? get(String driveId) {
    final record = DriveTelemetryStorageService.get(driveId);
    return record == null ? null : DriveTimeAnalysis.fromRecord(record);
  }
}
