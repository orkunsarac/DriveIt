import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owned_gps_session_coordinator.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/scoped_gps_transfer_sink.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/drive_route_projection.dart';

void main() {
  late Directory root;
  late GpsSessionStore journal;
  late GpsOwnershipStore sidecar;
  late OwnerScopedLocalStore store;
  late OwnedGpsSessionCoordinator coordinator;
  final a = GpsOwner.account('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  final b = GpsOwner.account('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  late GpsOwner auth;
  bool failFlush = false;
  setUp(() async {
    sqfliteFfiInit();
    failFlush = false;
    root = await Directory.systemTemp.createTemp(
      'driveit_scoped_gps_synthetic_',
    );
    journal = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/gps.db',
    );
    sidecar = await GpsOwnershipStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/owner.db',
    );
    store = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: a,
      beforeFlush: (group) async {
        if (failFlush && group == 'drives') {
          throw StateError('synthetic Hive flush failure');
        }
      },
    );
    auth = a;
    coordinator = OwnedGpsSessionCoordinator(
      journal: journal,
      ownership: sidecar,
      journalId: 'synthetic-journal',
      ownerAtStart: () => auth,
    );
  });
  tearDown(() async {
    await sidecar.close();
    await journal.close();
    await store.close();
    await root.delete(recursive: true);
  });
  Map<String, dynamic> proposal(String id) => driveTransferManifest(
    DriveSession(
      id: id,
      date: DateTime.utc(2026),
      distance: 0,
      durationSeconds: 0,
      averageSpeed: 0,
      maxSpeed: 0,
      mapImagePath: '',
      route: [],
    ),
  );
  Future<ScopedGpsTransferSink> sink(String id) async => ScopedGpsTransferSink(
    store,
    (await sidecar.get('synthetic-journal', id))!,
  );
  DateTime getFuture() => DateTime.now().add(const Duration(days: 40));

  test(
    'session remains A after auth B; transfer retry and reopen keep exact destination',
    () async {
      final session = await coordinator.start();
      await journal.stop(session.id, expectedSequence: 0);
      auth = b;
      final target = await sink(session.id);
      await coordinator.save(session.id, proposal(session.id), target);
      await coordinator.save(session.id, proposal(session.id), target);
      expect(store.keys(a, 'drives'), [session.id]);
      await store.close();
      store = await OwnerScopedLocalStore.open(root: root.path, owner: a);
      expect(store.read<DriveSession>(a, 'drives', session.id)!.id, session.id);
      final other = await OwnerScopedLocalStore.open(root: root.path, owner: b);
      try {
        expect(other.keys(b, 'drives'), isEmpty);
        expect(
          () => ScopedGpsTransferSink(
            other,
            (GpsOwnershipManifest({
              'version': 1,
              'kind': 'account',
              'user_id': a.userId,
              'target_store': a.targetStore,
              'state': 'ready',
              'session_id': session.id,
            })),
          ),
          throwsStateError,
        );
      } finally {
        await other.close();
      }
    },
  );
  test('no sidecar/journal receipts means cleanup forbidden', () async {
    final session = await coordinator.start();
    await journal.stop(session.id, expectedSequence: 0);
    final target = await sink(session.id);
    expect(
      await target.cleanup(
        journal: journal,
        ownership: sidecar,
        journalId: 'synthetic-journal',
        now: getFuture(),
      ),
      false,
    );
    expect(await journal.session(session.id), isNotNull);
  });
  test(
    'journal receipt without sidecar receipt cannot clean up; retry repairs',
    () async {
      final session = await coordinator.start();
      await journal.stop(session.id, expectedSequence: 0);
      final target = await sink(session.id);
      final faulty = GpsOwnershipStore(
        sidecar.db,
        beforeCommit: (stage) async {
          if (stage == 'transfer_receipt') {
            throw StateError('synthetic receipt failure');
          }
        },
      );
      final c = OwnedGpsSessionCoordinator(
        journal: journal,
        ownership: faulty,
        journalId: 'synthetic-journal',
        ownerAtStart: () => b,
      );
      await expectLater(
        c.save(session.id, proposal(session.id), target),
        throwsStateError,
      );
      expect(await sidecar.verified('synthetic-journal', session.id), false);
      expect(
        await target.cleanup(
          journal: journal,
          ownership: sidecar,
          journalId: 'synthetic-journal',
          now: getFuture(),
        ),
        false,
      );
      await coordinator.save(session.id, proposal(session.id), target);
      expect(await sidecar.verified('synthetic-journal', session.id), true);
      expect(store.keys(a, 'drives'), [session.id]);
    },
  );
  test('fresh target integrity required even with both receipts', () async {
    final session = await coordinator.start();
    await journal.stop(session.id, expectedSequence: 0);
    final target = await sink(session.id);
    await coordinator.save(session.id, proposal(session.id), target);
    await store.remove(a, 'drives', session.id); // Synthetic fixture only.
    expect(
      await target.cleanup(
        journal: journal,
        ownership: sidecar,
        journalId: 'synthetic-journal',
        now: getFuture(),
      ),
      false,
    );
    expect(await journal.session(session.id), isNotNull);
  });
  test(
    'Hive flush failure retains source and retry cannot duplicate',
    () async {
      final session = await coordinator.start();
      await journal.stop(session.id, expectedSequence: 0);
      final target = await sink(session.id);
      failFlush = true;
      await expectLater(
        coordinator.save(session.id, proposal(session.id), target),
        throwsStateError,
      );
      expect(await sidecar.verified('synthetic-journal', session.id), false);
      expect(await journal.session(session.id), isNotNull);
      failFlush = false;
      await coordinator.save(session.id, proposal(session.id), target);
      expect(store.keys(a, 'drives'), [session.id]);
    },
  );
  test('unassigned old session cannot enter account transfer', () async {
    final session = await journal.create();
    await journal.stop(session.id, expectedSequence: 0);
    expect(
      (await sidecar.recoveryOwner('synthetic-journal', session.id)).kind,
      GpsOwnerKind.legacyUnassigned,
    );
    await expectLater(
      coordinator.save(
        session.id,
        proposal(session.id),
        ScopedGpsTransferSink(
          store,
          GpsOwnershipManifest({
            'version': 1,
            'kind': 'account',
            'user_id': a.userId,
            'target_store': a.targetStore,
            'state': 'ready',
            'session_id': session.id,
          }),
        ),
      ),
      throwsStateError,
    );
    expect(store.keys(a, 'drives'), isEmpty);
  });
  test(
    'nonempty sequence transfer preserves samples; cleanup only after both receipts',
    () async {
      final session = await coordinator.start();
      final points = [
        for (var i = 0; i < 2; i++)
          CanonicalTelemetryPoint(
            latitude: 40 + i * .0001,
            longitude: 29,
            timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
            speedMps: 10,
            headingDegrees: 0,
            altitudeMeters: 0,
            accuracyMeters: 5,
            distanceFromPreviousMeters: i == 0 ? 0 : 10,
            accelerationMps2: 0,
            speedSource: 'gps',
          ),
      ];
      for (var i = 0; i < points.length; i++) {
        await journal.append(session.id, i + 1, points[i]);
      }
      await journal.stop(session.id, expectedSequence: 2);
      final projection = DriveRouteProjection(points);
      final manifest = proposal(session.id)
        ..['route'] = projection.encodedRoute
        ..['distance'] = projection.distanceMeters;
      final target = await sink(session.id);
      await coordinator.save(session.id, manifest, target);
      await coordinator.save(session.id, manifest, target);
      expect((await target.readTelemetry(session.id))!.length, 2);
      expect(store.keys(a, 'drives'), [session.id]);
      expect((await journal.read(session.id)).map((p) => p.sequence), [1, 2]);
      final next = await coordinator.start();
      expect(
        await target.cleanup(
          journal: journal,
          ownership: sidecar,
          journalId: 'synthetic-journal',
          now: getFuture(),
        ),
        true,
      );
      expect(await journal.read(session.id), isEmpty);
      expect((await journal.active())!.id, next.id);
      expect((await target.readTelemetry(session.id))!.length, 2);
    },
  );
}
