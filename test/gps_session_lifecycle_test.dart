import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_session_transfer.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/services/gps_recording_writer.dart';
import 'package:driveit_project/services/canonical_telemetry_pipeline.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/services/gps_failure.dart';

CanonicalTelemetryPoint sample(int i) => CanonicalTelemetryPoint(
  latitude: 40 + i * .00001,
  longitude: 29,
  timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
  speedMps: 2,
  headingDegrees: 0,
  altitudeMeters: 0,
  accuracyMeters: 4,
  distanceFromPreviousMeters: i == 0 ? 0 : (i == 2 ? 0 : 1),
  accelerationMps2: 0,
  speedSource: 'native',
);

class FailSink extends GpsHiveTransferSink {
  bool failDrive = false;
  bool failTelemetry = false;
  bool loseResponse = false;
  @override
  Future<void> writeDrive(String id, Map<String, dynamic> manifest) async {
    if (failDrive) throw StateError('synthetic drive write failure');
    await super.writeDrive(id, manifest);
    if (loseResponse) {
      loseResponse = false;
      throw StateError('synthetic committed response lost');
    }
  }

  @override
  Future<void> writeTelemetry(
    String id,
    List<CanonicalTelemetryPoint> points,
    Map<String, dynamic> metadata,
  ) async {
    if (failTelemetry) throw StateError('synthetic telemetry failure');
    await super.writeTelemetry(id, points, metadata);
  }
}

class FullStore extends GpsSessionStore {
  FullStore(super.db);
  bool full = true;
  @override
  Future<int> append(
    String id,
    int sequence,
    CanonicalTelemetryPoint point, {
    Map<String, dynamic>? checkpoint,
  }) async {
    if (full) throw StateError('synthetic disk full');
    return super.append(id, sequence, point, checkpoint: checkpoint);
  }
}

