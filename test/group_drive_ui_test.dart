import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_map.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'group_drive_map_fake.dart';
import 'group_gps_sharing_test.dart'
    show FakeGroupGps, FakeBackgroundGroupGps, groupPosition;
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/group_drive/group_drive_screen.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/widgets/owner_personal_navigator.dart';

import 'local_owner_integration_test.dart' show TestAuth, a, b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FakeGroupDriveService service;
  late LocalOwnerLifecycle ra;
  late LocalOwnerLifecycle rb;
  late TestAuth aa;
  late TestAuth ab;
  late DateTime now;
  late maps.GoogleMapsFlutterPlatform oldMaps;
  late GroupMapFake mapFake;
  Future<LocalOwnerLifecycle> runtime(TestAuth auth, String device) async {
    final r = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) => OwnerScopedLocalStore.open(
        root: '${root.path}/$device',
        owner: owner,
      ),
      driveInProgress: () async => false,
    );
    await r.start();
    return r;
  }

  setUp(() async {
    oldMaps = maps.GoogleMapsFlutterPlatform.instance;
    mapFake = GroupMapFake();
    maps.GoogleMapsFlutterPlatform.instance = mapFake;
    root = await Directory.systemTemp.createTemp('driveit_group_ui_');
    aa = TestAuth();
    ab = TestAuth()..userId = b;
    ra = await runtime(aa, 'deviceA');
    rb = await runtime(ab, 'deviceB');
    now = DateTime.now().toUtc();
    service = FakeGroupDriveService(
      clock: () => now,
      displayNames: {a: 'Hesap A', b: 'Hesap B'},
    );
  });
  tearDown(() async {
    await service.close();
    await ra.close();
    ra.dispose();
    await rb.close();
    rb.dispose();
    await aa.events.close();
    await ab.events.close();
    await root.delete(recursive: true);
    mapFake.clearHandlers();
    maps.GoogleMapsFlutterPlatform.instance = oldMaps;
  });
  Widget app(LocalOwnerLifecycle r) => OwnerPersonalNavigator(
    runtime: r,
    legacyChild: const Text('legacy'),
    groupDriveServiceForTesting: service,
  );
  Finder within(String device, Finder target) =>
      find.descendant(of: find.byKey(Key(device)), matching: target);
  Future<void> frames(WidgetTester tester) async {
    // Home has ongoing artwork animations; settling the entire app cannot
    // complete. Render the MaterialPageRoute's actual 300 ms transition and
    // flush service microtasks instead of waiting for every ticker to stop.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> click(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await frames(tester);
    // Existing scenarios explicitly choose not to share at entry. Approval
    // behavior is exercised separately below with the real dialog controls.
    final without = find.byKey(const Key('group_entry_consent_without'));
    if (without.evaluate().isNotEmpty) {
      await tester.tap(without);
      await frames(tester);
    }
  }

  testWidgets(
    'entry approval waits for lobby start; pause/resume reuses this membership consent',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final source = FakeGroupGps();
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(
            lease: ra.lease,
            service: service,
            gpsSource: source,
          ),
        ),
      );
      await frames(tester);
      await tester.tap(find.byKey(const Key('group_create')));
      await frames(tester);
      expect(find.text('Konumumu paylaşarak devam et'), findsOneWidget);
      expect(find.text('Konum paylaşmadan devam et'), findsOneWidget);
      await click(tester, find.byKey(const Key('group_entry_consent_share')));
      expect(find.byKey(const Key('group_lobby')), findsOneWidget);
      expect(source.requests, 0);
      expect(source.opens, 0);
      await click(tester, find.byKey(const Key('group_start_ride')));
      expect(source.opens, 1);
      expect(find.byKey(const Key('group_consent_confirm')), findsNothing);
      await click(tester, find.byKey(const Key('group_share_pause')));
      await click(tester, find.byKey(const Key('group_share_start')));
      expect(source.opens, 2);
      expect(find.byKey(const Key('group_consent_confirm')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      await source.stream.close();
    },
  );

  testWidgets('running join shares only on approval and rejoin asks again', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final admin = service.forOwner(ra.lease);
    final group = await admin.create();
    await admin.startRide(group.id);
    final source = FakeGroupGps();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDriveScreen(
          lease: rb.lease,
          service: service,
          gpsSource: source,
        ),
      ),
    );
    await frames(tester);
    await tester.enterText(
      find.byKey(const Key('group_invite_input')),
      group.invite.code,
    );
    await tester.ensureVisible(find.byKey(const Key('group_join')));
    await tester.tap(find.byKey(const Key('group_join')));
    await frames(tester);
    await click(tester, find.byKey(const Key('group_entry_consent_share')));
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(source.opens, 1);
    await click(tester, find.byKey(const Key('group_leave')));
    await click(tester, find.byKey(const Key('group_confirm')));
    expect(source.cancels, 1);
    await tester.enterText(
      find.byKey(const Key('group_invite_input')),
      group.invite.code,
    );
    await tester.ensureVisible(find.byKey(const Key('group_join')));
    await tester.tap(find.byKey(const Key('group_join')));
    await frames(tester);
    expect(find.byKey(const Key('group_entry_consent_share')), findsOneWidget);
    await click(tester, find.byKey(const Key('group_entry_consent_without')));
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(source.opens, 1);
    expect(find.byKey(const Key('group_share_start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    await source.stream.close();
  });

  testWidgets(
    'Home entry opens lobby; admin start moves both devices without GPS consent',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: KeyedSubtree(key: const Key('deviceA'), child: app(ra)),
              ),
              Expanded(
                child: KeyedSubtree(key: const Key('deviceB'), child: app(rb)),
              ),
            ],
          ),
        ),
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('home_group_card'))),
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_create'))),
      );
      expect(
        within('deviceA', find.byKey(const Key('group_lobby'))),
        findsOneWidget,
      );
      expect(find.byType(GoogleMap), findsNothing);
      final group = (await service.forOwner(ra.lease).current())!;
      expect(group.phase, GroupRidePhase.lobby);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_invite_copy'))),
      );
      expect(copied, group.invite.code);
      expect(
        within('deviceA', find.text('Davet kodu kopyalandı')),
        findsOneWidget,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      await click(
        tester,
        within('deviceB', find.byKey(const Key('home_group_card'))),
      );
      await tester.enterText(
        within('deviceB', find.byKey(const Key('group_invite_input'))),
        group.invite.code,
      );
      await click(
        tester,
        within('deviceB', find.byKey(const Key('group_join'))),
      );
      expect(
        within('deviceB', find.byKey(const Key('group_lobby'))),
        findsOneWidget,
      );
      expect(
        within('deviceB', find.byKey(const Key('group_start_ride'))),
        findsNothing,
      );
      expect(find.text('Katılımcılar 2/10'), findsNWidgets(2));
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_start_ride'))),
      );
      expect(find.byType(GoogleMap), findsNWidgets(2));
      expect(find.byKey(const Key('group_lobby')), findsNothing);
      expect(
        (await service.forOwner(rb.lease).current())!.members.every(
          (m) => m.sharingStatus == GroupSharingStatus.off,
        ),
        isTrue,
      );
      expect(find.byKey(const Key('group_share_start')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'lobby invite share uses the real invite link without starting GPS',
    (tester) async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      const channel = MethodChannel('driveit/group_invite');
      String? shared;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shared = (call.arguments as Map)['link'] as String;
        return null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(lease: ra.lease, service: service),
        ),
      );
      await frames(tester);
      await click(tester, find.byKey(const Key('group_invite_share')));
      expect(shared, group.invite.link.toString());
      expect(
        (await client.current())!.members.single.sharingStatus,
        GroupSharingStatus.off,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'running join goes directly to full-screen map and preserves map gestures',
    (tester) async {
      final admin = service.forOwner(ra.lease);
      final group = await admin.create();
      await admin.startRide(group.id);
      await tester.pumpWidget(MaterialApp(home: app(rb)));
      await click(tester, find.byKey(const Key('home_group_card')));
      await tester.enterText(
        find.byKey(const Key('group_invite_input')),
        group.invite.code,
      );
      await click(tester, find.byKey(const Key('group_join')));
      expect(find.byKey(const Key('group_lobby')), findsNothing);
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
        map.gestureRecognizers.any((r) => r.type == EagerGestureRecognizer),
        isTrue,
      );
      expect(
        tester.getSize(find.byType(GoogleMap)).height,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      expect(find.byKey(const Key('group_go_to_drive')), findsOneWidget);
      expect(map.myLocationEnabled, isFalse);
      await tester.tap(find.byKey(const Key('group_settings')));
      await frames(tester);
      expect(find.byKey(const Key('group_end')), findsNothing);
      expect(find.byKey(const Key('group_extend')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Sürüşe Git is always available and opens drive without starting it',
    (tester) async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      await client.startRide(group.id);
      var openedDrive = false;
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(
            lease: ra.lease,
            service: service,
            onGoToDrive: () => openedDrive = true,
          ),
        ),
      );
      await frames(tester);
      final own = (await client.current())!.members.single;
      expect(own.sharingStatus, GroupSharingStatus.off);
      expect(find.byKey(const Key('group_go_to_drive')), findsOneWidget);
      await click(tester, find.byKey(const Key('group_go_to_drive')));
      expect(openedDrive, isTrue);
      expect(
        (await client.current())!.members.single.sharingStatus,
        GroupSharingStatus.off,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Sürüşe Git returns to existing active drive instead of opening a new one',
    (tester) async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      await client.startRide(group.id);
      var returnedToActive = false;
      var openedNewDrive = false;
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(
            lease: ra.lease,
            service: service,
            onReturnToDrive: () => returnedToActive = true,
            onGoToDrive: () => openedNewDrive = true,
          ),
        ),
      );
      await frames(tester);
      await click(tester, find.byKey(const Key('group_go_to_drive')));
      expect(returnedToActive, isTrue);
      expect(openedNewDrive, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'settings retain admin extension and end; leaving requires confirmation',
    (tester) async {
      final admin = service.forOwner(ra.lease);
      final group = await admin.create();
      await service.forOwner(rb.lease).join(group.invite);
      await admin.startRide(group.id);
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(lease: ra.lease, service: service),
        ),
      );
      await frames(tester);
      for (var i = 0; i < 2; i++) {
        await click(tester, find.byKey(const Key('group_settings')));
        await click(tester, find.byKey(const Key('group_extend')));
      }
      expect((await admin.current())!.extensionCount, 2);
      await click(tester, find.byKey(const Key('group_leave')));
      await tester.tap(find.text('Vazgeç'));
      await frames(tester);
      expect((await admin.current())!.members, hasLength(2));
      await click(tester, find.byKey(const Key('group_settings')));
      await click(tester, find.byKey(const Key('group_end')));
      await click(tester, find.byKey(const Key('group_confirm')));
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.text('Grup sonlandırıldı'), findsOneWidget);
      expect((await service.forOwner(rb.lease).current())!.isActive, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'owner change revokes UI; delayed request cannot repaint previous owner',
    (tester) async {
      final client = service.forOwner(ra.lease);
      await client.create();
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: ra,
            legacyChild: const SizedBox(),
            initialRoute: '/group',
            groupDriveServiceForTesting: service,
          ),
        ),
      );
      await frames(tester);
      expect(find.text('Hesap A'), findsOneWidget);
      await tester.runAsync(() async {
        aa.emit(b);
        await ra.settled;
      });
      await frames(tester);
      expect(find.text('Hesap A'), findsNothing);
      expect(find.byKey(const Key('group_invite_code')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.close();
      final gate = Completer<void>();
      service = FakeGroupDriveService(beforeRequest: (_) => gate.future);
      await tester.pumpWidget(MaterialApp(home: app(ra)));
      await click(tester, find.byKey(const Key('home_group_card')));
      await tester.runAsync(() async {
        aa.emit(a);
        await ra.settled;
      });
      gate.complete();
      await frames(tester);
      expect(find.byType(GroupDriveScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'malformed invite, offline errors and expiry are visible in entry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(lease: ra.lease, service: service),
        ),
      );
      await frames(tester);
      await tester.enterText(
        find.byKey(const Key('group_invite_input')),
        'invalid',
      );
      await click(tester, find.byKey(const Key('group_join')));
      expect(find.text('Davet kodu veya bağlantısı geçersiz.'), findsOneWidget);
      await click(tester, find.byKey(const Key('group_create')));
      now = now.add(const Duration(hours: 12));
      await tester.pump(const Duration(hours: 12));
      await frames(tester);
      expect(find.text('Grubun süresi doldu'), findsOneWidget);
      service.available = false;
      await click(tester, find.byKey(const Key('group_create')));
      expect(find.textContaining('Grup servisine ulaşılamadı'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'GPS consent, pause, resume and foreground-only background revocation',
    (tester) async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      await client.startRide(group.id);
      final source = FakeGroupGps();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(
            lease: ra.lease,
            service: service,
            gpsSource: source,
          ),
        ),
      );
      await frames(tester);
      expect(source.opens, 0);
      await click(tester, find.byKey(const Key('group_share_start')));
      await click(tester, find.text('Vazgeç'));
      expect(source.opens, 0);
      await click(tester, find.byKey(const Key('group_share_start')));
      await click(tester, find.byKey(const Key('group_consent_confirm')));
      expect(source.opens, 1);
      source.stream.add(groupPosition(now));
      await frames(tester);
      GoogleMap map() => tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map().markers, hasLength(1));
      await click(tester, find.byKey(const Key('group_share_pause')));
      expect(map().markers, isEmpty);
      source.stream.add(groupPosition(now.add(const Duration(seconds: 1))));
      await frames(tester);
      expect(map().markers, isEmpty);
      await click(tester, find.byKey(const Key('group_share_start')));
      expect(find.byKey(const Key('group_consent_confirm')), findsNothing);
      expect(source.opens, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await frames(tester);
      expect(source.cancels, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(source.opens, 2);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      await source.stream.close();
    },
  );

  testWidgets(
    'background consent and navigator session survive Home and reopen without a second consumer',
    (tester) async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      await client.startRide(group.id);
      final source = FakeBackgroundGroupGps();
      final nav = GlobalKey<NavigatorState>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: ra,
            legacyChild: const SizedBox(),
            navigatorKey: nav,
            groupDriveServiceForTesting: service,
            groupGpsSourceFactory: () => source,
          ),
        ),
      );
      await click(tester, find.byKey(const Key('home_group_card')));
      await click(tester, find.byKey(const Key('group_share_start')));
      await click(tester, find.byKey(const Key('group_background_consent')));
      await click(tester, find.byKey(const Key('group_consent_confirm')));
      expect(source.opens, 1);
      await click(tester, find.byKey(const Key('group_back_home')));
      expect(source.cancels, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      source.stream.add(groupPosition(now));
      await frames(tester);
      expect((await client.current())!.members.single.location, isNotNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await click(tester, find.byKey(const Key('home_group_card')));
      expect(source.opens, 1);
      await click(tester, find.byKey(const Key('group_share_pause')));
      expect(source.cancels, 1);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      await source.stream.close();
    },
  );

  testWidgets(
    'empty real map and expiry never imply live synthetic coordinates',
    (tester) async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      await client.startRide(group.id);
      final grant = await client.startSharing(group.id, consent: true);
      Future<void> render() async {
        await tester.pumpWidget(
          MaterialApp(
            home: GroupDriveMap(
              lease: ra.lease,
              group: (await client.current())!,
              isSimulation: false,
            ),
          ),
        );
        await frames(tester);
      }

      await render();
      expect(find.text('Henüz canlı konum alınmadı'), findsNothing);
      expect(find.textContaining('Sentetik test'), findsNothing);
      await client.publishGps(
        grant,
        GroupGpsLocation(
          latitude: 10,
          longitude: 20,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      await render();
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).markers,
        hasLength(1),
      );
      expect(find.text('Canlı GPS • 1 görünür üye'), findsNothing);
      expect(find.byKey(const Key('group_marker_count')), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      await render(); // An unchanged UI/snapshot cannot refresh the fix.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).markers, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'camera follows selected member, manual gesture cancels, fit all ignores paused member',
    (tester) async {
      final ca = service.forOwner(ra.lease), cb = service.forOwner(rb.lease);
      final group = await ca.create();
      await ca.startRide(group.id);
      await cb.join(group.invite);
      final ga = await ca.startSharing(group.id, consent: true);
      final gb = await cb.startSharing(group.id, consent: true);
      await ca.publishGps(
        ga,
        GroupGpsLocation(
          latitude: 10,
          longitude: 20,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      await cb.publishGps(
        gb,
        GroupGpsLocation(
          latitude: 10.01,
          longitude: 20.01,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      final camera = GroupMapCamera();
      Future<void> render() async {
        await tester.pumpWidget(
          MaterialApp(
            home: GroupDriveMap(
              lease: ra.lease,
              group: (await ca.current())!,
              isSimulation: false,
              camera: camera,
            ),
          ),
        );
        await frames(tester);
      }

      await render();
      final snapshot = (await ca.current())!;
      camera.follow(snapshot.members.last.membershipId);
      await frames(tester);
      // Native move-start may arrive after the animateCamera Future resolves.
      // It must not cancel a programmatic follow operation.
      tester.widget<GoogleMap>(find.byType(GoogleMap)).onCameraMoveStarted!();
      final before = mapFake.calls
          .where((c) => c.method == 'camera#animate')
          .length;
      now = now.add(const Duration(seconds: 2));
      await cb.publishGps(
        gb,
        GroupGpsLocation(
          latitude: 10.011,
          longitude: 20.011,
          recordedAt: now,
          sequence: 2,
          accuracyMeters: 5,
        ),
      );
      await render();
      expect(
        mapFake.calls.where((c) => c.method == 'camera#animate').length,
        greaterThan(before),
      );
      tester.widget<GoogleMap>(find.byType(GoogleMap)).onCameraIdle!();
      tester.widget<GoogleMap>(find.byType(GoogleMap)).onCameraMoveStarted!();
      expect(camera.membershipId, isNull);
      final manual = mapFake.calls
          .where((c) => c.method == 'camera#animate')
          .length;
      now = now.add(const Duration(seconds: 2));
      await cb.publishGps(
        gb,
        GroupGpsLocation(
          latitude: 10.012,
          longitude: 20.012,
          recordedAt: now,
          sequence: 3,
          accuracyMeters: 5,
        ),
      );
      await render();
      expect(
        mapFake.calls.where((c) => c.method == 'camera#animate').length,
        manual,
      );
      await cb.pauseSharing(group.id);
      await render();
      camera.showAll();
      await frames(tester);
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).markers,
        hasLength(1),
      );
      expect(
        mapFake.calls.where((c) => c.method == 'camera#animate').length,
        greaterThan(manual),
      );
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );

  testWidgets(
    'participant avatar selection follows that member and highlights avatar',
    (tester) async {
      final ca = service.forOwner(ra.lease);
      final cb = service.forOwner(rb.lease);
      final group = await ca.create();
      await ca.startRide(group.id);
      await cb.join(group.invite);
      final ga = await ca.startSharing(group.id, consent: true);
      final gb = await cb.startSharing(group.id, consent: true);
      await ca.publishGps(
        ga,
        GroupGpsLocation(
          latitude: 10,
          longitude: 20,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      await cb.publishGps(
        gb,
        GroupGpsLocation(
          latitude: 10.01,
          longitude: 20.01,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(lease: ra.lease, service: service),
        ),
      );
      await frames(tester);
      final peer = (await ca.current())!.members.firstWhere(
        (member) => member.accountId == rb.lease.owner.userId,
      );
      final callsBefore = mapFake.calls
          .where((call) => call.method == 'camera#animate')
          .length;
      await click(
        tester,
        find.byKey(ValueKey('group_profile_${peer.membershipId}')),
      );
      expect(
        find.byKey(ValueKey('group_profile_selected_${peer.membershipId}')),
        findsOneWidget,
      );
      expect(
        mapFake.calls.where((call) => call.method == 'camera#animate').length,
        greaterThan(callsBefore),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ten member panel pins self and scrolls other avatars on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ca = service.forOwner(ra.lease);
      final group = await ca.create();
      await ca.startRide(group.id);
      await service.forOwner(rb.lease).join(group.invite);
      final extra = <LocalOwnerLifecycle>[], auths = <TestAuth>[];
      try {
        for (var i = 0; i < 8; i++) {
          final auth = TestAuth()
            ..userId =
                '00000000-0000-4000-8000-${(i + 10).toString().padLeft(12, '0')}';
          auths.add(auth);
          final r = (await tester.runAsync(() => runtime(auth, 'extra$i')))!;
          extra.add(r);
          await service.forOwner(r.lease).join(group.invite);
        }
        await tester.pumpWidget(
          MaterialApp(
            home: GroupDriveScreen(lease: ra.lease, service: service),
          ),
        );
        await frames(tester);
        final own = (await ca.current())!.members.first;
        final ownFinder = find.byKey(
          ValueKey('group_profile_${own.membershipId}'),
        );
        final ownX = tester.getTopLeft(ownFinder).dx;
        await tester.drag(
          find.byKey(const Key('group_other_profiles')),
          const Offset(-450, 0),
        );
        await frames(tester);
        expect(tester.getTopLeft(ownFinder).dx, ownX);
        expect(find.text('10/10'), findsOneWidget);
        final controls = [
          'group_back_home',
          'group_share_start',
          'group_go_to_drive',
          'group_leave',
          'group_settings',
        ].map((key) => tester.getRect(find.byKey(Key(key)))).toList();
        for (var i = 1; i < controls.length; i++) {
          expect(controls[i].width, closeTo(controls.first.width, .01));
          expect(controls[i].center.dy, controls.first.center.dy);
          expect(
            controls[i].left,
            greaterThanOrEqualTo(controls[i - 1].right - .01),
          );
        }
        for (final label in ['Geri', 'Devam', 'Sürüş', 'Çık', 'Ayarlar']) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.drag(
          find.byKey(const Key('group_participant_panel')),
          const Offset(0, -450),
        );
        await frames(tester);
        expect(
          find.byKey(const Key('group_participant_panel')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await tester.runAsync(() async {
          for (final r in extra) {
            await r.close();
            r.dispose();
          }
          for (final auth in auths) {
            await auth.events.close();
          }
        });
      }
    },
  );

  testWidgets(
    'Home without service remains gated; Guest cannot enter real membership',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(ownerLease: ra.lease)),
      );
      await click(tester, find.byKey(const Key('home_group_card')));
      expect(find.text('Grup Sürüşü yakında'), findsOneWidget);
      final guestAuth = TestAuth()..userId = null;
      final guest = (await tester.runAsync(() => runtime(guestAuth, 'guest')))!;
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDriveScreen(lease: guest.lease, service: service),
        ),
      );
      expect(find.text('Grup Sürüşü için hesap gerekli.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await guest.close();
        guest.dispose();
        await guestAuth.events.close();
      });
    },
  );
}
