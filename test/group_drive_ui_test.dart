import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_map.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'group_drive_map_fake.dart';
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
  }

  testWidgets(
    'real Home navigation: A creates, B joins, both participants update, member leaves, admin ends',
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
        within('deviceA', find.byKey(const Key('group_map_workspace'))),
        findsOneWidget,
      );
      expect(within('deviceA', find.text('Yönetici • KAPALI')), findsOneWidget);
      final code = tester
          .widget<SelectableText>(
            within('deviceA', find.byKey(const Key('group_invite_code'))),
          )
          .data!;
      await click(
        tester,
        within('deviceB', find.byKey(const Key('home_group_card'))),
      );
      await tester.enterText(
        within('deviceB', find.byKey(const Key('group_invite_input'))),
        code,
      );
      await click(
        tester,
        within('deviceB', find.byKey(const Key('group_join'))),
      );
      for (final device in ['deviceA', 'deviceB']) {
        expect(within(device, find.text('Katılımcılar 2/10')), findsOneWidget);
        expect(within(device, find.text('Hesap A')), findsOneWidget);
        expect(within(device, find.text('Hesap B')), findsOneWidget);
        expect(
          within(device, find.textContaining('Canlı konum paylaşımı kapalı')),
          findsOneWidget,
        );
      }
      expect(
        within('deviceB', find.byKey(const Key('group_end'))),
        findsNothing,
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_extend'))),
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_extend'))),
      );
      expect(
        tester
            .widget<TextButton>(
              within('deviceA', find.byKey(const Key('group_extend'))),
            )
            .onPressed,
        null,
      );
      await click(
        tester,
        within('deviceB', find.byKey(const Key('group_leave'))),
      );
      await tester.tap(find.byKey(const Key('group_confirm')));
      await frames(tester);
      expect(within('deviceA', find.text('Katılımcılar 1/10')), findsOneWidget);
      expect(
        within('deviceB', find.byKey(const Key('group_create'))),
        findsOneWidget,
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_end'))),
      );
      await tester.tap(find.byKey(const Key('group_confirm')));
      await frames(tester);
      expect(
        within('deviceA', find.text('Grup sonlandırıldı')),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'owner A B A revokes group screen/cache and returns to own membership',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: ra,
            legacyChild: const Text('legacy'),
            initialRoute: '/group',
            groupDriveServiceForTesting: service,
          ),
        ),
      );
      await frames(tester);
      await click(tester, find.byKey(const Key('group_create')));
      expect(find.text('Hesap A'), findsOneWidget);
      await tester.runAsync(() async {
        aa.emit(b);
        await ra.settled;
      });
      await frames(tester);
      expect(find.text('Hesap A'), findsNothing);
      expect(find.byKey(const Key('group_invite_code')), findsNothing);
      await click(tester, find.byKey(const Key('group_create')));
      expect(find.text('Hesap B'), findsOneWidget);
      await tester.runAsync(() async {
        aa.emit(a);
        await ra.settled;
      });
      await frames(tester);
      expect(find.text('Hesap A'), findsOneWidget);
      expect(find.text('Hesap B'), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late Future after owner change never restores the old group page',
    (tester) async {
      await service.close();
      final waiting = Completer<void>();
      service = FakeGroupDriveService(beforeRequest: (_) => waiting.future);
      await tester.pumpWidget(MaterialApp(home: app(ra)));
      await click(tester, find.byKey(const Key('home_group_card')));
      await tester.runAsync(() async {
        aa.emit(b);
        await ra.settled;
      });
      waiting.complete();
      await frames(tester);
      expect(find.byType(GroupDriveScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'expiry refresh rejects joins; malformed invite and offline state are visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: ra,
            legacyChild: const Text('legacy'),
            initialRoute: '/group',
            groupDriveServiceForTesting: service,
          ),
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
      final invite = (await service.forOwner(ra.lease).current())!.invite;
      now = now.add(const Duration(hours: 12));
      await tester.pump(const Duration(hours: 12));
      await frames(tester);
      expect(find.text('Grubun süresi doldu'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('group_invite_input')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(GroupDriveScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('group_invite_input')),
        invite.code,
      );
      await click(tester, find.byKey(const Key('group_join')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('group_error')),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(GroupDriveScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.text('Grup sona erdi; katılım ve uzatma kapalı.'),
        findsOneWidget,
      );
      service.available = false;
      await tester.scrollUntilVisible(
        find.byKey(const Key('group_create')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(GroupDriveScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await click(tester, find.byKey(const Key('group_create')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('group_error')),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(GroupDriveScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('Test servisine ulaşılamadı'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'no injected simulator leaves production-style Home entry unchanged',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(ownerLease: ra.lease)),
      );
      await click(tester, find.byKey(const Key('home_group_card')));
      expect(find.text('Grup Sürüşü yakında'), findsOneWidget);
      expect(find.byType(GroupDriveScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'UI consent -> synthetic markers -> focus -> pause resume stop and leave',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
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
      final ca = service.forOwner(ra.lease);
      final group = (await ca.current())!;
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
      GoogleMap map(String device) =>
          tester.widget<GoogleMap>(within(device, find.byType(GoogleMap)));
      expect(map('deviceA').markers, isEmpty);
      expect(map('deviceA').myLocationEnabled, false);
      expect(map('deviceA').myLocationButtonEnabled, false);
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_share_start'))),
      );
      await tester.tap(within('deviceA', find.text('Vazgeç')));
      await frames(tester);
      expect(
        (await ca.current())!.members.first.sharingStatus,
        GroupSharingStatus.off,
      );
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_share_start'))),
      );
      await tester.tap(
        within('deviceA', find.byKey(const Key('group_consent_confirm'))),
      );
      await frames(tester);
      await click(
        tester,
        within('deviceA', find.byKey(const Key('group_send_synthetic'))),
      );
      expect(map('deviceA').markers, hasLength(1));
      expect(
        map('deviceA').markers.single.icon.toJson(),
        BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ).toJson(),
      );
      const c = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      final authC = TestAuth()..userId = c;
      final rc = await tester.runAsync(() => runtime(authC, 'deviceC'));
      try {
        final cc = service.forOwner(rc!.lease);
        await cc.join(group.invite);
        final gc = await cc.startSharing(group.id, consent: true);
        await cc.publishSynthetic(
          gc,
          GroupSyntheticLocation(
            latitude: 10.5,
            longitude: 20.5,
            recordedAt: now,
            sequence: 1,
          ),
        );
        await frames(tester);
        expect(map('deviceA').markers, hasLength(2)); // B never opted in.
        expect(
          map(
            'deviceA',
          ).markers.any((m) => m.infoWindow.title!.startsWith('Hesap B')),
          false,
        );
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_share_start'))),
        );
        await tester.tap(
          within('deviceB', find.byKey(const Key('group_consent_confirm'))),
        );
        await frames(tester);
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_send_synthetic'))),
        );
        expect(map('deviceA').markers, hasLength(3));
        final markerB = map(
          'deviceA',
        ).markers.singleWhere((m) => m.infoWindow.title == 'Hesap B');
        expect(markerB.infoWindow.snippet, contains('Sentetik'));
        markerB.onTap!();
        await frames(tester);
        expect(
          within('deviceA', find.text('Seçili: Hesap B • Sentetik')),
          findsOneWidget,
        );
        expect(
          mapFake.calls.any((call) => call.method == 'camera#animate'),
          true,
        );
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_share_pause'))),
        );
        expect(map('deviceA').markers, hasLength(2));
        expect(
          within('deviceB', find.text('Sentetik paylaşım: DURAKLATILDI')),
          findsOneWidget,
        );
        expect(
          within('deviceB', find.byKey(const Key('group_send_synthetic'))),
          findsNothing,
        );
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_share_start'))),
        );
        await tester.tap(
          within('deviceB', find.byKey(const Key('group_consent_confirm'))),
        );
        await frames(tester);
        expect(map('deviceA').markers, hasLength(2)); // No old point on resume.
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_send_synthetic'))),
        );
        expect(map('deviceA').markers, hasLength(3));
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_share_stop'))),
        );
        expect(map('deviceA').markers, hasLength(2));
        await click(
          tester,
          within('deviceB', find.byKey(const Key('group_leave'))),
        );
        await tester.tap(find.byKey(const Key('group_confirm')));
        await frames(tester);
        expect(
          (await ca.current())!.members.any((m) => m.accountId == b),
          false,
        );
        expect(map('deviceA').markers, hasLength(2));
        await click(
          tester,
          within('deviceA', find.byKey(const Key('group_end'))),
        );
        await tester.tap(find.byKey(const Key('group_confirm')));
        await frames(tester);
        expect(map('deviceA').markers, isEmpty);
        expect(tester.takeException(), null);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await rc!.close();
          rc.dispose();
          await authC.events.close();
        });
      }
    },
  );

  testWidgets(
    'marker freshness fades at 15/30 seconds and removes after five minutes',
    (tester) async {
      final ca = service.forOwner(ra.lease);
      final group = await ca.create();
      final grant = await ca.startSharing(group.id, consent: true);
      await ca.publishSynthetic(
        grant,
        GroupSyntheticLocation(
          latitude: 10,
          longitude: 20,
          recordedAt: now,
          sequence: 1,
        ),
      );
      final snapshot = (await ca.current())!;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 400,
            child: GroupDriveMap(lease: ra.lease, group: snapshot),
          ),
        ),
      );
      await frames(tester);
      GoogleMap map() => tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map().markers.single.alpha, 1);
      await tester.pump(const Duration(seconds: 16));
      expect(map().markers.single.alpha, .55);
      await tester.pump(const Duration(seconds: 15));
      expect(map().markers.single.alpha, .3);
      await tester.pump(const Duration(seconds: 270));
      expect(map().markers, isEmpty);
      expect(snapshot.members, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'busy pause and owner switch reject delayed UI publication and remove the map',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entered = Completer<void>(), release = Completer<void>();
      await service.close();
      service = FakeGroupDriveService(
        clock: () => now,
        beforeRequest: (operation) async {
          if (operation == 'publishSynthetic') {
            entered.complete();
            await release.future;
          }
        },
      );
      await tester.pumpWidget(MaterialApp(home: app(ra)));
      await click(tester, find.byKey(const Key('home_group_card')));
      await click(tester, find.byKey(const Key('group_create')));
      await click(tester, find.byKey(const Key('group_share_start')));
      await tester.tap(find.byKey(const Key('group_consent_confirm')));
      await frames(tester);
      await click(tester, find.byKey(const Key('group_send_synthetic')));
      await entered.future;
      await click(tester, find.byKey(const Key('group_share_pause')));
      expect(find.text('Sentetik paylaşım: DURAKLATILDI'), findsOneWidget);
      await tester.runAsync(() async {
        aa.emit(b);
        await ra.settled;
      });
      release.complete();
      await frames(tester);
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(await service.forOwner(ra.lease).current(), null);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('group expiry clears consented points from the real map widget', (
    tester,
  ) async {
    final client = service.forOwner(ra.lease);
    final group = await client.create();
    final grant = await client.startSharing(group.id, consent: true);
    await client.publishSynthetic(
      grant,
      GroupSyntheticLocation(
        latitude: 10,
        longitude: 20,
        recordedAt: now,
        sequence: 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDriveScreen(lease: ra.lease, service: service),
      ),
    );
    await frames(tester);
    expect(
      tester.widget<GoogleMap>(find.byType(GoogleMap)).markers,
      hasLength(1),
    );
    now = group.expiresAt;
    await tester.pump(const Duration(hours: 12));
    await frames(tester);
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).markers, isEmpty);
    expect(
      (await client.current())!.members.single.sharingStatus,
      GroupSharingStatus.off,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), null);
  });
}
