import 'package:hive/hive.dart';
import '../models/drive_session.dart';
import '../models/drive_score_record.dart';
import '../models/canonical_telemetry_point.dart';
import '../features/my_world/repositories/world_source_snapshot_repository.dart';
import 'drive_storage_service.dart';
import 'drive_score_storage_service.dart';
import 'drive_telemetry_storage_service.dart';
import 'local_source_bundle.dart';
import 'local_lifecycle_journal.dart';

/// One read-only source policy for World consumers, never for History/Planet.
class WorldSourceAccess {
  static LocalSourceBundle? snapshot(String id) =>
      Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName)
      ? WorldSourceSnapshotRepository(
          Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
        ).get(id)
      : null;
  static DriveSession? drive(String id) =>
      LocalLifecycleJournal.worldDeleted(id)
      ? null
      : snapshot(id)?.drive ?? DriveStorageService.getDrive(id);
  static DriveScoreRecord? score(String id) =>
      snapshot(id)?.score ?? DriveScoreStorageService.get(driveId: id);
  static Future<List<CanonicalTelemetryPoint>> telemetry(String id) async =>
      snapshot(id)?.telemetry?.points ??
      DriveTelemetryStorageService.get(id)?.points ??
      const [];
  static List<DriveSession> drives() {
    final sources = {
      for (final d in DriveStorageService.getAllDrives()) d.id: d,
    };
    if (Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName)) {
      for (final s in WorldSourceSnapshotRepository(
        Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
      ).getAll()) {
        sources[s.drive.id] = s.drive;
      }
    }
    return sources.values
        .where((d) => !LocalLifecycleJournal.worldDeleted(d.id))
        .toList();
  }
}
