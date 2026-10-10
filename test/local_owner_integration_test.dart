import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/screens/career_screen.dart';
import 'package:driveit_project/widgets/drive_score_summary_section.dart';
import 'package:driveit_project/screens/history_screen.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/services/local_owner_gps_bridge.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:driveit_project/widgets/local_owner_navigator.dart';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class TestAuth implements LocalOwnerAuth {
  @override
  String? userId = a;
  final events = StreamController<String?>.broadcast(sync: true);
  @override
  Stream<String?> get changes => events.stream;
  void emit(String? id) {
    userId = id;
    events.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late TestAuth auth;
  late LocalOwnerLifecycle runtime;
  late GpsSessionStore journal;
  late GpsOwnershipStore sidecar;
  late LocalOwnerGpsBridge gps;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_5c2_');
    auth = TestAuth();
    journal = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/journal.db',
    );
    sidecar = await GpsOwnershipStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/owners.db',
    );
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async =>
          (await journal.recoverableSessions()).isNotEmpty,
      activeSessionOwner: () => gps.activeOwner(),
    );
    gps = LocalOwnerGpsBridge(
      runtime: runtime,
      journal: journal,
      ownership: sidecar,
      journalId: 'journal-v1',
    );
  });
  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await sidecar.close();
    await journal.close();
    await root.delete(recursive: true);
  });
  DriveSession drive() => DriveSession(
    id: 'same',
    date: DateTime.utc(2026),
    distance: 0,
    durationSeconds: 0,
    averageSpeed: 0,
    maxSpeed: 0,
    mapImagePath: '',
    route: [],
  );

  test(
    'SDK AuthState projection emits UUID/null only and deduplicates refresh',
    () async {
      final sdk = StreamController<AuthState>();
      final adapter = SupabaseLocalOwnerAuth.events(
        currentUserId: () => a,
        events: sdk.stream,
      );
      final seen = <String?>[];
      final sub = adapter.changes.listen(seen.add);
      final user = User(
        id: a,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      final session = Session(
        accessToken: 'synthetic-not-a-real-token',
        tokenType: 'bearer',
        user: user,
      );
      sdk.add(AuthState(AuthChangeEvent.signedIn, session));
      sdk.add(AuthState(AuthChangeEvent.tokenRefreshed, session));
      sdk.add(const AuthState(AuthChangeEvent.signedOut, null));
      await sdk.close();
      await sub.cancel();
      expect(adapter.userId, a);
      expect(seen, [a, null]);
    },
  );
  test(
    'same durable owner reopens personal context during active recovery',
    () async {
      await runtime.start();
      final session = await gps.start(startNative: (_, _) async {});
      final epoch = runtime.epoch;
      await runtime.retry();
      expect(runtime.state, LocalOwnerState.ready);
      expect(runtime.epoch, greaterThan(epoch));
      expect((await gps.requireBinding(session.id)).owner.userId, a);
    },
  );
  test(
    'unknown old session blocks context rather than assigning current Auth',
    () async {
      final old = await journal.create();
      await runtime.start();
      expect(runtime.state, LocalOwnerState.blocked);
      await expectLater(gps.requireBinding(old.id), throwsStateError);
      expect(await sidecar.get('journal-v1', old.id), null);
      expect((await journal.active())!.id, old.id);
    },
  );
  test(
    'GPS creation and user logout share fence; logout never reaches Auth',
    () async {
      await runtime.start();
      final entered = Completer<void>();
      final release = Completer<void>();
      final start = gps.start(
        startNative: (_, _) async {
          entered.complete();
          await release.future;
        },
      );
      await entered.future;
      var called = false;
      final logout = runtime.authorizeIdentityChange(() async {
        called = true;
      });
      final check = expectLater(logout, throwsStateError);
      release.complete();
      await start;
      await check;
      expect(called, false);
    },
  );
  test(
    'external Auth hides UI but preserves durable foreground owner',
    () async {
      await runtime.start();
      final session = await gps.start(startNative: (_, _) async {});
      auth.emit(b);
      await runtime.settled;
      expect(runtime.state, LocalOwnerState.blocked);
      expect((await gps.requireBinding(session.id)).owner.userId, a);
      expect((await journal.active())!.id, session.id);
    },
  );
  test('native start failure keeps bound recoverable journal', () async {
    await runtime.start();
    await expectLater(
      gps.start(
        startNative: (_, _) async {
          throw StateError('native denied');
        },
      ),
      throwsStateError,
    );
    final session = (await journal.active())!;
    expect((await gps.requireBinding(session.id)).owner.userId, a);
    await expectLater(
      gps.start(startNative: (_, _) async {}),
      throwsStateError,
    );
  });
  test(
    'failed exclusive operation does not poison future context recovery',
    () async {
      await runtime.start();
      await expectLater(
        runtime.withOwnerOperation<void>((_) async {
          throw StateError('fault');
        }),
        throwsStateError,
      );
      auth.emit(b);
      await runtime.settled;
      expect(runtime.lease.owner.userId, b);
    },
  );
  test(
    'scoped transfer reuses open Hive handle; retry retains two receipts',
    () async {
      await runtime.start();
      final session = await gps.start(startNative: (_, _) async {});
      await journal.stop(session.id, expectedSequence: 0);
      final d = drive()..id = session.id;
      await gps.transfer(session.id, driveTransferManifest(d));
      await gps.transfer(session.id, driveTransferManifest(d));
      expect(runtime.lease.keys('drives'), [session.id]);
      expect(await sidecar.verified('journal-v1', session.id), true);
      expect((await journal.session(session.id))!.state, 'saved');
    },
  );
  test(
    'queued GPS owner operation cannot execute after external Auth invalidation',
    () async {
      await runtime.start();
      final entered = Completer<void>();
      final release = Completer<void>();
      final first = runtime.withOwnerOperation<void>((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var ran = false;
      final pending = runtime.withOwnerOperation<void>((_) async {
        ran = true;
      });
      final check = expectLater(pending, throwsStateError);
      auth.emit(b);
      release.complete();
      await first;
      await check;
      await runtime.settled;
      expect(ran, false);
      expect(runtime.lease.owner.userId, b);
    },
  );
  testWidgets('pushed private route disappears with owner epoch', (
    tester,
  ) async {
    await tester.runAsync(runtime.start);
    await tester.pumpWidget(
      MaterialApp(
        home: LocalOwnerNavigator(
          runtime: runtime,
          legacyChild: const Text('legacy'),
          routes: {
            '/': (context, lease, _) => TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/detail'),
              child: const Text('open'),
            ),
            '/detail': (_, lease, _) => Text('private:${lease.owner.userId}'),
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('private:$a'), findsOneWidget);
    await tester.runAsync(() async {
      auth.emit(b);
      await runtime.settled;
    });
    await tester.pumpAndSettle();
    expect(find.text('private:$a'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('unknown owner route fails closed, never builds legacy', (
    tester,
  ) async {
    await tester.runAsync(runtime.start);
    await tester.pumpWidget(
      MaterialApp(
        home: LocalOwnerNavigator(
          runtime: runtime,
          legacyChild: const Text('shared secret'),
          initialRoute: '/unwired',
          routes: const {},
        ),
      ),
    );
    expect(find.text('shared secret'), findsNothing);
    expect(
      find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'actual History reads scoped drive/name without shared Hive boxes',
    (tester) async {
      await tester.runAsync(() async {
        await runtime.start();
        await runtime.lease.put('drives', 'same', drive());
        await runtime.lease.put('drive_names', 'same', 'A private drive');
      });
      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(ownerLease: runtime.lease)),
      );
      expect(find.text('A private drive'), findsOneWidget);
      await tester.tap(find.text('A private drive'));
      await tester.pump();
      expect(
        find.text('Hesaba özel sürüş detayı henüz hazır değil.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'score widget uses scoped persisted score, no global fallback or calculator',
    (tester) async {
      await tester.runAsync(() async {
        await runtime.start();
        await runtime.lease.put(
          'drive_scores',
          'same:v1',
          DriveScoreRecord(
            driveId: 'same',
            algorithmVersion: 1,
            telemetryDataVersion: 1,
            calculatedAt: DateTime.utc(2026),
            totalScore: 700,
            overallConfidence: .9,
            categories: [],
          ),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriveScoreSummarySection(
              driveId: 'same',
              ownerLease: runtime.lease,
              loader: (_) => throw StateError('Shared loader must not run'),
              reliabilityLoader: (_) =>
                  throw StateError('Shared reliability must not run'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.runAsync(() async {
        auth.emit(b);
        await runtime.settled;
      });
      expect(runtime.lease.score('same'), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Career missing owner baseline shows protected error, never reads shared history',
    (tester) async {
      await tester.runAsync(runtime.start);
      await tester.pumpWidget(
        MaterialApp(home: CareerScreen(ownerLease: runtime.lease)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Kariyer verisi okunamadı. Kayıtların korunuyor.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
