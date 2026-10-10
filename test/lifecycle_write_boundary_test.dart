import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/repositories/hive_my_world_index_repository.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';
import 'package:driveit_project/features/my_world/services/world_index_mutation_planner.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/services/local_lifecycle_journal.dart';
import 'package:driveit_project/features/my_world/repositories/hive_my_world_repository.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'local_lifecycle_foundation_test.dart' as fixtures;

/// Controlled acknowledgement failure, not a physical disk failure/process kill.
class FlushFaultBox<T> implements Box<T> {
  FlushFaultBox(this.inner, this.failAt);
  final Box<T> inner;
  final int failAt;
  int flushes = 0;
  @override
  Future<void> flush() async {
    if (++flushes == failAt) {
      throw StateError('synthetic flush boundary $failAt');
    }
    await inner.flush();
  }

  @override
  T? get(dynamic key, {T? defaultValue}) =>
      inner.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, T value) => inner.put(key, value);
  @override
  bool containsKey(dynamic key) => inner.containsKey(key);
  @override
  Iterable<dynamic> get keys => inner.keys;
  @override
  String? get path => inner.path;
  @override
  String get name => inner.name;
  @override
  int get length => inner.length;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_3d_boundaries_');
    Hive.init(root.path);
    MyWorldHive.registerAdapters(Hive);
    await MyWorldHive.openBoxes(Hive);
    await WorldSourceSnapshotRepository.open(Hive);
    await CareerContributionRepository.open(Hive);
    await LocalLifecycleJournal.open(Hive);
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  test(
    'pending enqueue and provider persistence cannot cross queued tombstone',
    () async {
      final repository = HiveMyWorldRepository(
        Hive.box(MyWorldHive.validatedRoadsBoxName),
        Hive.box(MyWorldHive.processingBoxName),
        Hive.box(MyWorldHive.pendingJobsBoxName),
      );
      final road = fixtures.fixture('pending-race').roads.single;
      final plan = const WorldIndexMutationPlanner().plan(
        current: WorldIndexSnapshot.empty(
          driveScoreAlgorithmVersion: 1,
          validatedRoadProcessingVersion: 6,
        ),
        challengerRoad: road,
        overlaps: [],
        now: fixtures.date,
      );
      final intent = LocalLifecycleJournal.traceIntent(
        plan.resultingSnapshot.traces.single,
      );
      final write = repository.saveValidatedRoad(road);
      final enqueue = repository.enqueueIfAbsent(
        WorldPendingJob.pending(
          driveSessionId: road.driveSessionId,
          type: WorldJobType.validateRoad,
          now: fixtures.date,
        ),
      );
      await intent;
      await write;
      expect(await enqueue, false);
      expect(await repository.getValidatedRoad(road.id), isNull);
      expect(await repository.getPendingJobs(), isEmpty);
    },
  );
  for (final boundary in [1, 2]) {
    test(
      'snapshot flush $boundary failure retries exact payload once',
      () async {
        final box = FlushFaultBox<dynamic>(
          Hive.box(WorldSourceSnapshotRepository.boxName),
          boundary,
        );
        final repository = WorldSourceSnapshotRepository(box);
        final source = fixtures.fixture('snapshot');
        await expectLater(repository.prepare(source), throwsStateError);
        await repository.prepare(source);
        expect(repository.getAll(), hasLength(1));
        expect(box.flushes, greaterThan(boundary));
        await Hive.close();
        await WorldSourceSnapshotRepository.open(Hive);
        expect(
          WorldSourceSnapshotRepository(
            Hive.box(WorldSourceSnapshotRepository.boxName),
          ).get('snapshot'),
          isNotNull,
        );
      },
    );
    test(
      'Career flush $boundary failure preserves one contribution on retry',
      () async {
        final box = FlushFaultBox<dynamic>(
          Hive.box(CareerContributionRepository.boxName),
          boundary,
        );
        final repository = CareerContributionRepository(box);
        final source = fixtures.fixture('career');
        await expectLater(repository.add(source), throwsStateError);
        await repository.add(source);
        expect(
          box.keys.where((k) => k.toString().startsWith('drive:')),
          hasLength(1),
        );
        expect(box.flushes, greaterThan(boundary));
      },
    );
  }
  test(
    'validated-road attachment retry reflushes cached matching payload',
    () async {
      final box = FlushFaultBox<dynamic>(
        Hive.box(WorldSourceSnapshotRepository.boxName),
        3,
      );
      final repository = WorldSourceSnapshotRepository(box);
      final source = fixtures.fixture('road');
      await repository.prepare(fixtures.fixture('road', telemetry: true));
      // Same validated road with a new derived revision is staged separately.
      final road = source.roads.single;
      // Existing identical attachment still acknowledges durability.
      await expectLater(repository.attachRoad(road), throwsStateError);
      await repository.attachRoad(road);
      expect(box.flushes, 4);
      expect(repository.get('road')!.roads, hasLength(1));
    },
  );
  test(
    'generation snapshot flush failure leaves previous pointer; retry commits once',
    () async {
      final snapshots = FlushFaultBox<WorldIndexSnapshot>(
        Hive.box(MyWorldHive.indexSnapshotsBoxName),
        1,
      );
      final index = HiveMyWorldIndexRepository(
        snapshots,
        Hive.box(MyWorldHive.indexMetadataBoxName),
      );
      final before = await index.getActiveSnapshot();
      final plan = const WorldIndexMutationPlanner().plan(
        current: before,
        challengerRoad: fixtures.fixture('plan').roads.single,
        overlaps: [],
        now: fixtures.date,
      );
      await expectLater(index.commit(plan), throwsStateError);
      expect((await index.getActiveSnapshot()).generation, before.generation);
      await index.commit(plan);
      expect(
        (await index.getActiveSnapshot()).generation,
        before.generation + 1,
      );
      await expectLater(index.commit(plan), throwsStateError);
    },
  );
  test(
    'pointer acknowledgement failure retains a complete generation and rejects replay',
    () async {
      final metadata = FlushFaultBox<WorldIndexPointer>(
        Hive.box(MyWorldHive.indexMetadataBoxName),
        1,
      );
      final index = HiveMyWorldIndexRepository(
        Hive.box(MyWorldHive.indexSnapshotsBoxName),
        metadata,
      );
      final before = await index.getActiveSnapshot();
      final plan = const WorldIndexMutationPlanner().plan(
        current: before,
        challengerRoad: fixtures.fixture('pointer').roads.single,
        overlaps: [],
        now: fixtures.date,
      );
      await expectLater(index.commit(plan), throwsStateError);
      // put may already be persisted even if the explicit flush acknowledgement
      // fails. This is a complete old/new snapshot, not a rollback guarantee.
      final observed = await index.getActiveSnapshot();
      expect(observed.generation, plan.resultingSnapshot.generation);
      expect(observed.traces, hasLength(1));
      await expectLater(index.commit(plan), throwsStateError);
      await Hive.close();
      await MyWorldHive.openBoxes(Hive);
      final reopened = HiveMyWorldIndexRepository(
        Hive.box(MyWorldHive.indexSnapshotsBoxName),
        Hive.box(MyWorldHive.indexMetadataBoxName),
      );
      expect(
        (await reopened.getActiveSnapshot()).generation,
        observed.generation,
      );
      expect((await reopened.getActiveSnapshot()).traces, hasLength(1));
    },
  );
  test(
    'queued tombstone rejects in-flight stale plan without changing pointer',
    () async {
      final index = HiveMyWorldIndexRepository(
        Hive.box(MyWorldHive.indexSnapshotsBoxName),
        Hive.box(MyWorldHive.indexMetadataBoxName),
      );
      final before = await index.getActiveSnapshot();
      final plan = const WorldIndexMutationPlanner().plan(
        current: before,
        challengerRoad: fixtures.fixture('race').roads.single,
        overlaps: [],
        now: fixtures.date,
      );
      final intent = LocalLifecycleJournal.traceIntent(
        plan.resultingSnapshot.traces.single,
      );
      final commit = index.commit(plan);
      await intent;
      await expectLater(commit, throwsStateError);
      expect((await index.getActiveSnapshot()).generation, before.generation);
    },
  );
}
