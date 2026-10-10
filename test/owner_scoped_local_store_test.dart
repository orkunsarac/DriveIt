import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/legacy_owner_preparation.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/features/my_world/models/world_index_mutation_plan.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment.dart';
import 'planet_segment_test.dart' as segment_fixtures;

const aId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const bId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

DriveSession drive(String id) => DriveSession(
  id: id,
  date: DateTime.utc(2026),
  distance: 5000,
  durationSeconds: 1000,
  averageSpeed: 18,
  maxSpeed: 40,
  mapImagePath: 'synthetic-only.png',
  route: [
    RoutePoint(latitude: 40, longitude: 29),
    RoutePoint(latitude: 40.01, longitude: 29.01, breakBefore: true),
  ],
);

void main() {
  late Directory root;
  late OwnerScopedLocalStore a, b, guest, legacy;
  final ownerA = GpsOwner.account(aId);
  final ownerB = GpsOwner.account(bId);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_scoped_synthetic_');
    a = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
    b = await OwnerScopedLocalStore.open(root: root.path, owner: ownerB);
    guest = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: const GpsOwner.guest(),
    );
    legacy = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: const GpsOwner.legacy(),
    );
  });
  tearDown(() async {
    for (final store in [a, b, guest, legacy]) {
      await store.close();
    }
    await root.delete(recursive: true);
  });

  test(
    'four namespaces retain same drive ID independently and on reopen',
    () async {
      for (final s in [a, b, guest, legacy]) {
        await s.put(s.owner, 'drives', 'same', drive('same'));
        await s.put(s.owner, 'drive_names', 'same', s.scope);
      }
      expect({a.path, b.path, guest.path, legacy.path}.length, 4);
      await a.close();
      a = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
      expect(a.read(ownerA, 'drive_names', 'same'), ownerA.targetStore);
      expect(b.read(ownerB, 'drive_names', 'same'), ownerB.targetStore);
      expect(
        a.read<DriveSession>(ownerA, 'drives', 'same')!.route.last.breakBefore,
        true,
      );
    },
  );
  test(
    'explicit wrong context cannot read/write/delete another store',
    () async {
      expect(() => a.read(ownerB, 'drives', 'same'), throwsStateError);
      await expectLater(
        a.put(ownerB, 'profile', 'name', 'B'),
        throwsStateError,
      );
      await expectLater(a.remove(ownerB, 'drives', 'same'), throwsStateError);
      expect(() => a.repositories(ownerB), throwsStateError);
      expect(() => a.worldIndex(ownerB), throwsStateError);
    },
  );
  for (final group in OwnerScopedLocalStore.groups.where(
    (g) => ![
      'drives',
      'drive_telemetry',
      'drive_scores',
      'my_world_validated_roads',
      'my_world_processing',
      'my_world_pending_jobs',
      'my_world_index_snapshots',
      'my_world_index_metadata',
    ].contains(g),
  )) {
    test('$group duplicate identity isolated', () async {
      await a.put(ownerA, group, 'same', {'owner': 'A', 'v': 1});
      await b.put(ownerB, group, 'same', {'owner': 'B', 'v': 2});
      expect(a.read<Map>(ownerA, group, 'same')!['owner'], 'A');
      expect(b.read<Map>(ownerB, group, 'same')!['owner'], 'B');
      expect(guest.read(guest.owner, group, 'same'), isNull);
      final detached = a.read<Map>(ownerA, group, 'same')!;
      detached['owner'] = 'B';
      expect(a.read<Map>(ownerA, group, 'same')!['owner'], 'A');
    });
  }
  test('owner epoch drops async A completion after A-B-A switch', () async {
    final barrier = OwnerViewBarrier(ownerA);
    final pending = Completer<String>();
    final result = barrier.load('world', (o) {
      expect(o.userId, aId);
      return pending.future;
    });
    barrier.switchTo(ownerB);
    barrier.switchTo(ownerA);
    pending.complete('old A');
    expect(await result, isNull);
    expect(await barrier.load('world', (_) async => 'new A'), 'new A');
    barrier.switchTo(ownerB);
    expect(await barrier.load('world', (_) async => 'B'), 'B');
    barrier.switchTo(ownerA);
    expect(await barrier.load('world', (_) async => 'unexpected'), 'new A');
  });
  test(
    'scoped world pointer and commit use own lifecycle not global Hive',
    () async {
      final repo = a.worldIndex(ownerA);
      final initial = await repo.getActiveSnapshot();
      final next = initial.copyWith(
        generation: 1,
        operationId: 'synthetic',
        processedDriveSessionIds: ['same'],
      );
      await repo.commit(
        WorldIndexMutationPlan(
          operationId: 'synthetic',
          sourceDriveSessionId: 'same',
          baseGeneration: 0,
          tracesToRemove: [],
          tracesToCreate: [],
          resultingSnapshot: next,
        ),
      );
      expect((await repo.getActiveSnapshot()).generation, 1);
      expect((await b.worldIndex(ownerB).getActiveSnapshot()).generation, 0);
      await expectLater(
        repo.commit(
          WorldIndexMutationPlan(
            operationId: 'stale',
            sourceDriveSessionId: 'same',
            baseGeneration: 0,
            tracesToRemove: [],
            tracesToCreate: [],
            resultingSnapshot: next,
          ),
        ),
        throwsStateError,
      );
      await ScopedLifecycle(a).tombstone('world', 'same');
      expect(b.read(ownerB, 'local_lifecycle_v1', 'world:same'), isNull);
    },
  );
  test(
    'source/career repositories reject foreign owner and rebuild only own source',
    () async {
      final ra = a.repositories(ownerA);
      final source = LocalSourceBundle(
        drive: drive('same'),
        ownerScope: a.scope,
      );
      await ra.prepareSource(source);
      await ra.contribute(source);
      expect(ra.rebuildSources().single.drive.id, 'same');
      expect(b.repositories(ownerB).rebuildSources(), isEmpty);
      expect(b.keys(ownerB, 'career_contributions_v1'), isEmpty);
      await expectLater(
        b.repositories(ownerB).prepareSource(source),
        throwsStateError,
      );
      await expectLater(
        b.repositories(ownerB).contribute(source),
        throwsStateError,
      );
      await ScopedLifecycle(a).tombstone('world', 'same');
      expect(ra.rebuildSources(), isEmpty);
      expect(ra.acceptedDistance, 0);
      await expectLater(ra.deliverSegment('same', ownerB), throwsStateError);
    },
  );

  test(
    'old owner async error cannot surface in new view; current error propagates',
    () async {
      final barrier = OwnerViewBarrier(ownerA);
      final pending = Completer<String>();
      final result = barrier.load('old-failure', (_) => pending.future);
      barrier.switchTo(ownerB);
      pending.completeError(StateError('synthetic old A error'));
      expect(await result, isNull);
      await expectLater(
        barrier.load<String>('current-failure', (_) async {
          throw StateError('synthetic current B error');
        }),
        throwsStateError,
      );
    },
  );
  group('read-only legacy preparation', () {
    late HiveImpl old;
    setUp(() async {
      final dir = await Directory('${root.path}/synthetic_legacy').create();
      old = HiveImpl()..init(dir.path);
      OwnerScopedLocalStore.register(old);
      await old.openBox<DriveSession>('drives');
      await old.openBox<dynamic>('drive_names');
      await old.box<DriveSession>('drives').put('old', drive('old'));
      await old.box<dynamic>('drive_names').put('old', 'Original title');
      await old.box<DriveSession>('drives').flush();
      await old.box<dynamic>('drive_names').flush();
    });
    tearDown(() => old.close());
    Future<LegacyLocalInventory> inventory() async =>
        LegacyLocalInventory.capture(old, ['drives', 'drive_names']);
    test(
      'copies all adapter fields without source change and retry duplicates',
      () async {
        final before = (await inventory()).fingerprint;
        final prepare = LegacyOwnerPreparation(legacy);
        await prepare.prepare(sourceId: 'synthetic', readSource: inventory);
        await prepare.prepare(sourceId: 'synthetic', readSource: inventory);
        expect((await inventory()).fingerprint, before);
        expect(legacy.keys(legacy.owner, 'drives'), ['old']);
        expect(
          legacy
              .read<DriveSession>(legacy.owner, 'drives', 'old')!
              .mapImagePath,
          'synthetic-only.png',
        );
        expect(a.keys(ownerA, 'drives'), isEmpty);
        await legacy.close();
        legacy = await OwnerScopedLocalStore.open(
          root: root.path,
          owner: const GpsOwner.legacy(),
        );
        expect(
          legacy
              .read<DriveSession>(legacy.owner, 'drives', 'old')!
              .route
              .last
              .breakBefore,
          true,
        );
      },
    );
    for (final stage in [
      'intent_flushed',
      'record_flushed',
      'all_flushed',
      'verified',
    ]) {
      test(
        'interruption $stage keeps source and reopens without duplicates',
        () async {
          final before = (await inventory()).fingerprint;
          await expectLater(
            LegacyOwnerPreparation(
              legacy,
              boundary: (s) async {
                if (s == stage) {
                  throw StateError('synthetic interrupted acknowledgement');
                }
              },
            ).prepare(sourceId: 'synthetic', readSource: inventory),
            throwsStateError,
          );
          await legacy.close();
          legacy = await OwnerScopedLocalStore.open(
            root: root.path,
            owner: const GpsOwner.legacy(),
          );
          await LegacyOwnerPreparation(
            legacy,
          ).prepare(sourceId: 'synthetic', readSource: inventory);
          expect((await inventory()).fingerprint, before);
          expect(legacy.keys(legacy.owner, 'drives'), ['old']);
        },
      );
    }
    test('unknown ownership never assigned to account or guest', () async {
      for (final target in [a, guest]) {
        await expectLater(
          LegacyOwnerPreparation(
            target,
          ).prepare(sourceId: 'synthetic', readSource: inventory),
          throwsStateError,
        );
        expect(target.keys(target.owner, 'drives'), isEmpty);
      }
    });
    test(
      'conflicting target preserved; source mutation fails closed',
      () async {
        await legacy.put(legacy.owner, 'drive_names', 'old', 'conflict');
        await expectLater(
          LegacyOwnerPreparation(
            legacy,
          ).prepare(sourceId: 'synthetic', readSource: inventory),
          throwsStateError,
        );
        expect(legacy.read(legacy.owner, 'drive_names', 'old'), 'conflict');
        expect(old.box<dynamic>('drive_names').get('old'), 'Original title');
      },
    );
    test('source changes during copy cannot be marked verified', () async {
      await expectLater(
        LegacyOwnerPreparation(
          legacy,
          boundary: (s) async {
            if (s == 'all_flushed') {
              await old
                  .box<dynamic>('drive_names')
                  .put('old', 'concurrent source change');
            }
          },
        ).prepare(sourceId: 'synthetic', readSource: inventory),
        throwsStateError,
      );
    });
    test(
      'unknown source box requires review rather than silently dropping data',
      () async {
        await old.openBox<dynamic>('unrecognized_personal_box');
        expect(
          () =>
              LegacyLocalInventory.capture(old, ['unrecognized_personal_box']),
          throwsStateError,
        );
      },
    );
    test(
      'target flush fault preserves source and retry reestablishes durability',
      () async {
        await legacy.close();
        bool fail = true;
        legacy = await OwnerScopedLocalStore.open(
          root: root.path,
          owner: const GpsOwner.legacy(),
          beforeFlush: (group) async {
            if (fail && group == 'drive_names') {
              throw StateError('synthetic flush exception');
            }
          },
        );
        final before = (await inventory()).fingerprint;
        await expectLater(
          LegacyOwnerPreparation(
            legacy,
          ).prepare(sourceId: 'synthetic', readSource: inventory),
          throwsStateError,
        );
        expect((await inventory()).fingerprint, before);
        fail = false;
        await LegacyOwnerPreparation(
          legacy,
        ).prepare(sourceId: 'synthetic', readSource: inventory);
        expect(legacy.keys(legacy.owner, 'drives'), ['old']);
      },
    );
    test(
      'parallel duplicate preparations serialize without activating quarantine',
      () async {
        final prepare = LegacyOwnerPreparation(legacy);
        await Future.wait(
          List.generate(
            3,
            (_) =>
                prepare.prepare(sourceId: 'synthetic', readSource: inventory),
          ),
        );
        expect(legacy.keys(legacy.owner, 'drives'), ['old']);
        await expectLater(legacy.manifest('identity', {}), throwsArgumentError);
      },
    );
  });
  test('same pending job ID belongs to separate frozen scopes', () async {
    final job = WorldPendingJob.pending(
      driveSessionId: 'same',
      type: WorldJobType.validateRoad,
      now: DateTime.utc(2026),
    );
    await a.put(ownerA, 'my_world_pending_jobs', job.id, job);
    await b.put(ownerB, 'my_world_pending_jobs', job.id, job);
    await ScopedLifecycle(a).tombstone('world', 'same');
    expect(
      b.read<WorldPendingJob>(ownerB, 'my_world_pending_jobs', job.id)!.status,
      WorldJobStatus.pending,
    );
    expect(b.read(ownerB, 'local_lifecycle_v1', 'world:same'), isNull);
  });
  test(
    'same Planet segment ID stays stable pending and owner isolated',
    () async {
      final segments = const PlanetSegmentBuilder()
          .build('drive', segment_fixtures.fixture([8000]))
          .segments;
      final ra = a.repositories(ownerA), rb = b.repositories(ownerB);
      await ra.prepareSegments(segments);
      await ra.prepareSegments(segments);
      expect(ra.segments('drive').length, 1);
      expect(rb.segments('drive'), isEmpty);
      await rb.prepareSegments(segments);
      expect(
        rb.segments('drive').single['payload'],
        ra.segments('drive').single['payload'],
      );
      await ra.deliverSegment(segments.single.id, ownerA);
      expect(ra.acceptedDistance, 0);
      expect(rb.acceptedDistance, 0);
      expect(ra.segments('drive').single['state'], isNot('accepted'));
    },
  );
  test(
    'independent History deletion leaves scoped Career World and B intact',
    () async {
      final source = LocalSourceBundle(
        drive: drive('same'),
        ownerScope: a.scope,
      );
      final ra = a.repositories(ownerA);
      await a.put(ownerA, 'drives', 'same', source.drive);
      await b.put(ownerB, 'drives', 'same', drive('same'));
      await expectLater(ra.deleteHistory('same'), throwsStateError);
      expect(a.read(ownerA, 'drives', 'same'), isNotNull);
      await ra.prepareSource(source);
      expect(
        await ra.prepareCareerBaseline(
          [source],
          {
            'countedIds': ['same'],
            'totalDistance': 5000.0,
            'totalDuration': 1000,
          },
        ),
        true,
      );
      expect(ra.careerStatistics()!.totalDistanceMeters, 5000);
      await ra.deleteHistory('same');
      await ra.deleteHistory('same');
      expect(a.read(ownerA, 'drives', 'same'), isNull);
      expect(ra.source('same'), isNotNull);
      expect(ra.careerStatistics()!.totalDistanceMeters, 5000);
      expect(b.read(ownerB, 'drives', 'same'), isNotNull);
      expect(b.read(ownerB, 'local_lifecycle_v1', 'history:same'), isNull);
    },
  );
}
