import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owned_gps_session_coordinator.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_failure.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/gps_session_transfer.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class FakeAuth {
  GpsOwner owner = const GpsOwner.guest();
}

class ScopedSink implements OwnedGpsTransferSink, ProvenanceGpsTransferSink {
  ScopedSink(this.targetStore);
  @override
  final String targetStore;
  Map<String, dynamic>? drive;
  List<CanonicalTelemetryPoint>? points;
  int writes = 0;
  bool failFlush = false;
  String? sourceIdentity;
  @override
  Future<String?> readSourceIdentity(String id) async => sourceIdentity;
  @override
  Future<void> persistSourceIdentity(String id, String value) async {
    if (sourceIdentity != null && sourceIdentity != value) {
      throw StateError('synthetic source identity conflict');
    }
    sourceIdentity = value;
  }
  @override
  Future<Map<String, dynamic>?> readDrive(String id) async => drive;
  @override
  Future<List<CanonicalTelemetryPoint>?> readTelemetry(String id) async =>
      points;
  @override
  Future<void> writeDrive(String id, Map<String, dynamic> value) async {
    writes++;
    drive = value;
  }

  @override
  Future<void> writeTelemetry(
    String id,
    List<CanonicalTelemetryPoint> value,
    Map<String, dynamic> metadata,
  ) async {
    writes++;
    points = value;
    sourceIdentity = metadata['sourceIdentity'] as String?;
  }

  @override
  Future<void> flush() async {
    if (failFlush) throw StateError('synthetic sink durability failure');
  }
}

