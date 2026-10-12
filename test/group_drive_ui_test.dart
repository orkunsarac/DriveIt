import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(within('deviceA', find.text('Yönetici')), findsOneWidget);
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
      await tester.enterText(
        find.byKey(const Key('group_invite_input')),
        invite.code,
      );
      await click(tester, find.byKey(const Key('group_join')));
      expect(
        find.text('Grup sona erdi; katılım ve uzatma kapalı.'),
        findsOneWidget,
      );
      service.available = false;
      await click(tester, find.byKey(const Key('group_create')));
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
}
