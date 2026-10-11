// Synthetic Hive only; never app.main(), platform Auth, or a device data path.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/hive.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/legacy_source_writer_fence.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/screens/history_screen.dart';
import 'package:driveit_project/screens/device_drive_archive_screen.dart';
import 'package:driveit_project/widgets/owner_personal_navigator.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;

class _Fence implements RegisteredSourceWriterFence {
  bool fail = false;
  int pauses = 0, resumes = 0;
  @override
  void requireRegistered() {}
  @override
  Future<void> pauseAndDrain() async {
    pauses++;
    if (fail) throw StateError('synthetic_drain_failure');
  }

  @override
  Future<void> resume() async {
    resumes++;
  }
}

class _Authorization implements DeviceArchiveAuthorizer {
  bool allowed = true;
  Completer<bool>? pending;
  @override
  Future<bool> verifyDeviceAccess() async =>
      pending == null ? allowed : pending!.future;
}

class _Maps extends maps.GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HiveImpl hive;
  late Box<DriveSession> box;
  late LocalOwnerLifecycle runtime;
  late TestAuth auth;
  late _Fence fence;
  late _Authorization authorization;
  late DeviceDriveArchiveSnapshot snapshot;
  DeviceDriveArchiveAccess access({bool enabled = true}) =>
      DeviceDriveArchiveAccess(
        gate: enabled
            ? LocalOwnershipGate.synthetic()
            : LocalOwnershipGate.production,
        snapshot: snapshot,
        authorizer: authorization,
      );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_archive_fixture_');
    hive = HiveImpl()
      ..init('${root.path}/legacy')
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    box = await hive.openBox<DriveSession>('drives');
    await box.put(
      'old',
      DriveSession(
        id: 'old',
        date: DateTime.utc(2026, 9, 28, 11, 24),
        distance: 12345.67,
        durationSeconds: 5776,
        averageSpeed: 34.5,
        maxSpeed: 87.6,
        mapImagePath: 'never-open-this-image',
        route: [
          RoutePoint(
            latitude: 40,
            longitude: 29,
            legacyHiveFields: {2: DateTime.utc(2026)},
          ),
          RoutePoint(latitude: 40.01, longitude: 29.01),
          RoutePoint(latitude: 40.02, longitude: 29.02, breakBefore: true),
        ],
      ),
    );
    await box.flush();
    fence = _Fence();
    authorization = _Authorization();
    auth = TestAuth();
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      driveInProgress: () async => false,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: '${root.path}/owners', owner: owner),
    );
    await runtime.start();
    snapshot = await DeviceDriveArchiveSnapshot.prepare(
      source: SavedDriveArchiveSource(box),
      writers: fence,
      unfinishedDriveIds: () async => {},
    );
  });
  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await hive.close();
    await root.delete(recursive: true);
  });
  testWidgets(
    'background revokes granted context permanently, resume cannot revive it',
    (tester) async {
      final context = await access().open(runtime.lease);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(context.isCurrent, false);
      expect(() => context.drive('old'), throwsStateError);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(context.isCurrent, false);
      context.dispose();
    },
  );
  testWidgets(
    'late authentication success after background cannot grant access',
    (tester) async {
      authorization.pending = Completer<bool>();
      final result = access().open(runtime.lease);
      final rejected = expectLater(result, throwsStateError);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      authorization.pending!.complete(true);
      await rejected;
    },
  );
  testWidgets(
    'short lived grant expires and direct detail never bypasses expired context',
    (tester) async {
      final shortAccess = DeviceDriveArchiveAccess(
        gate: LocalOwnershipGate.synthetic(),
        snapshot: snapshot,
        authorizer: authorization,
        accessLifetime: const Duration(seconds: 1),
      );
      final context = await shortAccess.open(runtime.lease);
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceDriveArchiveDetailScreen(
            archive: context,
            driveId: 'old',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(context.isCurrent, false);
      expect(find.textContaining('Arşiv erişimi sona erdi'), findsOneWidget);
      expect(() => context.drive('old'), throwsStateError);
      await tester.pumpWidget(const SizedBox());
      context.dispose();
    },
  );
  testWidgets(
    'native prompt inactive focus waits for resumed before granting',
    (tester) async {
      authorization.pending = Completer<bool>();
      final result = access().open(runtime.lease);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      authorization.pending!.complete(true);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final context = await result;
      expect(context.isCurrent, true);
      context.dispose();
    },
  );
  testWidgets('ID-only archive deep link cannot mint a device grant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OwnerPersonalNavigator(
          runtime: runtime,
          legacyChild: const Text('legacy'),
          deviceArchive: access(),
        ),
      ),
    );
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(HomeScreen)),
    ).pushNamed('/device-archive/detail', arguments: 'old');
    await tester.pumpAndSettle();
    expect(find.byType(DeviceDriveArchiveDetailScreen), findsNothing);
    expect(
      find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> switchTo(String id) async {
    auth.emit(id);
    await runtime.settled;
  }

  test(
    'exact saved metadata and all GPS samples including legacy DateTime survive',
    () async {
      final context = await access().open(runtime.lease);
      final drive = context.drive('old');
      expect(context.drives().single.id, 'old');
      expect(drive.date, DateTime.utc(2026, 9, 28, 11, 24));
      expect(drive.distance, 12345.67);
      expect(drive.durationSeconds, 5776);
      expect(drive.averageSpeed, 34.5);
      expect(drive.maxSpeed, 87.6);
      expect(drive.route.map((p) => p.latitude), [40, 40.01, 40.02]);
      expect(drive.route.last.breakBefore, true);
      expect(drive.route.first.legacyHiveFields[2], DateTime.utc(2026));
      context.dispose();
    },
  );
  test(
    'archive source bytes unchanged; returned models cannot write or mutate snapshot',
    () async {
      final file = File('${root.path}/legacy/drives.hive');
      final before = await file.readAsBytes();
      snapshot = await DeviceDriveArchiveSnapshot.prepare(
        source: SavedDriveArchiveSource(box),
        writers: fence,
        unfinishedDriveIds: () async => {},
      );
      final context = await access().open(runtime.lease);
      final copy = context.drive('old');
      copy.distance = 0;
      copy.route.clear();
      expect(copy.isInBox, false);
      expect(() => copy.save(), throwsA(isA<HiveError>()));
      expect(() => copy.delete(), throwsA(isA<HiveError>()));
      expect(context.drive('old').route, hasLength(3));
      expect(context.drive('old').distance, 12345.67);
      expect(await file.readAsBytes(), before);
      expect(box.get('old')!.distance, 12345.67);
      context.dispose();
    },
  );
  test(
    'A and B History World Career and outbox never acquire archive records',
    () async {
      for (final id in [a, b, a]) {
        await switchTo(id);
        expect(runtime.lease.drives(), isEmpty);
        for (final group in [
          'career_contributions_v1',
          'my_world_source_snapshots_v1',
          'planet_segment_outbox_v1',
          'drive_posters',
        ]) {
          expect(runtime.lease.keys(group), isEmpty);
        }
      }
    },
  );
  test('A to B to A revokes previous independent archive capability', () async {
    final old = await access().open(runtime.lease);
    await switchTo(b);
    expect(old.isCurrent, false);
    expect(() => old.drive('old'), throwsStateError);
    await switchTo(a);
    expect(() => old.drives(), throwsStateError);
    final fresh = await access().open(runtime.lease);
    expect(fresh.drives(), hasLength(1));
    fresh.dispose();
    old.dispose();
  });
  test('account login is not archive authority', () async {
    authorization.allowed = false;
    await expectLater(access().open(runtime.lease), throwsStateError);
  });
  test(
    'epoch change during device authorization cannot grant new account',
    () async {
      authorization.pending = Completer<bool>();
      final result = access().open(runtime.lease);
      await switchTo(b);
      authorization.pending!.complete(true);
      await expectLater(result, throwsStateError);
    },
  );
  test(
    'production gate remains closed even with successful fake verification',
    () async {
      await expectLater(
        access(enabled: false).open(runtime.lease),
        throwsStateError,
      );
    },
  );
  test(
    'serialized snapshot validates on fresh reconstruction, no migration or import',
    () async {
      snapshot = DeviceDriveArchiveSnapshot.restore(snapshot.serialize());
      final context = await access().open(runtime.lease);
      expect(context.drive('old').route, hasLength(3));
      context.dispose();
    },
  );
  test(
    'source close and reopen retains archive without rewriting saved drives',
    () async {
      await box.close();
      box = await hive.openBox<DriveSession>('drives');
      final rebuilt = await DeviceDriveArchiveSnapshot.prepare(
        source: SavedDriveArchiveSource(box),
        writers: fence,
        unfinishedDriveIds: () async => {},
      );
      expect(rebuilt.fingerprint, snapshot.fingerprint);
    },
  );
  test(
    'direct ID not in archive is rejected independently of account History',
    () async {
      final context = await access().open(runtime.lease);
      await runtime.lease.put(
        'drives',
        'account-only',
        DriveSession(
          id: 'account-only',
          date: DateTime.utc(2026),
          distance: 1,
          durationSeconds: 1,
          averageSpeed: 1,
          maxSpeed: 1,
          mapImagePath: '',
          route: [],
        ),
      );
      expect(() => context.drive('account-only'), throwsStateError);
      context.dispose();
    },
  );
  test('partial corrupt or unsupported snapshot fails closed', () {
    expect(() => DeviceDriveArchiveSnapshot.restore('{}'), throwsStateError);
    final value = jsonDecode(snapshot.serialize()) as Map<String, dynamic>;
    (value['rows'] as Map)['old'] = 'broken';
    expect(
      () => DeviceDriveArchiveSnapshot.restore(jsonEncode(value)),
      throwsStateError,
    );
  });
  test('active or unsaved journal evidence blocks snapshot', () async {
    await expectLater(
      DeviceDriveArchiveSnapshot.prepare(
        source: SavedDriveArchiveSource(box),
        writers: fence,
        unfinishedDriveIds: () async => {'old'},
      ),
      throwsStateError,
    );
    expect(fence.resumes, fence.pauses);
  });
  test('failed writer drain cannot publish snapshot', () async {
    fence.fail = true;
    await expectLater(
      DeviceDriveArchiveSnapshot.prepare(
        source: SavedDriveArchiveSource(box),
        writers: fence,
        unfinishedDriveIds: () async => {},
      ),
      throwsStateError,
    );
  });
  testWidgets('History to device archive to detail to segmented GPS map', (
    tester,
  ) async {
    final original = maps.GoogleMapsFlutterPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = _Maps();
    addTearDown(() => maps.GoogleMapsFlutterPlatform.instance = original);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(ownerLease: runtime.lease, deviceArchive: access()),
      ),
    );
    await tester.tap(find.text('Cihazdaki Eski Sürüşler'));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceDriveArchiveScreen), findsOneWidget);
    await tester.tap(find.text('28.09.2026 11:24'));
    await tester.pumpAndSettle();
    expect(find.text('Ortalama hız: 34.5 km/sa'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    await tester.tap(find.text('GPS Rota Haritası'));
    await tester.pumpAndSettle();
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.polylines, hasLength(2));
    expect(map.polylines.expand((p) => p.points), hasLength(3));
    expect(map.myLocationEnabled, false);
    await tester.runAsync(() => switchTo(b));
    await tester.pumpAndSettle();
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.textContaining('Arşiv erişimi sona erdi'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'missing device authorizer leaves controlled History entry disabled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(ownerLease: runtime.lease)),
      );
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Cihazdaki Eski Sürüşler'),
      );
      expect(tile.onTap, null);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
