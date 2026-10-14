import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/screens/drive_detail_screen.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/screens/history_screen.dart';
import 'package:driveit_project/screens/world_mode_selection_screen.dart';
import 'package:driveit_project/screens/profile_settings_screen.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/owner_personal_preferences.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/widgets/local_owner_view.dart';
import 'package:driveit_project/widgets/owner_personal_navigator.dart';
import 'package:driveit_project/features/world_publish/segments/planet_publication_section.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment.dart';
import 'package:driveit_project/features/drive_poster/poster_screens.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'planet_segment_test.dart' show fixture;

class _AvailableGuestAccountGateway implements DriveItAccountGateway {
  @override
  bool get isAvailable => true;
  @override
  bool get hasSession => false;
  @override
  String? get currentDisplayName => null;
  @override
  Stream<dynamic> get authStateChanges => const Stream<dynamic>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AcceptDeviceArchiveAuth implements DeviceArchiveAuthorizer {
  @override
  Future<bool> verifyDeviceAccess() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late TestAuth auth;
  late LocalOwnerLifecycle runtime;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_screen_owner_');
    auth = TestAuth();
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
    );
    await runtime.start();
  });
  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await root.delete(recursive: true);
  });
  DriveSession drive(String id, double distance) => DriveSession(
    id: id,
    date: DateTime.utc(2026),
    distance: distance,
    durationSeconds: 60,
    averageSpeed: 0,
    maxSpeed: 0,
    mapImagePath: '',
    route: [],
  );
  Future<void> switchTo(String? id) async {
    auth.emit(id);
    await runtime.settled;
  }

  test(
    'guest, legacy, A and B stay distinct; same ID resolves authoritative owner',
    () async {
      await runtime.lease.put('drives', 'same', drive('same', 1000));
      final old = runtime.lease;
      await switchTo(b);
      expect(() => old.requireDrive('same'), throwsStateError);
      expect(() => runtime.lease.requireDrive('same'), throwsStateError);
      await runtime.lease.put('drives', 'same', drive('same', 2000));
      expect(runtime.lease.requireDrive('same').distance, 2000);
      await switchTo(null);
      expect(runtime.lease.owner, const GpsOwner.guest());
      expect(runtime.lease.drives(), isEmpty);
      await switchTo(a);
      expect(runtime.lease.requireDrive('same').distance, 1000);
      expect(
        runtime.lease.owner.targetStore,
        isNot(const GpsOwner.legacy().targetStore),
      );
    },
  );
  test(
    'profile and World preferences persist in their own owner and revoke old access',
    () async {
      final old = runtime.lease;
      final profile = OwnerProfileStore(old);
      final settings = OwnerWorldSettings(old);
      await profile.saveName('Synthetic A');
      await profile.savePhoto(Uint8List.fromList([1, 2, 3]));
      await settings.setSkipIntroAnimation(true);
      await switchTo(b);
      expect(() => profile.name, throwsStateError);
      expect(() => profile.saveName('wrong'), throwsStateError);
      expect(OwnerProfileStore(runtime.lease).name, null);
      expect(OwnerWorldSettings(runtime.lease).skipIntroAnimation, false);
      await switchTo(a);
      expect(OwnerProfileStore(runtime.lease).name, 'Synthetic A');
      expect(OwnerProfileStore(runtime.lease).photo, [1, 2, 3]);
      expect(OwnerWorldSettings(runtime.lease).skipIntroAnimation, true);
    },
  );
  test('delayed personal result is discarded after account switch', () async {
    final old = runtime.lease;
    final pending = Completer<String>();
    final result = old.load((_) => pending.future);
    await switchTo(b);
    pending.complete('private A');
    expect(await result, null);
  });
  test(
    'local publication preparation pins owner and rejects mismatched source',
    () async {
      await runtime.lease.put('drives', 'same', drive('same', 6000));
      final raw = fixture([6000]);
      final record = DriveTelemetryRecord(
        driveSessionId: 'same',
        dataVersion: raw.dataVersion,
        createdAt: raw.createdAt,
        points: raw.points,
        acquisitionMetadata: raw.acquisitionMetadata,
      );
      await runtime.lease.put('drive_telemetry', 'same', record);
      final segment = const PlanetSegmentBuilder()
          .build('same', record)
          .eligible
          .single;
      await runtime.lease.preparePublication('same', [segment]);
      expect(runtime.lease.publicationEntries('same'), hasLength(1));
      await runtime.lease.preparePublication('same', [segment]);
      expect(runtime.lease.publicationEntries('same'), hasLength(1));
      await switchTo(b);
      await runtime.lease.put('drives', 'same', drive('same', 7000));
      expect(runtime.lease.publicationEntries('same'), isEmpty);
      await runtime.lease.put('drives', 'other', drive('other', 7000));
      await expectLater(
        runtime.lease.preparePublication('other', [segment]),
        throwsStateError,
      );
    },
  );
  testWidgets(
    'ID-only cross-account detail fails before map/global storage initialization',
    (tester) async {
      await tester.runAsync(() async {
        await runtime.lease.put(
          'drives',
          'private-a',
          drive('private-a', 6000),
        );
        await switchTo(b);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OwnedDriveDetailScreen(
            lease: runtime.lease,
            driveId: 'private-a',
          ),
        ),
      );
      expect(find.byType(OwnerAccessUnavailable), findsOneWidget);
      expect(find.byType(DriveDetailScreen), findsNothing);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'direct route private subtree disappears immediately on revocation',
    (tester) async {
      final old = runtime.lease;
      await tester.pumpWidget(
        MaterialApp(
          home: LocalOwnerView(
            lease: old,
            builder: (_) => const Text('private-a'),
          ),
        ),
      );
      expect(find.text('private-a'), findsOneWidget);
      await tester.runAsync(() => switchTo(b));
      await tester.pump();
      expect(find.text('private-a'), findsNothing);
      expect(find.byType(OwnerAccessUnavailable), findsOneWidget);
    },
  );
  testWidgets(
    'scoped Home loads own profile without initialized global Hive or Supabase',
    (tester) async {
      await tester.runAsync(
        () => OwnerProfileStore(runtime.lease).saveName('Scoped Home A'),
      );
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(ownerLease: runtime.lease)),
      );
      await tester.pump();
      expect(find.textContaining('Scoped Home A'), findsWidgets);
      expect(tester.takeException(), null);
      await tester.runAsync(() => switchTo(b));
      await tester.pump();
      expect(find.textContaining('Scoped Home A'), findsNothing);
    },
  );
  testWidgets(
    'scoped profile shows account actions and excludes legacy profile fallback',
    (tester) async {
      await tester.runAsync(
        () => OwnerProfileStore(runtime.lease).saveName('Profile A'),
      );
      var legacyReads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsScreen(
            ownerLease: runtime.lease,
            profileLoader: () async {
              legacyReads++;
              throw StateError('legacy forbidden');
            },
            accountGateway: _AvailableGuestAccountGateway(),
          ),
        ),
      );
      await tester.pump();
      expect(legacyReads, 0);
      expect(find.text('Profile A'), findsOneWidget);
      expect(find.text('DriveIt Hesabı'), findsOneWidget);
      expect(find.text('Hesap Oluştur'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
      final loginButton = find.byKey(const ValueKey('driveit_account_login'));
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account_email')), findsOneWidget);
      expect(find.byKey(const ValueKey('account_password')), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('account_email'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.runAsync(() => switchTo(b));
      await tester.pump();
      expect(find.text('Profile A'), findsNothing);
    },
  );
  testWidgets(
    'guest Home profile route exposes and opens the separate read-only device archive',
    (tester) async {
      await tester.runAsync(() => switchTo(null));
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: runtime,
            legacyChild: const SizedBox.shrink(),
            deviceArchiveLoader: (lease) async {
              lease.requireCurrent();
              return DeviceDriveArchiveAccess(
                gate: runtime.gate,
                snapshot: DeviceDriveArchiveSnapshot.empty(),
                authorizer: _AcceptDeviceArchiveAuth(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(runtime.lease.owner.kind, GpsOwnerKind.guest);
      await tester.tap(find.byKey(const Key('home_profile_settings')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSettingsScreen), findsOneWidget);
      final archiveButton = find.byKey(const Key('profile_device_archive'));
      expect(archiveButton, findsOneWidget);
      expect(
        find.text('Önceki DriveIt sürüşlerin. Yalnızca bu cihazda saklanır.'),
        findsOneWidget,
      );
      await tester.ensureVisible(archiveButton);
      await tester.tap(archiveButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Cihaz arşivi • Salt okunur • Hiçbir hesaba aktarılmaz'),
        findsOneWidget,
      );
      expect(find.text('Kayıtlı eski sürüş yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Kayıtlı eski sürüş yok'))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(ProfileSettingsScreen))).pop();
      // Home has an intentional repeating presentation animation.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => switchTo(a));
      await tester.pump();
      await tester.tap(find.byKey(const Key('home_profile_settings')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(runtime.lease.owner.kind, GpsOwnerKind.account);
      expect(find.byKey(const Key('profile_device_archive')), findsOneWidget);
    },
  );
  testWidgets(
    'scoped publication never invokes legacy lookup; revoked state hides preview',
    (tester) async {
      final own = drive('same', 6000);
      await tester.runAsync(() => runtime.lease.put('drives', 'same', own));
      var remoteCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanetPublicationSection(
              drive: own,
              ownerLease: runtime.lease,
              existingLookup: () async {
                remoteCalls++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(remoteCalls, 0);
      expect(tester.takeException(), null);
      await tester.runAsync(() => switchTo(b));
      await tester.pump();
      expect(find.text('Kişisel yayın durumu erişime kapalı.'), findsOneWidget);
    },
  );
  testWidgets('controlled navigator leaves gate-off child untouched', (
    tester,
  ) async {
    final disabled = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.production,
      auth: auth,
      openStore: (_) => throw StateError('must not open'),
      driveInProgress: () async => false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OwnerPersonalNavigator(
          runtime: disabled,
          legacyChild: const Text('legacy unchanged'),
        ),
      ),
    );
    expect(find.text('legacy unchanged'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await disabled.close();
    disabled.dispose();
  });

  testWidgets(
    'normal owner World route exposes My World and real Planet entry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: runtime,
            legacyChild: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      Navigator.of(tester.element(find.byType(HomeScreen))).pushNamed('/world');
      await tester.pumpAndSettle();
      expect(find.byType(WorldModeSelectionScreen), findsOneWidget);
      expect(find.byKey(const Key('my_world_card')), findsOneWidget);
      expect(find.byKey(const Key('driveit_planet_card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'poster route is owner scoped and never builds the legacy screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: runtime,
            legacyChild: const Text('legacy'),
          ),
        ),
      );
      await tester.pump();
      Navigator.of(
        tester.element(find.byType(HomeScreen)),
      ).pushNamed('/posters');
      await tester.pumpAndSettle();
      expect(find.byType(PosterCenterScreen), findsOneWidget);
      expect(
        find.text('Henüz poster oluşturabileceğin bir sürüş yok.'),
        findsOneWidget,
      );
      expect(find.text('legacy'), findsNothing);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('standalone History revokes its cached rows on external Auth', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await runtime.lease.put('drives', 'same', drive('same', 6000));
      await runtime.lease.put('drive_names', 'same', 'History A secret');
    });
    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(ownerLease: runtime.lease)),
    );
    await tester.pump();
    expect(find.text('History A secret'), findsOneWidget);
    await tester.runAsync(() => switchTo(b));
    await tester.pump();
    expect(find.text('History A secret'), findsNothing);
    expect(find.byType(OwnerAccessUnavailable), findsOneWidget);
  });

  testWidgets(
    'entire personal navigator rebuilds B and restores A profile on return',
    (tester) async {
      await tester.runAsync(
        () => OwnerProfileStore(runtime.lease).saveName('Home owner A'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: runtime,
            legacyChild: const Text('legacy'),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Home owner A'), findsWidgets);
      await tester.runAsync(() => switchTo(b));
      await tester.pump();
      expect(find.textContaining('Home owner A'), findsNothing);
      await tester.runAsync(
        () => OwnerProfileStore(runtime.lease).saveName('Home owner B'),
      );
      await tester.runAsync(() => switchTo(a));
      await tester.pump();
      expect(find.textContaining('Home owner A'), findsWidgets);
      expect(find.textContaining('Home owner B'), findsNothing);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'reusing a profile State with another lease fails closed instead of showing cached A',
    (tester) async {
      await tester.runAsync(
        () => OwnerProfileStore(runtime.lease).saveName('Cached A'),
      );
      const key = ValueKey('same-route-state');
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsScreen(key: key, ownerLease: runtime.lease),
        ),
      );
      await tester.pump();
      expect(find.text('Cached A'), findsOneWidget);
      await tester.runAsync(() => switchTo(b));
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsScreen(key: key, ownerLease: runtime.lease),
        ),
      );
      await tester.pump();
      expect(find.text('Cached A'), findsNothing);
      expect(find.byType(OwnerAccessUnavailable), findsOneWidget);
    },
  );
}
