import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/gps_session_transfer.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_recording_writer.dart';
import 'package:driveit_project/services/canonical_telemetry_pipeline.dart';
import 'package:driveit_project/services/drive_recovery_status.dart';
import 'package:driveit_project/services/drive_route_projection.dart';
import 'package:driveit_project/services/drive_time_analysis.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';

@pragma('vm:entry-point')
void gpsProbeCallback() =>
    FlutterForegroundTask.setTaskHandler(NativeGpsProbeTask());

/// Uses the same native headless FlutterEngine, but only a named synthetic DB.
/// Never calls DriveIt's production task callback or main/Hive bootstrap.
class NativeGpsProbeTask extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    GpsSessionStore? store;
    try {
      final path =
          await FlutterForegroundTask.getData(key: 'gps_native_probe_path')
              as String;
      store = await GpsSessionStore.open(factory: databaseFactory, path: path);
      final session = (await store.active())!;
      final writer = GpsRecordingWriter(
        store,
        session.id,
        onError: (failed) {
          if (failed) throw StateError('synthetic writer failed');
        },
      );
      await writer.restore();
      final start = writer.sequence;
      for (var i = start; i < start + 60; i++) {
        await writer.add(
          RawTelemetryInput(
            latitude: 40 + i * .00001,
            longitude: 29,
            timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
            speedMps: 2,
            headingDegrees: 0,
            altitudeMeters: 50,
            accuracyMeters: 4,
          ),
        );
      }
      await writer.close();
      FlutterForegroundTask.sendDataToMain({
        'gpsProbeDone': true,
        'sequence': writer.sequence,
      });
    } catch (_) {
      FlutterForegroundTask.sendDataToMain({'gpsProbeDone': false});
    } finally {
      await store?.close();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native reliable timing survives SQLite to Hive with exact source points',
    (_) async {
      final root = Directory(
        '${await getDatabasesPath()}/gps_reliability_${DateTime.now().microsecondsSinceEpoch}',
      );
      await root.create();
      Hive.init(root.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DriveSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RoutePointAdapter());
      }
      DriveTelemetryHive.registerAdapters(Hive);
      await Hive.openBox<DriveSession>('drives');
      await DriveTelemetryHive.openBox(Hive);
      final store = await GpsSessionStore.open(
        factory: databaseFactory,
        path: '${root.path}/journal.db',
      );
      try {
        final s = await store.create();
        final times = [
          for (var t = 0; t <= 50; t += 5) t,
          for (var t = 60; t <= 100; t += 5) t,
        ];
        final points = <CanonicalTelemetryPoint>[];
        for (var i = 0; i < times.length; i++) {
          final p = CanonicalTelemetryPoint(
            latitude: 40 + i * .0001,
            longitude: 29,
            timestamp: s.startedAt.add(Duration(seconds: times[i])),
            speedMps: 10,
            headingDegrees: 0,
            altitudeMeters: 0,
            accuracyMeters: 3,
            distanceFromPreviousMeters: i == 0 ? 0 : 50,
            accelerationMps2: 0,
            speedSource: 'native',
            gapDurationMicros: times[i] == 60 ? 10000000 : 0,
          );
          points.add(p);
          await store.append(s.id, i + 1, p);
        }
        final stop = s.startedAt.add(const Duration(seconds: 200));
        await store.requestStop(s.id, at: stop);
        await store.stop(s.id, expectedSequence: points.length);
        final projection = DriveRouteProjection(points);
        final transfer = GpsSessionTransfer(store, GpsHiveTransferSink());
        await transfer.save(
          s.id,
          driveTransferManifest(
            DriveSession(
              id: s.id,
              date: DateTime.now(),
              distance: projection.distanceMeters,
              durationSeconds: 200,
              averageSpeed: 36,
              maxSpeed: 36,
              mapImagePath: '',
              route: projection.route,
            ),
          ),
        );
        final restored = DriveTelemetryStorageService.get(s.id)!;
        expect(restored.acquisitionMetadata['reliabilityPolicyVersion'], 1);
        expect(
          restored.acquisitionMetadata['stopRequestedAtMicros'],
          stop.microsecondsSinceEpoch,
        );
        expect(
          jsonEncode(
            restored.points.map(GpsSessionTransfer.pointContent).toList(),
          ),
          jsonEncode(points.map(GpsSessionTransfer.pointContent).toList()),
        );
        final timing = DriveTimeAnalysis.fromRecord(restored);
        expect(timing.measuredMicros, 90000000);
        expect(timing.coverage, .45);
        expect(timing.scoreEligible, false);
        expect(projection.distanceMeters, timing.distanceMeters);
        expect(await transfer.verify(s.id), true);
      } finally {
        await store.close();
        await Hive.close();
      }
    },
  );
  testWidgets(
    'native Phase 4 stopped journal transfers/verifies Hive and isolated retention',
    (_) async {
      final root = Directory(
        '${await getDatabasesPath()}/gps_phase4_${DateTime.now().microsecondsSinceEpoch}',
      );
      await root.create();
      Hive.init(root.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DriveSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RoutePointAdapter());
      }
      DriveTelemetryHive.registerAdapters(Hive);
      await Hive.openBox<DriveSession>('drives');
      await DriveTelemetryHive.openBox(Hive);
      var store = await GpsSessionStore.open(
        factory: databaseFactory,
        path: '${root.path}/journal.db',
      );
      try {
        final s = await store.create();
        final writer = GpsRecordingWriter(
          store,
          s.id,
          onError: (_) => fail('native synthetic write failed'),
        );
        await writer.restore();
        for (var i = 0; i < 300; i++) {
          await writer.add(
            RawTelemetryInput(
              latitude: 40 + i * .0001,
              longitude: 29,
              timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
              speedMps: 10,
              headingDegrees: 0,
              altitudeMeters: 0,
              accuracyMeters: 4,
            ),
          );
        }
        await writer.close();
        await store.stop(s.id, expectedSequence: writer.sequence);
        await store.close();
        store = await GpsSessionStore.open(
          factory: databaseFactory,
          path: '${root.path}/journal.db',
        );
        expect(await store.lifecycle(s.id), 'PENDING_SAVE');
        final points = (await store.read(s.id)).map((p) => p.point).toList();
        final route = <RoutePoint>[];
        var distance = 0.0;
        for (final p in points) {
          if (route.isEmpty ||
              p.breakBefore ||
              p.distanceFromPreviousMeters > 0) {
            route.add(
              RoutePoint(
                latitude: p.latitude,
                longitude: p.longitude,
                breakBefore: p.breakBefore,
              ),
            );
            if (route.length > 1 && !p.breakBefore) {
              distance += p.distanceFromPreviousMeters;
            }
          }
        }
        final manifest = driveTransferManifest(
          DriveSession(
            id: s.id,
            date: DateTime.utc(2026),
            distance: distance,
            durationSeconds: 299,
            averageSpeed: 10,
            maxSpeed: 36,
            mapImagePath: '',
            route: route,
          ),
        );
        final transfer = GpsSessionTransfer(store, GpsHiveTransferSink());
        await transfer.save(s.id, manifest);
        await transfer.save(s.id, manifest);
        await Hive.close();
        await Hive.openBox<DriveSession>('drives');
        await DriveTelemetryHive.openBox(Hive);
        expect(await transfer.verify(s.id), true);
        expect(await store.lifecycle(s.id), 'VERIFIED');
        expect(Hive.box<DriveSession>('drives').length, 1);
        final other = await store.create();
        await store.removeVerifiedJournal(
          s.id,
          now: DateTime.now().add(const Duration(days: 31)),
          verifyHive: (_) => transfer.verify(s.id),
        );
        expect(await store.read(s.id), isEmpty);
        expect((await store.active())!.id, other.id);
      } finally {
        await store.close();
        await Hive.close();
      }
    },
  );
  testWidgets(
    'native Phase 3 checkpoint recovers zero-speed evidence and gap quality',
    (_) async {
      final path =
          '${await getDatabasesPath()}/gps_speed_phase3_${DateTime.now().microsecondsSinceEpoch}.db';
      var store = await GpsSessionStore.open(
        factory: databaseFactory,
        path: path,
      );
      final session = await store.create();
      var writer = GpsRecordingWriter(
        store,
        session.id,
        onError: (_) => fail('synthetic native write failed'),
      );
      final oracle = CanonicalTelemetryPipeline();
      RawTelemetryInput input(int i) {
        final seconds = i < 40 ? i * .2 : 24.8 + (i - 40) * .2;
        final meters = i < 40 ? i * 2.8 : 109.2 + 310 + (i - 40) * 2.8;
        return RawTelemetryInput(
          latitude: meters / 111194.92664455874,
          longitude: 0,
          timestamp: DateTime.utc(
            2026,
          ).add(Duration(microseconds: (seconds * 1000000).round())),
          speedMps: 0,
          headingDegrees: 0,
          altitudeMeters: 10,
          accuracyMeters: 5,
        );
      }

      final expected = <Map<String, dynamic>>[];
      try {
        await writer.restore();
        for (var i = 0; i < 100; i++) {
          expected.add(oracle.add(input(i))!.toMap());
          await writer.add(input(i));
          if (i == 20 || i == 45) {
            await writer.close();
            await store.close();
            store = await GpsSessionStore.open(
              factory: databaseFactory,
              path: path,
            );
            writer = GpsRecordingWriter(
              store,
              session.id,
              onError: (_) => fail('synthetic restore write failed'),
            );
            await writer.restore();
          }
        }
        await writer.close();
        final rows = await store.read(session.id);
        expect(rows.length, 100);
        expect(rows.map((r) => r.point.toMap()).toList(), expected);
        expect(rows.last.point.speedMps, closeTo(14, .01));
        expect(rows[40].point.breakBefore, isTrue);
        expect(rows[40].point.distanceFromPreviousMeters, 0);
        expect(rows[40].point.accelerationReliable, isFalse);
      } finally {
        await store.close();
      }
    },
  );
  final suffix = DateTime.now().microsecondsSinceEpoch;
  testWidgets('original Android configuration: capture first native exception', (
    _,
  ) async {
    // Separate synthetic DB: never opens DriveIt's real journal or Hive.
    Database? db;
    var stage = 'wal';
    try {
      db = await openDatabase(
        '${await getDatabasesPath()}/gps_original_probe_$suffix.db',
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL');
          stage = 'synchronous';
          await db.execute('PRAGMA synchronous=FULL');
          stage = 'foreign_keys';
          await db.execute('PRAGMA foreign_keys=ON');
          stage = 'busy_timeout';
          await db.execute('PRAGMA busy_timeout=5000');
        },
      );
      // Platform-dependent result, not an assumed bug.
      // ignore: avoid_print
      print('DriveItGpsProbe legacy_configuration_failed=false');
    } on DatabaseException catch (error) {
      final nonQuery = error.toString().contains('query or rawQuery');
      // Fixed allowlist; no raw SQL/error payload or local path.
      // ignore: avoid_print
      print(
        'DriveItGpsProbe legacy_configuration_failed=true stage=$stage db_code=${error.getResultCode()} non_query_row=$nonQuery',
      );
    } finally {
      await db?.close();
    }
  });
  testWidgets('native sqflite WAL/FULL/timeout and session restart recovery', (
    _,
  ) async {
    final path = '${await getDatabasesPath()}/gps_fixed_probe_$suffix.db';
    var store = await GpsSessionStore.open(
      factory: databaseFactory,
      path: path,
    );
    try {
      expect(
        (await store.db.rawQuery('PRAGMA journal_mode')).single.values.single,
        'wal',
      );
      expect(
        (await store.db.rawQuery('PRAGMA synchronous')).single.values.single,
        2,
      );
      expect(
        (await store.db.rawQuery('PRAGMA busy_timeout')).single.values.single,
        5000,
      );
      expect(await store.active(), isNull);
      final session = await store.create();
      var writer = GpsRecordingWriter(
        store,
        session.id,
        onError: (_) => fail('native write failed'),
      );
      await writer.restore();
      RawTelemetryInput sample(int i) => RawTelemetryInput(
        latitude: 40 + i * .00001,
        longitude: 29,
        timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
        speedMps: 2,
        accuracyMeters: 4,
        headingDegrees: 0,
        altitudeMeters: 50,
      );
      for (var i = 0; i < 120; i++) {
        await writer.add(sample(i));
      }
      await writer.close();
      await store.close();
      store = await GpsSessionStore.open(factory: databaseFactory, path: path);
      final status = await inspectDriveRecovery(
        loadActive: store.active,
        legacyActive: () async => false,
        loadLegacy: () async => [],
      );
      expect(status.hasVerifiedSession, true);
      expect(status.session!.id, session.id);
      writer = GpsRecordingWriter(
        store,
        session.id,
        onError: (_) => fail('native retry failed'),
      );
      await writer.restore();
      await writer.add(sample(119)); // duplicate callback after recreation
      for (var i = 120; i < 240; i++) {
        await writer.add(sample(i));
      }
      await writer.close();
      final rows = await store.read(session.id);
      expect(rows.length, 240);
      expect(rows.map((r) => r.sequence), List.generate(240, (i) => i + 1));
    } finally {
      await store.close();
    }
  });
  for (final oldVersion in [1, 2]) {
    testWidgets(
      'native v$oldVersion upgrade preserves journal; v3 lifecycle and stop receipt survive reopen',
      (_) async {
        final path =
            '${await getDatabasesPath()}/gps_upgrade_probe_${oldVersion}_$suffix.db';
        final legacy = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: oldVersion,
            onCreate: (db, _) async {
              await db.execute(
                'CREATE TABLE sessions (id TEXT PRIMARY KEY, started_us INTEGER NOT NULL, stopped_us INTEGER, state TEXT NOT NULL, error TEXT, saved_drive_id TEXT)',
              );
              await db.execute(
                'CREATE TABLE current_session (singleton INTEGER PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id))',
              );
              await db.execute(
                'CREATE TABLE points (session_id TEXT NOT NULL REFERENCES sessions(id), sequence INTEGER NOT NULL, timestamp_us INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(session_id,sequence), UNIQUE(session_id,timestamp_us))',
              );
              if (oldVersion == 2) {
                await db.execute(
                  'CREATE TABLE session_events (session_id TEXT NOT NULL REFERENCES sessions(id), kind TEXT NOT NULL, occurred_us INTEGER NOT NULL, sequence INTEGER, PRIMARY KEY(session_id,kind))',
                );
              }
            },
          ),
        );
        await legacy.insert('sessions', {
          'id': 'synthetic-v1',
          'started_us': 1,
          'state': 'recording',
        });
        await legacy.insert('current_session', {
          'singleton': 1,
          'session_id': 'synthetic-v1',
        });
        final oldPoint = CanonicalTelemetryPipeline().add(
          RawTelemetryInput(
            latitude: 40,
            longitude: 29,
            timestamp: DateTime.utc(2026),
            speedMps: 11,
            headingDegrees: 0,
            altitudeMeters: 30,
            accuracyMeters: 3,
          ),
        )!;
        final oldPayload = jsonEncode(
          GpsJournalPoint('synthetic-v1', 1, oldPoint).toMap(),
        );
        await legacy.insert('points', {
          'session_id': 'synthetic-v1',
          'sequence': 1,
          'timestamp_us': oldPoint.timestamp.microsecondsSinceEpoch,
          'payload': oldPayload,
        });
        if (oldVersion == 2) {
          await legacy.insert('session_events', {
            'session_id': 'synthetic-v1',
            'kind': 'started',
            'occurred_us': 1,
            'sequence': 0,
          });
        }
        await legacy.close();
        var store = await GpsSessionStore.open(
          factory: databaseFactory,
          path: path,
        );
        expect((await store.db.query('points')).single['payload'], oldPayload);
        if (oldVersion == 2) {
          expect(
            (await store.events('synthetic-v1')).single['kind'],
            'started',
          );
        }
        var writer = GpsRecordingWriter(
          store,
          'synthetic-v1',
          onError: (_) => fail('write'),
        );
        RawTelemetryInput input(int sec) => RawTelemetryInput(
          latitude: 40 + sec * .0001,
          longitude: 29,
          timestamp: DateTime.utc(2026).add(Duration(seconds: sec)),
          speedMps: 11,
          headingDegrees: 0,
          altitudeMeters: 30,
          accuracyMeters: 3,
        );
        await writer.restore();
        await writer.add(input(0));
        await writer.close();
        await store.close();
        store = await GpsSessionStore.open(
          factory: databaseFactory,
          path: path,
        );
        writer = GpsRecordingWriter(
          store,
          'synthetic-v1',
          onError: (_) => fail('retry'),
        );
        await writer.restore();
        await writer.add(input(120));
        final requested = DateTime.now();
        await store.requestStop('synthetic-v1', at: requested);
        await writer.drain();
        await store.stop('synthetic-v1', expectedSequence: 2);
        await store.stop('synthetic-v1', expectedSequence: 2);
        expect((await store.read('synthetic-v1')).last.point.breakBefore, true);
        expect((await store.session('synthetic-v1'))!.stoppedAt, requested);
        expect(
          (await store.events(
            'synthetic-v1',
          )).where((e) => e['kind'] == 'drained').single['sequence'],
          2,
        );
        expect(await store.db.getVersion(), 3);
        await writer.close();
        await store.close();
      },
    );
  }
  testWidgets(
    'headless foreground engine writes and recreation retains prefix',
    (tester) async {
      // Emulator runner grants Android location permission to the test package
      // after installation. No permission or app action on a physical phone.
      await Future<void>.delayed(const Duration(seconds: 12));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Synthetic GPS engine test')),
        ),
      );
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'gps_probe',
          channelName: 'Synthetic GPS probe',
          channelDescription: 'Emulator test only',
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(1000),
        ),
      );
      // Never take over an unrelated service, even on an emulator.
      expect(await FlutterForegroundTask.isRunningService, false);
      final path =
          '${await getDatabasesPath()}/gps_background_probe_$suffix.db';
      final store = await GpsSessionStore.open(
        factory: databaseFactory,
        path: path,
      );
      final session = await store.create();
      await FlutterForegroundTask.saveData(
        key: 'gps_native_probe_path',
        value: path,
      );
      var ownedService = false;
      try {
        for (var round = 1; round <= 2; round++) {
          final done = Completer<Map>();
          void receive(Object data) {
            if (data is Map &&
                data.containsKey('gpsProbeDone') &&
                !done.isCompleted) {
              done.complete(data);
            }
          }

          FlutterForegroundTask.addTaskDataCallback(receive);
          try {
            final started = await FlutterForegroundTask.startService(
              serviceId: 907,
              notificationTitle: 'Synthetic GPS engine test',
              notificationText: 'Emulator only',
              serviceTypes: const [ForegroundServiceTypes.location],
              callback: gpsProbeCallback,
            );
            expect(started, isNot(isA<ServiceRequestFailure>()));
            ownedService = true;
            final result = await done.future.timeout(
              const Duration(seconds: 45),
            );
            expect(result['gpsProbeDone'], true);
            expect(result['sequence'], round * 60);
            final stopped = await FlutterForegroundTask.stopService();
            expect(stopped, isNot(isA<ServiceRequestFailure>()));
            ownedService = false;
          } finally {
            FlutterForegroundTask.removeTaskDataCallback(receive);
          }
        }
        final points = await store.read(session.id);
        expect(points.length, 120);
        expect(points.map((p) => p.sequence), List.generate(120, (i) => i + 1));
        expect((await store.active())!.id, session.id);
      } finally {
        if (ownedService) await FlutterForegroundTask.stopService();
        await store.close();
      }
    },
  );
}
