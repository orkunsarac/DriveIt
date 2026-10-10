import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/drive_recovery_status.dart';
import 'package:driveit_project/services/gps_failure.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/screens/drive_recovery_screen.dart';
import 'package:driveit_project/widgets/gps_recovery_notice.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';

class CannotOpenFactory implements DatabaseFactory {
  @override
  Future<String> getDatabasesPath() async => 'synthetic';
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async => throw StateError('synthetic native open failure');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final finish in [false, true]) {
    testWidgets('explicit recovery choice finish=$finish keeps same session', (
      tester,
    ) async {
      final session = GpsSession(
        'same-session',
        DateTime.utc(2026),
        'recording',
        null,
      );
      bool? requestedFinish, requestedResume;
      await tester.pumpWidget(
        MaterialApp(
          home: DriveRecoveryScreen(
            initialStatus: DriveRecoveryStatus(
              DriveRecoveryKind.verifiedSession,
              session: session,
            ),
            recoveredScreenBuilder: (finishOnOpen, resume) {
              requestedFinish = finishOnOpen;
              requestedResume = resume;
              return const Scaffold(body: Text('Verified journal'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requestedFinish, isNull);
      await tester.tap(
        find.text(finish ? 'Kaydet ve Bitir' : 'Sürüşe Devam Et'),
      );
      await tester.pumpAndSettle();
      expect(requestedFinish, finish);
      expect(requestedResume, !finish);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('running producer returns directly without a recovery choice', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DriveRecoveryScreen(
          initialStatus: DriveRecoveryStatus(
            DriveRecoveryKind.verifiedSession,
            session: GpsSession(
              'same-session',
              DateTime.utc(2026),
              'recording',
              null,
            ),
            producerRunning: true,
          ),
          recoveredScreenBuilder: (finish, resume) {
            expect(finish, false);
            expect(resume, false);
            opens++;
            return const Scaffold(body: Text('Live drive'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(find.text('Sürüşe Devam Et'), findsNothing);
  });
  test(
    'producer state distinguishes live UI restore from recovery decision',
    () async {
      final session = GpsSession(
        'same-session',
        DateTime.utc(2026),
        'recording',
        null,
      );
      for (final running in [true, false]) {
        final status = await inspectDriveRecovery(
          loadActive: () async => session,
          legacyActive: () async => false,
          loadLegacy: () async => [],
          producerRunning: () async => running,
        );
        expect(status.session, same(session));
        expect(status.requiresDecision, !running);
        expect(status.producerRunning, running);
        expect(status.canStartNewDrive, false);
      }
    },
  );
  testWidgets(
    'stopped producer exposes both choices without starting a session',
    (tester) async {
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DriveRecoveryScreen(
            loadStatus: () async => DriveRecoveryStatus(
              DriveRecoveryKind.verifiedSession,
              session: GpsSession(
                'same-session',
                DateTime.utc(2026),
                'recording',
                null,
              ),
            ),
            loadSessions: () async => [],
            selectSession: (_) async {
              selections++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sürüşe Devam Et'), findsOneWidget);
      expect(find.text('Kaydet ve Bitir'), findsOneWidget);
      expect(selections, 0);
      expect(tester.takeException(), isNull);
    },
  );
  Future<DriveRecoveryStatus> inspect({
    GpsSession? session,
    bool legacy = false,
    Object? error,
  }) => inspectDriveRecovery(
    loadActive: () async {
      if (error != null) throw error;
      return session;
    },
    legacyActive: () async => legacy,
    loadLegacy: () async => [
      {'time': 123, 'speedMps': 2},
    ],
  );

  test(
    'first install: no active session and no legacy -> normal startup',
    () async {
      final result = await inspect();
      expect(result.kind, DriveRecoveryKind.none);
      expect(result.canStartNewDrive, true);
      expect(result.hasVerifiedSession, false);
    },
  );
  test(
    'upgrade without an active flag does not scan/attach old buffers',
    () async {
      var oldBufferRead = false;
      final result = await inspectDriveRecovery(
        loadActive: () async => null,
        legacyActive: () async => false,
        loadLegacy: () async {
          oldBufferRead = true;
          return [
            {'time': 123},
          ];
        },
      );
      expect(result.kind, DriveRecoveryKind.none);
      expect(oldBufferRead, false);
    },
  );
  test(
    'legacy active flag has separate recovery, never a SQLite session',
    () async {
      final result = await inspect(legacy: true);
      expect(result.kind, DriveRecoveryKind.legacyPossible);
      expect(result.session, isNull);
      expect(result.hasVerifiedSession, false);
      expect(result.canStartNewDrive, false);
      expect(result.legacyPoints.single['time'], 123);
    },
  );
  test('open failure is unknown, not active or empty', () async {
    Object? caught;
    try {
      await GpsSessionStore.open(factory: CannotOpenFactory());
    } catch (error) {
      caught = error;
    }
    expect((caught as GpsFailure).code, GpsErrorCode.sqliteOpen);
    final result = await inspect(error: caught);
    expect(result.kind, DriveRecoveryKind.storageUnavailable);
    expect(result.failure!.id, 'GPS_DB_OPEN');
    expect(result.canStartNewDrive, false);
    expect(result.hasVerifiedSession, false);
  });
  test(
    'read failure is separately classified and blocks new recording',
    () async {
      final result = await inspect(error: GpsFailure(GpsErrorCode.sqliteRead));
      expect(result.kind, DriveRecoveryKind.storageUnavailable);
      expect(result.failure!.id, 'GPS_DB_READ');
      expect(result.hasVerifiedSession, false);
      expect(result.canStartNewDrive, false);
    },
  );
  test(
    'verified recording/stopped sessions take precedence over legacy flag',
    () async {
      for (final state in ['recording', 'stopped']) {
        final session = GpsSession('stable', DateTime.utc(2026), state, null);
        final result = await inspect(session: session, legacy: true);
        expect(result.hasVerifiedSession, true);
        expect(result.session!.id, 'stable');
        expect(result.canStartNewDrive, false);
        expect(result.legacyPoints, isEmpty);
      }
    },
  );
  test('invalid session state is recoverable error, not fake active', () async {
    final result = await inspect(
      session: GpsSession('stable', DateTime.utc(2026), 'invalid', null),
    );
    expect(result.kind, DriveRecoveryKind.storageUnavailable);
    expect(result.failure!.id, 'GPS_RECOVERY');
  });
  test('native safe error classification never includes input payload', () {
    final failure = GpsFailure.from(
      StateError('token=SECRET latitude=40 sql=PRIVATE'),
      GpsErrorCode.sqliteWrite,
    );
    expect(failure.id, 'GPS_DB_WRITE');
    expect('${failure.description} $failure', isNot(contains('SECRET')));
    expect('${failure.description} $failure', isNot(contains('latitude')));
    expect(
      GpsFailure.fromId('unknown token=SECRET').description,
      isNot(contains('SECRET')),
    );
    expect(
      GpsFailure(GpsErrorCode.gpsUnavailable).id,
      'GPS_SAMPLE_UNAVAILABLE',
    );
  });
  test(
    'SQLite read/write failures preserve session and committed prefix',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('gps-recovery-test-');
      final path = '${dir.path}/gps.db';
      var store = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      try {
        final session = await store.create();
        CanonicalTelemetryPoint p(int i) => CanonicalTelemetryPoint(
          latitude: 40,
          longitude: 29,
          timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
          speedMps: 2,
          headingDegrees: 0,
          altitudeMeters: 10,
          accuracyMeters: 4,
          distanceFromPreviousMeters: 0,
          accelerationMps2: 0,
        );
        await store.append(session.id, 1, p(0));
        // Synthetic failure on new INSERT only, not a modification of point data.
        await store.db.execute(
          "CREATE TRIGGER synthetic_disk_fault BEFORE INSERT ON points BEGIN SELECT RAISE(ABORT,'synthetic'); END",
        );
        await expectLater(
          store.append(session.id, 2, p(1)),
          throwsA(
            isA<GpsFailure>().having(
              (f) => f.code,
              'code',
              GpsErrorCode.sqliteWrite,
            ),
          ),
        );
        expect((await store.active())!.id, session.id);
        expect((await store.read(session.id)).length, 1);
        await store.close();
        await expectLater(
          store.active(),
          throwsA(
            isA<GpsFailure>().having(
              (f) => f.code,
              'code',
              GpsErrorCode.sqliteRead,
            ),
          ),
        );
        store = await GpsSessionStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
        );
        expect((await store.active())!.id, session.id);
        expect((await store.read(session.id)).length, 1);
      } finally {
        await store.close();
        await dir.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'recovery error allows exit to safe screen without drive controls',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('Safe home')),
        ),
      );
      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => DriveRecoveryScreen(
            initialStatus: DriveRecoveryStatus(
              DriveRecoveryKind.storageUnavailable,
              failure: GpsFailure(GpsErrorCode.sqliteOpen),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GPS_DB_OPEN'), findsOneWidget);
      expect(find.text('SÜRÜŞÜ BİTİR'), findsNothing);
      await tester.tap(find.text('Güvenli Bölümlere Dön'));
      await tester.pumpAndSettle();
      expect(find.text('Safe home'), findsOneWidget);
    },
  );
  testWidgets('legacy preview is read-only and not a resume/start action', (
    tester,
  ) async {
    final data = [
      {'time': 123, 'speedMps': 2},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: DriveRecoveryScreen(
          initialStatus: DriveRecoveryStatus(
            DriveRecoveryKind.legacyPossible,
            failure: GpsFailure(GpsErrorCode.legacyRecovery),
            legacyPoints: data,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Eski Kaydı İncele (1 örnek)'));
    await tester.pumpAndSettle();
    expect(find.text('Örnek 1'), findsOneWidget);
    expect(data, [
      {'time': 123, 'speedMps': 2},
    ]);
    expect(find.text('SÜRÜŞE BAŞLA'), findsNothing);
  });
  testWidgets('even while retry busy, leaving recovery remains enabled', (
    tester,
  ) async {
    var left = false;
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GpsRecoveryNotice(
            failure: GpsFailure(GpsErrorCode.sqliteRead),
            busy: true,
            onLeave: () => left = true,
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tekrar Kontrol Et'));
    await tester.tap(find.text('Güvenli Bölümlere Dön'));
    expect(retried, false);
    expect(left, true);
  });
}
