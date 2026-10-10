import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_result.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/local_lifecycle_journal.dart';
import 'package:driveit_project/services/independent_deletion_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/services/career_local_consumer.dart';
import 'package:driveit_project/services/world_source_access.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/models/world_index_mutation_plan.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';
import 'package:driveit_project/features/my_world/services/my_world_runtime.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'local_lifecycle_foundation_test.dart' as fixtures;

LocalSourceBundle source(String id, {bool telemetry = true}) {
  final map = fixtures.fixture(id, telemetry: telemetry).toMap();
  (map['roads'] as List).first['version'] =
      MyWorldRules.validatedRoadProcessingVersion;
  return LocalSourceBundle.fromMap(map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_3b_synthetic_');
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DriveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RoutePointAdapter());
    DriveTelemetryHive.registerAdapters(Hive);
    DriveScoreHive.registerAdapters(Hive);
    MyWorldHive.registerAdapters(Hive);
    await Hive.openBox<DriveSession>('drives');
    for (final box in ['career_totals', 'symbolic_routes', 'drive_names']) {
      await Hive.openBox<dynamic>(box);
    }
    await DriveTelemetryHive.openBox(Hive);
    await DriveScoreHive.openBox(Hive);
    await MyWorldHive.openBoxes(Hive);
    await WorldSourceSnapshotRepository.open(Hive);
    await CareerContributionRepository.open(Hive);
    await LocalLifecycleJournal.open(Hive);
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<void> seed(List<LocalSourceBundle> sources) async {
    for (final s in sources) {
      await Hive.box<DriveSession>('drives').put(s.drive.id, s.drive);
      if (s.telemetry != null) {
        await Hive.box<DriveTelemetryRecord>(
          DriveTelemetryHive.boxName,
        ).put(s.drive.id, s.telemetry!);
      }
      if (s.score != null) {
        await Hive.box<DriveScoreRecord>(
          DriveScoreHive.boxName,
        ).put('${s.drive.id}:v1', s.score!);
      }
      for (final r in s.roads) {
        await Hive.box<ValidatedRoad>(
          MyWorldHive.validatedRoadsBoxName,
        ).put(r.id, r);
      }
    }
    await Hive.box('career_totals').put('initialized', true);
    await Hive.box(
      'career_totals',
    ).put('atomicTotals', fixtures.totals(sources));
  }

  Future<void> rebuild() async {
    final r = await MyWorldRuntime.rebuildService().rebuild(
      targetVersion: DriveScoreAlgorithmVersion.v1,
    );
    expect(r.success, true, reason: r.failureReason);
  }

  List<Map<String, Object>> traceShape(dynamic snapshot) => [
    for (final t in snapshot.traces)
      {
        'id': t.id,
        'source': t.sourceDriveSessionId,
        'road': t.validatedRoadId,
        'section': t.matchedSectionId,
        'start': t.startOffsetMeters,
        'end': t.endOffsetMeters,
        'direction': t.directionKey,
      },
  ];

  test(
    'History deletion preserves World rebuild/detail and all Career metrics',
    () async {
      final s = source('legacy');
      await seed([s]);
      await rebuild();
      final before = await MyWorldRuntime.indexRepository().getActiveSnapshot();
      final career = fixtures.metrics(await CareerLocalConsumer.load());
      await DriveStorageService.deleteDrive('legacy');
      expect(DriveStorageService.getDrive('legacy'), isNull);
      expect(WorldSourceAccess.drive('legacy')!.date, s.drive.date);
      expect(
        await WorldSourceAccess.telemetry('legacy'),
        hasLength(s.telemetry!.points.length),
      );
      expect(
        traceShape(await MyWorldRuntime.indexRepository().getActiveSnapshot()),
        traceShape(before),
      );
      await rebuild();
      expect(
        traceShape(await MyWorldRuntime.indexRepository().getActiveSnapshot()),
        traceShape(before),
      );
      expect(fixtures.metrics(await CareerLocalConsumer.load()), career);
      expect((await MyWorldRuntime.readService().load()).traces, hasLength(1));
      await DriveStorageService.deleteDrive('legacy');
      expect(fixtures.metrics(await CareerLocalConsumer.load()), career);
    },
  );

  test(
    'cached intent retry must persist authorization before History removal',
    () async {
      await seed([source('intent-flush')]);
      await rebuild();
      var attempts = 0;
      var removed = false;
      Future<void> persist() async {
        attempts++;
        if (attempts == 1) {
          await LocalLifecycleJournal.box.put('history:intent-flush', {
            'version': 1,
            'state': 'prepared',
          });
          throw StateError('synthetic intent flush failed');
        }
        await LocalLifecycleJournal.intent('history', 'intent-flush');
      }

      Future<void> remove() async {
        expect(attempts, 2);
        removed = true;
      }

      await expectLater(
        IndependentDeletionService.deleteHistory(
          'intent-flush',
          removeHistory: remove,
          persistIntent: persist,
        ),
        throwsStateError,
      );
      expect(removed, false);
      await IndependentDeletionService.deleteHistory(
        'intent-flush',
        removeHistory: remove,
        persistIntent: persist,
      );
      expect(removed, true);
      expect(attempts, 2);
    },
  );

  test(
    'missing legacy Career source blocks deletion without altering World',
    () async {
      final s = source('known');
      await seed([s]);
      await rebuild();
      await Hive.box('career_totals').put('atomicTotals', {
        'countedIds': ['known', 'missing'],
        'totalDistance': 12000.0,
        'totalDuration': 360,
      });
      final before = await MyWorldRuntime.indexRepository().getActiveSnapshot();
      await expectLater(
        DriveStorageService.deleteDrive('known'),
        throwsStateError,
      );
      expect(DriveStorageService.getDrive('known'), isNotNull);
      expect(
        traceShape(await MyWorldRuntime.indexRepository().getActiveSnapshot()),
        traceShape(before),
      );
      expect(LocalLifecycleJournal.historyDeleted('known'), false);
    },
  );

  test('missing telemetry on active source blocks History deletion', () async {
    await seed([source('no-telemetry', telemetry: false)]);
    await rebuild();
    await expectLater(
      DriveStorageService.deleteDrive('no-telemetry'),
      throwsStateError,
    );
    expect(DriveStorageService.getDrive('no-telemetry'), isNotNull);
    expect(
      (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
      hasLength(1),
    );
  });

  test(
    'crash after durable History intent resumes cleanup and rejects source resurrection',
    () async {
      final s = source('crash');
      await seed([s]);
      await rebuild();
      await expectLater(
        IndependentDeletionService.deleteHistory(
          'crash',
          removeHistory: () async => fail('must not delete before crash'),
          afterIntent: () async => throw StateError('synthetic power loss'),
        ),
        throwsStateError,
      );
      expect(LocalLifecycleJournal.pending('history'), ['crash']);
      expect(DriveStorageService.getDrive('crash'), isNotNull);
      await IndependentDeletionService.recoverPending();
      expect(DriveStorageService.getDrive('crash'), isNull);
      expect(LocalLifecycleJournal.pending('history'), isEmpty);
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
        hasLength(1),
      );
      await expectLater(
        DriveStorageService.saveDrive(s.drive),
        throwsStateError,
      );
    },
  );

  test(
    'cross-box partial cleanup replays without changing Career or World',
    () async {
      final s = source('partial');
      await seed([s]);
      await rebuild();
      final stats = fixtures.metrics(await CareerLocalConsumer.load());
      await expectLater(
        IndependentDeletionService.deleteHistory(
          'partial',
          removeHistory: () async {
            await Hive.box<DriveSession>('drives').delete('partial');
            throw StateError('synthetic telemetry disk failure');
          },
        ),
        throwsStateError,
      );
      expect(DriveTelemetryStorageService.get('partial'), isNotNull);
      await IndependentDeletionService.recoverPending();
      expect(DriveTelemetryStorageService.get('partial'), isNull);
      expect(fixtures.metrics(await CareerLocalConsumer.load()), stats);
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
        hasLength(1),
      );
    },
  );

  test(
    'World tombstone does not remove History/Career and prevents rebuild/jobs revival',
    () async {
      final s = source('world-delete');
      await seed([s]);
      await rebuild();
      final stats = fixtures.metrics(await CareerLocalConsumer.load());
      final trace = (await MyWorldRuntime.indexRepository().getActiveSnapshot())
          .traces
          .single;
      await IndependentDeletionService.deleteWorldTrace(trace.id);
      expect(DriveStorageService.getDrive(s.drive.id), isNotNull);
      expect(fixtures.metrics(await CareerLocalConsumer.load()), stats);
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
        isEmpty,
      );
      await rebuild();
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
        isEmpty,
      );
      await MyWorldRuntime.enqueueSavedDrive(s.drive);
      expect(await MyWorldRuntime.repository().getPendingJobs(), isEmpty);
      final job = WorldPendingJob.pending(
        driveSessionId: s.drive.id,
        type: WorldJobType.validateRoad,
        now: fixtures.date,
      );
      expect(await MyWorldRuntime.repository().enqueueIfAbsent(job), false);
      await IndependentDeletionService.deleteWorldTrace(trace.id);
      expect(LocalLifecycleJournal.pending('worldTrace'), isEmpty);
      expect(LocalLifecycleJournal.worldHasDeletion(s.drive.id), true);
    },
  );

  test(
    'canonical partial tombstone preserves other spans and cannot be committed stale',
    () async {
      final s = source('split');
      await seed([s]);
      await rebuild();
      final index = MyWorldRuntime.indexRepository();
      final before = await index.getActiveSnapshot();
      final full = before.traces.single;
      await LocalLifecycleJournal.traceIntent(
        full.copyWith(
          id: 'cut',
          startOffsetMeters: 2000,
          endOffsetMeters: 4000,
        ),
      );
      final filtered = LocalLifecycleJournal.filterTraces(before.traces);
      expect(filtered.map((t) => (t.startOffsetMeters, t.endOffsetMeters)), [
        (0.0, 2000.0),
        (4000.0, 6000.0),
      ]);
      expect(
        LocalLifecycleJournal.filterTraces(before.traces).map((t) => t.id),
        filtered.map((t) => t.id),
      );
      await expectLater(
        index.commit(
          WorldIndexMutationPlan(
            operationId: 'stale-delete',
            sourceDriveSessionId: 'split',
            baseGeneration: before.generation,
            tracesToRemove: [],
            tracesToCreate: [],
            resultingSnapshot: before.copyWith(
              generation: before.generation + 1,
            ),
          ),
        ),
        throwsStateError,
      );
      expect((await index.getActiveSnapshot()).generation, before.generation);
      await rebuild();
      expect(
        traceShape(await index.getActiveSnapshot()),
        traceShape(before.copyWith(traces: filtered)),
      );
    },
  );

  test(
    'late score refresh updates ledger and World without counting another drive',
    () async {
      final s = source('score-refresh');
      await seed([s]);
      await rebuild();
      final before = await CareerLocalConsumer.load();
      await DriveStorageService.deleteDrive('score-refresh');
      // Recreate no History data: verify through the captured source itself.
      final snapshot = WorldSourceAccess.snapshot('score-refresh')!;
      final map = snapshot.toMap();
      map['score']['total'] = 800.0;
      map['score']['calculatedAt'] = DateTime.utc(2026, 1, 2).toIso8601String();
      map['score']['categories'] = [
        const DriveScoreCategoryRecord(
          categoryKey: 'synthetic',
          rawScore: 800,
          maximum: 1000,
          applicable: true,
          sampleSufficient: true,
          contributionUsed: 800,
          contributionSource: DriveScoreContributionSource.actual,
        ).toMap(),
      ];
      final updated = LocalSourceBundle.fromMap(map);
      final career = CareerContributionRepository(
        Hive.box(CareerContributionRepository.boxName),
      );
      await DriveScoreStorageService.save(updated.score!);
      await DriveScoreStorageService.save(updated.score!);
      final after = await CareerLocalConsumer.load();
      expect(after.drives.length, before.drives.length);
      expect(after.totalDistanceMeters, before.totalDistanceMeters);
      expect(after.bestScore!.totalScore, 800);
      expect(WorldSourceAccess.score('score-refresh')!.totalScore, 800);
      expect(DriveScoreStorageService.get(driveId: 'score-refresh'), isNull);
      expect(
        career.box.keys.where((k) => k.toString().startsWith('drive:')),
        hasLength(1),
      );
      expect(
        career.box.keys.where((k) => k.toString().contains(':revision:')),
        hasLength(1),
      );
    },
  );

  test(
    'missing snapshot store fails closed before any destructive write',
    () async {
      final s = source('no-store');
      await seed([s]);
      await rebuild();
      await Hive.box(WorldSourceSnapshotRepository.boxName).close();
      await expectLater(
        DriveStorageService.deleteDrive('no-store'),
        throwsStateError,
      );
      expect(DriveStorageService.getDrive('no-store'), isNotNull);
      expect(LocalLifecycleJournal.historyDeleted('no-store'), false);
    },
  );

  test(
    'flushed trace intent survives reopen and resumes exactly once',
    () async {
      final s = source('reopen');
      await seed([s]);
      await rebuild();
      final trace = (await MyWorldRuntime.indexRepository().getActiveSnapshot())
          .traces
          .single;
      await LocalLifecycleJournal.traceIntent(trace);
      await Hive.close();
      await Hive.openBox<DriveSession>('drives');
      for (final box in ['career_totals', 'symbolic_routes', 'drive_names']) {
        await Hive.openBox<dynamic>(box);
      }
      await DriveTelemetryHive.openBox(Hive);
      await DriveScoreHive.openBox(Hive);
      await MyWorldHive.openBoxes(Hive);
      await WorldSourceSnapshotRepository.open(Hive);
      await CareerContributionRepository.open(Hive);
      await LocalLifecycleJournal.open(Hive);
      await IndependentDeletionService.recoverPending();
      final generation =
          (await MyWorldRuntime.indexRepository().getActiveSnapshot())
              .generation;
      await IndependentDeletionService.recoverPending();
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).generation,
        generation,
      );
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
        isEmpty,
      );
      expect(DriveStorageService.getDrive('reopen'), isNotNull);
      expect(LocalLifecycleJournal.worldHasDeletion('reopen'), true);
    },
  );

  test(
    'first owner is stable; another valid source fills a deleted owner span',
    () async {
      final a = source('first');
      final b = source('second');
      b.drive.date = a.drive.date.add(const Duration(days: 1));
      await seed([a, b]);
      await rebuild();
      final before = await MyWorldRuntime.indexRepository().getActiveSnapshot();
      expect(before.traces, hasLength(1));
      expect(before.traces.single.sourceDriveSessionId, 'first');
      await IndependentDeletionService.deleteWorldTrace(
        before.traces.single.id,
      );
      final after = await MyWorldRuntime.indexRepository().getActiveSnapshot();
      expect(after.traces, hasLength(1));
      expect(after.traces.single.sourceDriveSessionId, 'second');
      await rebuild();
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot())
            .traces
            .single
            .sourceDriveSessionId,
        'second',
      );
    },
  );

  test(
    'both independent deletions retain Career but remove unused World source',
    () async {
      final s = source('both-deleted');
      await seed([s]);
      await rebuild();
      final trace = (await MyWorldRuntime.indexRepository().getActiveSnapshot())
          .traces
          .single;
      await DriveStorageService.deleteDrive('both-deleted');
      await IndependentDeletionService.deleteWorldTrace(trace.id);
      expect(DriveStorageService.getDrive('both-deleted'), isNull);
      expect(WorldSourceAccess.snapshot('both-deleted'), isNull);
      expect(LocalLifecycleJournal.worldHasDeletion('both-deleted'), true);
      await rebuild();
      expect(
        (await MyWorldRuntime.indexRepository().getActiveSnapshot()).traces,
        isEmpty,
      );
    },
  );

  test(
    'unresolved old World source cannot silently vanish in rebuild',
    () async {
      final s = source('orphan');
      await seed([s]);
      await rebuild();
      final index = MyWorldRuntime.indexRepository();
      final before = await index.getActiveSnapshot();
      await Hive.box<DriveSession>('drives').delete('orphan');
      final result = await MyWorldRuntime.rebuildService().rebuild(
        targetVersion: DriveScoreAlgorithmVersion.v1,
      );
      expect(result.success, false);
      expect((await index.getActiveSnapshot()).generation, before.generation);
      expect(traceShape(await index.getActiveSnapshot()), traceShape(before));
    },
  );
}
