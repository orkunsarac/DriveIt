import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/drive_session.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/persistence/my_world_hive.dart';
import '../features/my_world/repositories/world_source_snapshot_repository.dart';
import 'local_source_bundle.dart';
import 'career_contribution_repository.dart';
import 'drive_telemetry_storage_service.dart';
import 'drive_score_storage_service.dart';

/// Explicit local preparation entry points, not a startup migration. Source
/// boxes and World generations are read only. Phase 3B must verify readiness
/// before enabling independent deletion; missing historical sources stay missing.
class LocalDataPreparationService {
  static LocalSourceBundle? readSource(String id) {
    if (!Hive.isBoxOpen('drives')) return null;
    final drive = Hive.box<DriveSession>('drives').get(id);
    if (drive == null) return null;
    return LocalSourceBundle(
      drive: drive,
      telemetry: DriveTelemetryStorageService.get(id),
      score: DriveScoreStorageService.get(driveId: id),
      roads: Hive.isBoxOpen(MyWorldHive.validatedRoadsBoxName)
          ? Hive.box<ValidatedRoad>(
              MyWorldHive.validatedRoadsBoxName,
            ).values.where((r) => r.driveSessionId == id).toList()
          : const [],
    );
  }

  static Future<bool> prepareWorldSource(String id) async {
    final source = readSource(id);
    if (source == null) return false;
    final repository = WorldSourceSnapshotRepository(
      Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
    );
    // Preserve an existing immutable source and enrich validation only.
    final existing = repository.get(id);
    if (existing == null) {
      await repository.prepare(source);
    } else {
      await repository.prepare(
        LocalSourceBundle(
          drive: source.drive,
          telemetry: source.telemetry,
          score: source.score,
          ownerScope: source.ownerScope,
        ),
      );
      for (final road in source.roads) {
        await repository.attachRoad(road);
      }
    }
    return repository.get(id) != null;
  }

  static Future<bool> prepareLegacyCareer() async {
    final contributions = CareerContributionRepository(
      Hive.box<dynamic>(CareerContributionRepository.boxName),
    );
    if (contributions.legacyReady) return true;
    final totals = Hive.box<dynamic>('career_totals');
    if (totals.get('initialized') != true) {
      // Only a genuinely empty installation has an unambiguous zero baseline.
      if (totals.isNotEmpty || Hive.box<DriveSession>('drives').isNotEmpty) {
        return false;
      }
      return contributions.prepareLegacy(
        sources: [],
        totals: {
          'countedIds': <String>[],
          'totalDistance': 0.0,
          'totalDuration': 0,
        },
      );
    }
    final atomic = totals.get('atomicTotals') as Map?;
    final baseline = {
      'countedIds': atomic?['countedIds'] ?? totals.get('countedIds'),
      'totalDistance': atomic?['totalDistance'] ?? totals.get('totalDistance'),
      'totalDuration': atomic?['totalDuration'] ?? totals.get('totalDuration'),
    };
    if (baseline.values.any((v) => v == null)) return false;
    final staged = contributions.box.get('baseline') as Map?;
    if (staged != null && staged['payload'] != jsonEncode(baseline)) {
      // Preserve an unresolved older baseline verbatim. It must not prevent a
      // new drive being recorded, but it continues to block unsafe deletion.
      return false;
    }
    return contributions.prepareLegacy(
      sources: Hive.box<DriveSession>(
        'drives',
      ).values.map((d) => readSource(d.id)!).toList(),
      totals: baseline,
    );
  }
}
