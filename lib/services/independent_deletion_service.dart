import 'package:hive/hive.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/persistence/my_world_hive.dart';
import '../features/my_world/repositories/world_source_snapshot_repository.dart';
import '../features/my_world/services/my_world_runtime.dart';
import '../features/drive_score/models/drive_score_algorithm_version.dart';
import '../features/my_world/models/world_index_snapshot.dart';
import '../features/my_world/services/world_index_mutation_planner.dart';
import '../features/my_world/config/my_world_rules.dart';
import 'career_contribution_repository.dart';
import 'local_data_preparation_service.dart';
import 'local_lifecycle_journal.dart';
import 'world_source_access.dart';
import 'drive_storage_service.dart';

class IndependentDeletionService {
  static Future<void> recoverPending() async {
    // Only explicitly authorized intents are replayed; never infer deletion
    // from missing source data or migrate/delete the user's other records.
    for (final id in LocalLifecycleJournal.pending('history')) {
      await DriveStorageService.deleteDrive(id);
    }
    for (final id in LocalLifecycleJournal.pending('worldTrace')) {
      await deleteWorldTrace(id);
    }
  }

  static final Map<String, Future<void>> _inFlight = {};
  static Future<void> _once(String key, Future<void> Function() body) {
    final active = _inFlight[key];
    if (active != null) return active;
    final future = body();
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  static Future<void> deleteHistory(
    String id, {
    required Future<void> Function() removeHistory,
    Future<void> Function()? afterIntent,
    // Fault-injection boundary; production always uses the durable journal.
    Future<void> Function()? persistIntent,
  }) => _once('history:$id', () async {
    if (!LocalLifecycleJournal.available ||
        !Hive.isBoxOpen(CareerContributionRepository.boxName) ||
        !Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName) ||
        !Hive.isBoxOpen(MyWorldHive.indexSnapshotsBoxName) ||
        !Hive.isBoxOpen(MyWorldHive.validatedRoadsBoxName)) {
      throw StateError('Silme koruması hazır değil; sürüş korunuyor.');
    }
    if (!LocalLifecycleJournal.historyDeleted(id)) {
      if (!await LocalDataPreparationService.prepareLegacyCareer()) {
        throw StateError(
          'Eski Kariyer geçmişi tam doğrulanamadı; sürüş silinmedi.',
        );
      }
      final career = CareerContributionRepository(
        Hive.box<dynamic>(CareerContributionRepository.boxName),
      );
      final source = LocalDataPreparationService.readSource(id);
      if (source == null || !career.box.containsKey('drive:$id')) {
        throw StateError('Kariyer katkısı eksik; sürüş silinmedi.');
      }
      // Re-read and verify the immutable contribution, including a late score.
      await career.add(source);
      if (career.statistics() == null) {
        throw StateError('Kariyer katkıları doğrulanamadı; sürüş silinmedi.');
      }
      if (!LocalLifecycleJournal.worldDeleted(id) &&
          Hive.isBoxOpen(MyWorldHive.indexSnapshotsBoxName)) {
        final traces = await MyWorldRuntime.indexRepository()
            .getActiveTracesForDrive(id);
        final hasWorldData =
            traces.isNotEmpty ||
            source.score != null ||
            Hive.box<ValidatedRoad>(
              MyWorldHive.validatedRoadsBoxName,
            ).values.any((road) => road.driveSessionId == id);
        if (hasWorldData) {
          if (!await LocalDataPreparationService.prepareWorldSource(id)) {
            throw StateError('Bağımsız Dünya kaynağı eksik; sürüş silinmedi.');
          }
          final snapshot = WorldSourceAccess.snapshot(id)!;
          if ((traces.isNotEmpty &&
                  (snapshot.telemetry == null ||
                      snapshot.telemetry!.points.isEmpty ||
                      snapshot.score == null)) ||
              traces.any(
                (trace) => !snapshot.roads.any(
                  (road) =>
                      road.id == trace.validatedRoadId &&
                      road.sections.any(
                        (section) => section.id == trace.matchedSectionId,
                      ),
                ),
              )) {
            throw StateError(
              'Dünya telemetry/skor/geometri koruması eksik; sürüş silinmedi.',
            );
          }
        }
      }
      // No destructive write has occurred before this durable authorization.
    }
    // A failed flush may leave an intent visible in Hive's memory cache.
    // Every destructive retry must establish durability again, not infer it
    // from containsKey alone.
    await (persistIntent?.call() ??
        LocalLifecycleJournal.intent('history', id));
    await afterIntent?.call();
    await removeHistory();
    await _purgeWhollyDeletedWorldSource(id);
    await LocalLifecycleJournal.complete('history', id);
  });