void main() {
  late Directory root;
  late GpsSessionStore journal;
  late GpsOwnershipStore sidecar;
  late FakeAuth auth;
  late OwnedGpsSessionCoordinator coordinator;
  OwnedGpsSessionCoordinator createCoordinator(GpsOwnershipStore store) =>
      OwnedGpsSessionCoordinator(
        journal: journal,
        ownership: store,
        journalId: 'local-journal-v1',
        ownerAtStart: () => auth.owner,
      );
  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp(
      'driveit_ownership_synthetic_',
    );
    journal = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/gps.db',
    );
    sidecar = await GpsOwnershipStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/owners.db',
    );
    auth = FakeAuth();
    coordinator = createCoordinator(sidecar);
  });
  tearDown(() async {
    await sidecar.close();
    await journal.close();
    await root.delete(recursive: true);
  });
  Map<String, dynamic> proposal(GpsSession session) => {
    'id': session.id,
    'route': <dynamic>[],
    'distance': 0.0,
  };
  Future<void> stop(GpsSession session) =>
      journal.stop(session.id, expectedSequence: 0);

  test('guest pinned at start', () async {
    final s = await coordinator.start();
    final binding = (await sidecar.get('local-journal-v1', s.id))!;
    expect(binding.provenance.isProven, isTrue);
    expect(binding.provenance.sourceIdentity, matches(RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    )));
    expect(
      binding.owner.kind,
      GpsOwnerKind.guest,
    );
    auth.owner = GpsOwner.account(a);
    expect(
      (await sidecar.recoveryOwner('local-journal-v1', s.id)).kind,
      GpsOwnerKind.guest,
    );
  });
  test(
    'account UUID pinned across logout and B login, B sink rejected',
    () async {
      auth.owner = GpsOwner.account(a);
      final s = await coordinator.start();
      auth.owner = const GpsOwner.guest();
      expect((await sidecar.recoveryOwner('local-journal-v1', s.id)).userId, a);
      auth.owner = GpsOwner.account(b);
      await stop(s);
      final wrong = ScopedSink(auth.owner.targetStore);
      await expectLater(
        coordinator.save(s.id, proposal(s), wrong),
        throwsStateError,
      );
      expect(wrong.writes, 0);
      expect((await journal.session(s.id))!.state, 'stopped');
      final correct = ScopedSink(GpsOwner.account(a).targetStore);
      await coordinator.save(s.id, proposal(s), correct);
      expect(await sidecar.verified('local-journal-v1', s.id), true);
    },
  );
  test(
    'reopen both files retains original account, not current auth',
    () async {
      auth.owner = GpsOwner.account(a);
      final s = await coordinator.start();
      final sourceIdentity =
          (await sidecar.get('local-journal-v1', s.id))!
              .provenance.sourceIdentity;
      await sidecar.close();
      await journal.close();
      journal = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/gps.db',
      );
      sidecar = await GpsOwnershipStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/owners.db',
      );
      auth.owner = GpsOwner.account(b);
      expect((await journal.active())!.id, s.id);
      final recovered = (await sidecar.get('local-journal-v1', s.id))!;
      expect(recovered.owner.userId, a);
      expect(recovered.provenance.sourceIdentity, sourceIdentity);
    },
  );
  test('ownership commit/flush failure prevents journal creation', () async {
    final faulty = GpsOwnershipStore(
      sidecar.db,
      beforeCommit: (stage) async {
        throw StateError('synthetic commit failure');
      },
    );
    await expectLater(createCoordinator(faulty).start(), throwsStateError);
    expect(await journal.active(), null);
    expect(await sidecar.db.query('ownership'), isEmpty);
  });
  test(
    'binding commit failure retains session, cannot infer account on recovery',
    () async {
      auth.owner = GpsOwner.account(a);
      final faulty = GpsOwnershipStore(
        sidecar.db,
        beforeCommit: (stage) async {
          if (stage == 'ownership_bind') {
            throw StateError('synthetic bind failure');
          }
        },
      );
      await expectLater(createCoordinator(faulty).start(), throwsStateError);
      final s = (await journal.active())!;
      auth.owner = GpsOwner.account(b);
      expect(
        (await sidecar.recoveryOwner('local-journal-v1', s.id)).kind,
        GpsOwnerKind.legacyUnassigned,
      );
      await stop(s);
      await expectLater(
        createCoordinator(
          sidecar,
        ).save(s.id, proposal(s), ScopedSink(auth.owner.targetStore)),
        throwsStateError,
      );
      expect((await sidecar.db.query('ownership')).single['state'], 'prepared');
    },
  );
  test(
    'prepared reservation before journal creation never adopts unrelated session',
    () async {
      await sidecar.prepare('local-journal-v1', GpsOwner.account(a));
      final old = await journal.create();
      auth.owner = GpsOwner.account(b);
      expect(
        (await sidecar.recoveryOwner('local-journal-v1', old.id)).kind,
        GpsOwnerKind.legacyUnassigned,
      );
    },
  );
  test('planned identity recovers crash between journal create and sidecar bind', () async {
    const sessionId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    final pending = await sidecar.prepare(
      'local-journal-v1',
      GpsOwner.account(a),
      plannedSessionId: sessionId,
    );
    final sourceIdentity = pending.provenance.sourceIdentity;
    final session = await journal.create(id: sessionId);
    expect(session.id, sessionId);
    await sidecar.close();
    sidecar = await GpsOwnershipStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/owners.db',
    );
    final recovered = await sidecar.recoverBinding(
      'local-journal-v1',
      sessionId,
      journalSessionExists: await journal.session(sessionId) != null,
    );
    expect(recovered?.state, 'ready');
    expect(recovered?.provenance.sourceIdentity, sourceIdentity);
    expect(recovered?.owner.userId, a);
  });
  test(
    'journal creation failure preserves unbound reservation without rebinding old session',
    () async {
      final old = await journal.create();
      auth.owner = GpsOwner.account(a);
      await expectLater(coordinator.start(), throwsA(isA<GpsFailure>()));
      expect((await journal.active())!.id, old.id);
      expect(
        (await sidecar.recoveryOwner('local-journal-v1', old.id)).kind,
        GpsOwnerKind.legacyUnassigned,
      );
    },
  );
  test('same session identity cannot bind to another owner', () async {
    final first = await sidecar.prepare(
      'local-journal-v1',
      GpsOwner.account(a),
    );
    final second = await sidecar.prepare(
      'local-journal-v1',
      GpsOwner.account(b),
    );
    await sidecar.bind(first.reservationId, 'synthetic-same-id');
    await expectLater(
      sidecar.bind(second.reservationId, 'synthetic-same-id'),
      throwsA(isA<Exception>()),
    );
    expect(
      (await sidecar.recoveryOwner(
        'local-journal-v1',
        'synthetic-same-id',
      )).userId,
      a,
    );
    expect(
      GpsOwner.account(a).recordKey('same'),
      isNot(GpsOwner.account(b).recordKey('same')),
    );
  });
  test('same session ID in different journals remains unambiguous', () async {
    final x = await sidecar.prepare('journal-a', GpsOwner.account(a));
    final y = await sidecar.prepare('journal-b', GpsOwner.account(b));
    await sidecar.bind(x.reservationId, 'same');
    await sidecar.bind(y.reservationId, 'same');
    expect((await sidecar.recoveryOwner('journal-a', 'same')).userId, a);
    expect((await sidecar.recoveryOwner('journal-b', 'same')).userId, b);
  });
  test(
    'transfer intent durable reopen (exception interruption, not process kill)',
    () async {
      auth.owner = GpsOwner.account(a);
      final s = await coordinator.start();
      await stop(s);
      final manifest = (await sidecar.get('local-journal-v1', s.id))!;
      await sidecar.beginTransfer(manifest, manifest.targetStore);
      await sidecar.close();
      sidecar = await GpsOwnershipStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/owners.db',
      );
      auth.owner = GpsOwner.account(b);
      final sink = ScopedSink(manifest.targetStore);
      await createCoordinator(sidecar).save(s.id, proposal(s), sink);
      expect((await sidecar.db.query('transfers')).length, 1);
      expect(await sidecar.verified('local-journal-v1', s.id), true);
    },
  );
  test(
    'receipt transaction failure remains retryable after journal verification',
    () async {
      final s = await coordinator.start();
      await stop(s);
      final sink = ScopedSink(const GpsOwner.guest().targetStore);
      final faulty = GpsOwnershipStore(
        sidecar.db,
        beforeCommit: (stage) async {
          if (stage == 'transfer_receipt') {
            throw StateError('synthetic receipt failure');
          }
        },
      );
      await expectLater(
        createCoordinator(faulty).save(s.id, proposal(s), sink),
        throwsStateError,
      );
      expect((await sidecar.db.query('transfers')).single['state'], 'intent');
      expect(await journal.session(s.id), isNotNull);
      expect((await journal.transferFor(s.id))!['verified_us'], isNotNull);
      await coordinator.save(s.id, proposal(s), sink);
      expect(sink.writes, 2);
      expect(await sidecar.verified('local-journal-v1', s.id), true);
    },
  );
  test(
    'repeat and concurrent transfer produce one receipt and no duplicate sink writes',
    () async {
      final s = await coordinator.start();
      await stop(s);
      final sink = ScopedSink(const GpsOwner.guest().targetStore);
      await Future.wait([
        coordinator.save(s.id, proposal(s), sink),
        coordinator.save(s.id, proposal(s), sink),
      ]);
      await coordinator.save(s.id, proposal(s), sink);
      expect(sink.writes, 2);
      expect((await sidecar.db.query('transfers')).length, 1);
    },
  );
  test(
    'sink flush failure retains journal and immutable intent, retry verifies',
    () async {
      final s = await coordinator.start();
      await stop(s);
      final sink = ScopedSink(const GpsOwner.guest().targetStore)
        ..failFlush = true;
      await expectLater(
        coordinator.save(s.id, proposal(s), sink),
        throwsStateError,
      );
      expect(await sidecar.verified('local-journal-v1', s.id), false);
      expect((await journal.session(s.id))!.state, 'stopped');
      sink.failFlush = false;
      await coordinator.save(s.id, proposal(s), sink);
      expect(sink.writes, 2);
    },
  );
  test(
    'legacy session and old transfer receipt are untouched; scoped transfer denied',
    () async {
      final s = await journal.create();
      await stop(s);
      await journal.beginTransfer(s.id, s.id, '{"id":"legacy"}');
      final old = await journal.transferFor(s.id);
      auth.owner = GpsOwner.account(a);
      final sink = ScopedSink(auth.owner.targetStore);
      await expectLater(
        coordinator.save(s.id, proposal(s), sink),
        throwsStateError,
      );
      expect(await journal.transferFor(s.id), old);
      expect(sink.writes, 0);
      expect(
        (await sidecar.recoveryOwner('local-journal-v1', s.id)).kind,
        GpsOwnerKind.legacyUnassigned,
      );
    },
  );
  test('journal points survive ownership failure and auth switch', () async {
    auth.owner = GpsOwner.account(a);
    final s = await coordinator.start();
    final p = CanonicalTelemetryPoint(
      latitude: 40,
      longitude: 29,
      timestamp: DateTime.utc(2026),
      speedMps: 0,
      headingDegrees: 0,
      altitudeMeters: 0,
      accuracyMeters: 5,
      distanceFromPreviousMeters: 0,
      accelerationMps2: 0,
    );
    await journal.append(s.id, 1, p);
    auth.owner = GpsOwner.account(b);
    final rows = await journal.read(s.id);
    expect(rows.length, 1);
    expect(rows.single.sequence, 1);
    expect((await sidecar.recoveryOwner('local-journal-v1', s.id)).userId, a);
  });
  test('immutable storage denies owner update and evidence deletion', () async {
    final s = await coordinator.start();
    await expectLater(
      sidecar.db.update(
        'ownership',
        {'user_id': a, 'kind': 'account'},
        where: 'session_id=?',
        whereArgs: [s.id],
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      sidecar.db.delete('ownership'),
      throwsA(isA<Exception>()),
    );
  });
  test('account UUID validation and unknown schema fail closed', () async {
    expect(() => GpsOwner.account('display-name'), throwsArgumentError);
    expect(() => GpsOwnershipManifest({'version': 99}), throwsStateError);
  });

  test('same source identity survives ownership transfer without regeneration', () async {
    auth.owner = GpsOwner.account(a);
    final session = await coordinator.start();
    final before = (await sidecar.get('local-journal-v1', session.id))!;
    final sourceIdentity = before.provenance.sourceIdentity;
    await stop(session);
    final sink = ScopedSink(before.targetStore);
    await coordinator.save(session.id, proposal(session), sink);
    expect(sink.sourceIdentity, sourceIdentity);
    expect(
      (await sidecar.get('local-journal-v1', session.id))!
          .provenance.sourceIdentity,
      sourceIdentity,
    );
  });

  test('schema v1 reservations upgrade as unproven and are not rewritten', () async {
    final legacyPath = '${root.path}/owners_v1.db';
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE ownership (
            reservation_id TEXT PRIMARY KEY, version INTEGER NOT NULL CHECK(version=1),
            journal_id TEXT NOT NULL, session_id TEXT,
            kind TEXT NOT NULL, user_id TEXT, target_store TEXT NOT NULL,
            state TEXT NOT NULL, created_us INTEGER NOT NULL, updated_us INTEGER NOT NULL,
            UNIQUE(journal_id,session_id))''');
          await db.execute('''CREATE TABLE transfers (
            operation_id TEXT PRIMARY KEY, journal_id TEXT NOT NULL, session_id TEXT NOT NULL,
            target_store TEXT NOT NULL, state TEXT NOT NULL,
            created_us INTEGER NOT NULL, verified_us INTEGER,
            UNIQUE(journal_id,session_id))''');
          await db.insert('ownership', {
            'reservation_id': 'legacy-reservation',
            'version': 1,
            'journal_id': 'local-journal-v1',
            'session_id': 'old-session',
            'kind': 'guest',
            'target_store': const GpsOwner.guest().targetStore,
            'state': 'ready',
            'created_us': 1,
            'updated_us': 1,
          });
        },
      ),
    );
    await db.close();
    final upgraded = await GpsOwnershipStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: legacyPath,
    );
    final manifest = (await upgraded.get('local-journal-v1', 'old-session'))!;
    expect(manifest.provenance.status, DriveProvenanceStatus.unproven);
    expect(manifest.provenance.sourceIdentity, isNull);
    expect((await upgraded.db.query('ownership')).single['reservation_id'],
        'legacy-reservation');
    await upgraded.close();
  });
  test(
    'real child exits after sidecar intent; reopen preserves destination',
    () async {
      auth.owner = GpsOwner.account(a);
      final s = await coordinator.start();
      await stop(s);
      await sidecar.close();
      var dir = File(Platform.resolvedExecutable).parent;
      String? dart;
      while (true) {
        final candidate = File(
          '${dir.path}/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
        );
        if (candidate.existsSync()) {
          dart = candidate.path;
          break;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      expect(dart, isNotNull);
      final result = await Process.run(dart!, [
        'run',
        'test/support/gps_ownership_exit_probe.dart',
        '${root.path}/owners.db',
        s.id,
      ]);
      sidecar = await GpsOwnershipStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/owners.db',
      );
      expect(result.exitCode, 73, reason: result.stderr.toString());
      auth.owner = GpsOwner.account(b);
      final manifest = (await sidecar.get('local-journal-v1', s.id))!;
      expect(manifest.owner.userId, a);
      expect((await sidecar.db.query('transfers')).single['state'], 'intent');
      final sink = ScopedSink(manifest.targetStore);
      await createCoordinator(sidecar).save(s.id, proposal(s), sink);
      expect(sink.writes, 2);
      expect(await sidecar.verified('local-journal-v1', s.id), true);
    },
  );
}