void main() {
  late Directory root;
  late GpsSessionStore store;
  late GpsSession session;
  late Map<String, dynamic> manifest;
  late FailSink sink;
  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('driveit_phase4_synthetic_');
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DriveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RoutePointAdapter());
    DriveTelemetryHive.registerAdapters(Hive);
    await Hive.openBox<DriveSession>('drives');
    await DriveTelemetryHive.openBox(Hive);
    store = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/journal.db',
    );
    session = await store.create();
    for (var i = 0; i < 4; i++) {
      await store.append(session.id, i + 1, sample(i));
    }
    manifest = driveTransferManifest(
      DriveSession(
        id: session.id,
        date: DateTime.utc(2026),
        distance: 2,
        durationSeconds: 3,
        averageSpeed: 2.4,
        maxSpeed: 7.2,
        mapImagePath: '',
        route: [
          for (final i in [0, 1, 3])
            RoutePoint(
              latitude: sample(i).latitude,
              longitude: sample(i).longitude,
            ),
        ],
      ),
    );
    sink = FailSink();
  });
  tearDown(() async {
    await store.close();
    await Hive.close();
    await root.delete(recursive: true);
  });
  Future<void> stopped() => store.stop(session.id, expectedSequence: 4);
  Future<Map<String, dynamic>> save() =>
      GpsSessionTransfer(store, sink).save(session.id, manifest);

  test(
    'active, interrupted, pending-save, saving and verified lifecycle',
    () async {
      expect(
        await store.lifecycle(session.id, producerRunning: true),
        'ACTIVE',
      );
      expect(await store.lifecycle(session.id), 'RECOVERABLE');
      await stopped();
      expect(await store.lifecycle(session.id), 'PENDING_SAVE');
      sink.failDrive = true;
      await expectLater(save(), throwsStateError);
      expect(await store.lifecycle(session.id), 'SAVING');
      sink.failDrive = false;
      await save();
      expect(await store.lifecycle(session.id), 'VERIFIED');
      expect(await store.active(), isNull);
      expect((await store.read(session.id)).length, 4);
      expect(DriveTelemetryStorageService.get(session.id)!.points.length, 4);
      expect(Hive.box<DriveSession>('drives').get(session.id)!.route.length, 3);
    },
  );
  test('stopped without save survives database reopen', () async {
    await stopped();
    await store.close();
    store = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/journal.db',
    );
    expect(await store.lifecycle(session.id), 'PENDING_SAVE');
    await save();
  });
  test(
    'telemetry committed / drive failed is retried without deletion',
    () async {
      await stopped();
      sink.failDrive = true;
      await expectLater(save(), throwsStateError);
      final bytes = jsonEncode(
        DriveTelemetryStorageService.get(
          session.id,
        )!.points.map((p) => p.toMap()).toList(),
      );
      sink.failDrive = false;
      await save();
      expect(
        jsonEncode(
          DriveTelemetryStorageService.get(
            session.id,
          )!.points.map((p) => p.toMap()).toList(),
        ),
        bytes,
      );
      expect(Hive.box<DriveSession>('drives').length, 1);
    },
  );
  test('drive already written / telemetry missing is completed', () async {
    await stopped();
    await sink.writeDrive(session.id, manifest);
    sink.failTelemetry = true;
    await expectLater(save(), throwsStateError);
    expect((await store.session(session.id))!.state, 'stopped');
    sink.failTelemetry = false;
    await save();
    expect(await GpsSessionTransfer(store, sink).verify(session.id), true);
  });
  test(
    'double save and response lost do not duplicate or change date',
    () async {
      await stopped();
      sink.loseResponse = true;
      await expectLater(save(), throwsStateError);
      manifest['dateMicros'] = (manifest['dateMicros'] as int) + 999;
      final results = await Future.wait([save(), save()]);
      expect(
        results[0]['dateMicros'],
        DateTime.utc(2026).microsecondsSinceEpoch,
      );
      await save();
      expect(Hive.box<DriveSession>('drives').length, 1);
      expect(
        (await store.events(
          session.id,
        )).where((e) => e['kind'] == 'verified').length,
        1,
      );
    },
  );
  test('existing different drive or telemetry is never overwritten', () async {
    await stopped();
    final wrong = {...manifest, 'distance': 99.0};
    await sink.writeDrive(session.id, wrong);
    await expectLater(save(), throwsA(isA<GpsFailure>()));
    expect(Hive.box<DriveSession>('drives').get(session.id)!.distance, 99);
    expect((await store.read(session.id)).length, 4);
  });
  test('wrong session id and wrong final drain rejected', () async {
    await expectLater(save(), throwsA(isA<GpsFailure>()));
    await expectLater(
      store.stop(session.id, expectedSequence: 3),
      throwsA(isA<GpsFailure>()),
    );
    await stopped();
    final wrong = {...manifest, 'id': 'other'};
    await expectLater(
      GpsSessionTransfer(store, sink).save(session.id, wrong),
      throwsA(isA<GpsFailure>()),
    );
  });
  test(
    'cleanup denied active / pending / saving / legacy unverified',
    () async {
      final later = DateTime.now().add(const Duration(days: 100));
      expect(await store.maintenanceEligible(session.id, later), false);
      await stopped();
      expect(await store.maintenanceEligible(session.id, later), false);
      sink.failDrive = true;
      await expectLater(save(), throwsStateError);
      expect(await store.maintenanceEligible(session.id, later), false);
      await expectLater(
        store.removeVerifiedJournal(
          session.id,
          now: later,
          verifyHive: (_) => Future.value(true),
        ),
        throwsA(isA<GpsFailure>()),
      );
    },
  );
  test(
    '30-day retention boundary, fresh Hive verification, scoped cleanup',
    () async {
      await stopped();
      await save();
      final t = (await store.transferFor(session.id))!;
      final at = DateTime.fromMicrosecondsSinceEpoch(t['verified_us'] as int);
      expect(
        await store.maintenanceEligible(
          session.id,
          at
              .add(const Duration(days: 30))
              .subtract(const Duration(microseconds: 1)),
        ),
        false,
      );
      expect(
        await store.maintenanceEligible(
          session.id,
          at.add(const Duration(days: 30)),
        ),
        true,
      );
      final other = await store.create();
      await store.append(other.id, 1, sample(0));
      await expectLater(
        store.removeVerifiedJournal(
          session.id,
          now: at.add(const Duration(days: 30)),
          verifyHive: (_) => Future.value(false),
        ),
        throwsA(isA<GpsFailure>()),
      );
      await store.removeVerifiedJournal(
        session.id,
        now: at.add(const Duration(days: 30)),
        verifyHive: (_) => GpsSessionTransfer(store, sink).verify(session.id),
      );
      expect(await store.read(session.id), isEmpty);
      expect(await store.events(session.id), isEmpty);
      expect((await store.read(other.id)).length, 1);
      expect((await store.active())!.id, other.id);
      expect(await store.db.query('journal_maintenance'), hasLength(1));
      await expectLater(
        store.db.delete('points', where: 'session_id=?', whereArgs: [other.id]),
        throwsA(anything),
      );
    },
  );
  test(
    'maintenance transaction rollback leaves source and audit unchanged',
    () async {
      await stopped();
      await save();
      await store.db.execute(
        "CREATE TRIGGER synthetic_maintenance_failure BEFORE DELETE ON session_events BEGIN SELECT RAISE(ABORT,'synthetic rollback'); END",
      );
      await expectLater(
        store.removeVerifiedJournal(
          session.id,
          now: DateTime.now().add(const Duration(days: 31)),
          verifyHive: (_) => GpsSessionTransfer(store, sink).verify(session.id),
        ),
        throwsA(isA<GpsFailure>()),
      );
      expect((await store.read(session.id)).length, 4);
      expect(await store.db.query('journal_maintenance'), isEmpty);
    },
  );
  test('multiple completed and interrupted sessions stay isolated', () async {
    await stopped();
    await save();
    final other = await store.create();
    await store.append(other.id, 1, sample(0));
    await store.setError(other.id, 'GPS_DB_WRITE');
    expect(await store.lifecycle(other.id), 'RECOVERY_REQUIRED');
    expect((await store.recoverableSessions()).map((s) => s.id), [other.id]);
    expect(Hive.box<DriveSession>('drives').get(session.id), isNotNull);
  });
  test(
    'legacy saved without verification is never maintenance eligible',
    () async {
      await stopped();
      await store.acknowledgeSaved(session.id, session.id);
      expect(await store.lifecycle(session.id), 'RECOVERY_REQUIRED');
      expect(
        await store.maintenanceEligible(
          session.id,
          DateTime.now().add(const Duration(days: 100)),
        ),
        false,
      );
    },
  );
  test(
    'orphan and multiple pending sessions require explicit safe selection',
    () async {
      await stopped();
      await store.db.delete('current_session'); // named synthetic fixture only
      await expectLater(store.create(), throwsA(isA<GpsFailure>()));
      final other = GpsSession(
        'synthetic_orphan_2',
        DateTime.now(),
        'recording',
        null,
      );
      await store.db.insert('sessions', {
        'id': other.id,
        'started_us': other.startedAt.microsecondsSinceEpoch,
        'state': 'recording',
      });
      await store.selectRecovery(other.id);
      await store.append(other.id, 1, sample(0));
      await expectLater(
        store.selectRecovery(session.id),
        throwsA(isA<GpsFailure>()),
      );
      expect((await store.active())!.id, other.id);
      await store.stop(other.id, expectedSequence: 1);
      await store.selectRecovery(session.id);
      expect((await store.recoverableSessions()).length, 2);
      await save();
      expect((await store.recoverableSessions()).single.id, other.id);
      await store.selectRecovery(other.id);
      expect((await store.active())!.id, other.id);
    },
  );
  test(
    'bounded disk-full queue preserves admitted prefix, reports rejected samples',
    () async {
      final full = FullStore(store.db);
      var failures = 0;
      final writer = GpsRecordingWriter(
        full,
        session.id,
        onError: (failed) {
          if (failed) failures++;
        },
        maximumPendingSamples: 8,
        retryDelay: const Duration(milliseconds: 2),
      );
      await writer.restore();
      final admitted = <Future<void>>[];
      for (var i = 4; i < 12; i++) {
        admitted.add(
          writer.add(
            RawTelemetryInput(
              latitude: 40 + i * .00001,
              longitude: 29,
              timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
              speedMps: 2,
              headingDegrees: 0,
              altitudeMeters: 0,
              accuracyMeters: 4,
            ),
          ),
        );
      }
      for (var i = 0; i < 1000; i++) {
        await expectLater(
          writer.add(
            RawTelemetryInput(
              latitude: 40,
              longitude: 29,
              timestamp: DateTime.utc(2026).add(Duration(hours: 1, seconds: i)),
              speedMps: 0,
              headingDegrees: 0,
              altitudeMeters: 0,
              accuracyMeters: 4,
            ),
          ),
          throwsStateError,
        );
      }
      expect(writer.pendingSamples, 8);
      expect(writer.rejectedSamples, 1000);
      expect(failures, greaterThan(0));
      expect(writer.sequence, 4);
      full.full = false;
      await Future.wait(admitted);
      await writer.close();
      expect(writer.pendingSamples, 0);
      expect(writer.sequence, 12);
      expect((await store.read(session.id)).length, 12);
    },
  );
  test(
    'paged canonical reads preserve payload and all sequence boundaries',
    () async {
      for (var i = 4; i < 300; i++) {
        await store.append(
          session.id,
          i + 1,
          sample(i),
          checkpoint: {
            'syntheticRawWindow': List.filled(80, {'notUsedByUI': 1}),
          },
        );
      }
      final before = (await store.db.query(
        'points',
        where: 'session_id=?',
        whereArgs: [session.id],
        orderBy: 'sequence',
      )).map((r) => r['payload']).toList();
      final paged = await store.read(session.id, includeCheckpoints: false);
      expect(paged.length, 300);
      expect(paged.map((p) => p.sequence), List.generate(300, (i) => i + 1));
      expect(paged.every((p) => p.checkpoint == null), true);
      expect(
        (await store.last(session.id))!.checkpoint!['syntheticRawWindow'],
        hasLength(80),
      );
      expect(
        (await store.read(
          session.id,
          after: 128,
          includeCheckpoints: false,
        )).first.sequence,
        129,
      );
      final after = (await store.db.query(
        'points',
        where: 'session_id=?',
        whereArgs: [session.id],
        orderBy: 'sequence',
      )).map((r) => r['payload']).toList();
      expect(after, before);
    },
  );
  for (final phase in ['intent', 'telemetry', 'drive', 'verified']) {
    test(
      'real child process dies after $phase; journal/Hive recover exactly',
      () async {
        await stopped();
        await Hive.close();
        await store.close();
        final input = File('${root.path}/manifest.json');
        await input.writeAsString(jsonEncode(manifest));
        var folder = File(Platform.resolvedExecutable).parent;
        String? dart;
        for (var i = 0; i < 8; i++) {
          final candidate =
              '${folder.path}/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
          if (File(candidate).existsSync()) {
            dart = candidate;
            break;
          }
          folder = folder.parent;
        }
        expect(dart, isNotNull);
        final process = await Process.run(dart!, [
          'run',
          'test/support/gps_transfer_crash_probe.dart',
          root.path,
          session.id,
          phase,
        ], workingDirectory: Directory.current.path);
        expect(process.exitCode, 73, reason: '${process.stderr}');
        store = await GpsSessionStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: '${root.path}/journal.db',
        );
        await Hive.openBox<DriveSession>('drives');
        await DriveTelemetryHive.openBox(Hive);
        expect((await store.read(session.id)).length, 4);
        await save();
        expect(await store.lifecycle(session.id), 'VERIFIED');
        expect(Hive.box<DriveSession>('drives').length, 1);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