  /// A canonical span tombstone removes only the selected ownership trace.
  /// Other spans of the same source and all independent domains survive.
  static Future<void> deleteWorldTrace(
    String traceId,
  ) => _once('worldTrace:$traceId', () async {
    if (!LocalLifecycleJournal.available) {
      throw StateError('Dünya silme günlüğü hazır değil.');
    }
    final index = MyWorldRuntime.indexRepository();
    final before = await index.getActiveSnapshot();
    final selected = before.traces.where((t) => t.id == traceId).firstOrNull;
    if (selected == null &&
        !LocalLifecycleJournal.box.containsKey('worldTrace:$traceId')) {
      throw StateError('Seçilen kişisel Dünya izi bulunamadı.');
    }
    // Missing historical sources must never disappear during a deletion rebuild.
    for (final trace in before.traces) {
      if (WorldSourceAccess.drive(trace.sourceDriveSessionId) == null ||
          await MyWorldRuntime.repository().getValidatedRoad(
                trace.validatedRoadId,
              ) ==
              null) {
        throw StateError(
          'Başka bir Dünya izinin kaynağı eksik; silme durduruldu.',
        );
      }
    }
    if (selected != null) await LocalLifecycleJournal.traceIntent(selected);
    await LocalLifecycleJournal.intent('worldTrace', traceId);
    final current = await index.getActiveSnapshot();
    final filtered = LocalLifecycleJournal.filterTraces(current.traces);
    if (filtered.length != current.traces.length ||
        List.generate(
          filtered.length,
          (i) => filtered[i].id != current.traces[i].id,
        ).any((v) => v)) {
      final result = await MyWorldRuntime.rebuildService().rebuild(
        targetVersion: DriveScoreAlgorithmVersion.v1,
        reason: 'independentWorldDeletion:$traceId',
      );
      if (!result.success) {
        throw StateError(
          'Dünya silme tamamlanamadı; güvenli tekrar denenebilir.',
        );
      }
    }
    final sourceId =
        (LocalLifecycleJournal.box.get('worldTrace:$traceId')
                as Map)['sourceId']
            as String;
    await _purgeWhollyDeletedWorldSource(sourceId);
    await LocalLifecycleJournal.complete('worldTrace', traceId);
  });

  static Future<void> _purgeWhollyDeletedWorldSource(String id) async {
    if (DriveStorageService.getDrive(id) != null ||
        !LocalLifecycleJournal.worldHasDeletion(id)) {
      return;
    }
    final source = WorldSourceAccess.snapshot(id);
    if (source == null) return;
    if ((await MyWorldRuntime.indexRepository().getActiveTracesForDrive(
      id,
    )).isNotEmpty) {
      return;
    }
    final eligible = source.roads.where(
      (r) =>
          r.processingVersion == MyWorldRules.validatedRoadProcessingVersion &&
          r.validDistanceMeters >= MyWorldRules.minimumValidDistanceMeters,
    );
    for (final road in eligible) {
      final footprint = const WorldIndexMutationPlanner()
          .plan(
            current: WorldIndexSnapshot.empty(
              driveScoreAlgorithmVersion: 1,
              validatedRoadProcessingVersion: MyWorldRules.worldRulesVersion,
            ),
            challengerRoad: road,
            overlaps: [],
            now: road.createdAt,
          )
          .resultingSnapshot
          .traces;
      // A dormant, non-deleted span may still legitimately reappear when a
      // different owner is removed. Do not purge its genuine source payload.
      if (LocalLifecycleJournal.filterTraces(footprint).isNotEmpty) return;
    }
    await MyWorldRuntime.repository().deleteWorldDataForDrive(id);
    final box = Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName);
    await box.delete(id);
    await box.flush();
  }
}
