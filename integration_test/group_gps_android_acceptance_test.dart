import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/features/group_drive/group_drive_screen.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../test/local_owner_integration_test.dart' show TestAuth, a, b;
import '../test/owned_drive_delivery_test.dart' show DeliveryMaps;

/// Physical GPS acceptance runs only inside the explicitly isolated release
/// test APK. The real Android source reaches only the in-memory fake group;
/// the map platform is replaced so coordinates never go to map tile servers.
void main() {
  debugPrint('A55_GROUP_GPS_CHECKPOINT: test main entered');
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  debugPrint('A55_GROUP_GPS_CHECKPOINT: integration binding ready');

  testWidgets(
    'isolated release real GPS consent, pause, resume and owner fence',
    (tester) async {
      debugPrint('A55_GROUP_GPS_CHECKPOINT: testWidgets body entered');
      expect(SupabaseBootstrap.isIsolatedAndroidTest, isTrue);
      expect(await SupabaseBootstrap.initializeIfConfigured(), isFalse);

      final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      final root = await (await getApplicationSupportDirectory()).createTemp(
        'driveit_owner_test_group_gps_acceptance_',
      );
      final archiveHive = HiveImpl()
        ..init('${root.path}/legacy')
        ..registerAdapter(DriveSessionAdapter())
        ..registerAdapter(RoutePointAdapter());
      final archiveBox = await archiveHive.openBox<DriveSession>('drives');
      await archiveBox.flush();

      final auth = TestAuth()..userId = a;
      final groupService = FakeGroupDriveService(
        displayNames: {a: 'Sentetik Kabul Hesabı'},
      );
      final gate = LocalOwnershipGate.synthetic();
      final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
      ControlledOwnershipRuntime? runtime;
      GroupDriveClient? client;
      Future<void>? mount;
      try {
        runtime = (await app.startDriveIt(
          gate: gate,
          controlled: ControlledOwnershipDependencies(
            descriptor: descriptor,
            databaseFactory: databaseFactory,
            restoreAuth: () async => auth,
            producerRunning: () => FlutterForegroundTask.isRunningService,
            openStore: (owner) =>
                OwnerScopedLocalStore.open(root: root.path, owner: owner),
            attachForeground: (gps, value) async =>
                ForegroundService.attachForTesting(gps, value),
            detachForeground: ForegroundService.detachForTesting,
            writerFence: LocalSourceWriterFence(
              gate: gate,
              gpsBusy: () => FlutterForegroundTask.isRunningService,
              provenCategories: LocalSourceWriterFence.requiredCategories,
              sourceRoots: [root.path],
            ),
            groupDriveServiceForTesting: groupService,
          ),
          archiveSource: SavedDriveArchiveSource(archiveBox),
          unfinishedArchiveDrives: () async => <String>{},
          archiveAuthorizer: _NeverArchiveAuthorizer(),
          mountApplication: (widget) {
            mount = tester.pumpWidget(widget);
          },
        ))!;
        final ownerRuntime = runtime;
        await mount;
        await tester.pump();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byKey(const Key('home_group_card')), findsOneWidget);

        // Use the actual owner Home -> /group route from the controlled release
        // composition. Group creation is synthetic and contains no real account.
        await tester.tap(find.byKey(const Key('home_group_card')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(GroupDriveScreen), findsOneWidget);
        await tester.tap(find.byKey(const Key('group_create')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byKey(const Key('group_lobby')), findsOneWidget);
        await tester.tap(find.byKey(const Key('group_start_ride')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byKey(const Key('group_map_workspace')), findsOneWidget);
        expect(find.byKey(const Key('group_share_start')), findsOneWidget);

        final groupClient = groupService.forOwner(ownerRuntime.owner.lease);
        client = groupClient;
        final created = await groupClient.current();
        expect(created?.members, hasLength(1));
        expect(created!.members.single.sharingStatus, GroupSharingStatus.off);
        expect(await ownerRuntime.gps.journal.active(), isNull);
        expect(await FlutterForegroundTask.isRunningService, isFalse);

        // Drive the real Flutter controls from this isolated integration test.
        // This is test automation only; it does not change the product consent
        // policy. Android's native location prompt remains a manual user action.
        final startButton = find.byKey(const Key('group_share_start'));
        await tester.ensureVisible(startButton);
        expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);
        await tester.tap(startButton);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('group_consent_confirm')), findsOneWidget);
        await tester.tap(find.byKey(const Key('group_consent_confirm')));
        await tester.pumpAndSettle();

        debugPrint(
          'A55_GROUP_GPS: in-app consent submitted; approve the Android '
          'location prompt on device if shown. No coordinates are logged.',
        );
        final firstFix = await _waitForMember(
          tester,
          groupClient,
          predicate: (member) =>
              member.sharingStatus == GroupSharingStatus.sharing &&
              member.location?.origin == GroupLocationOrigin.deviceGps,
        );
        expect(firstFix.location, isNotNull);
        expect(firstFix.location!.accuracyMeters, isNotNull);
        expect(firstFix.location!.accuracyMeters! <= 75, isTrue);
        expect(find.textContaining('Cihaz GPS konumları'), findsOneWidget);
        expect(find.byKey(const Key('group_marker_count')), findsOneWidget);
        expect(await ownerRuntime.gps.journal.active(), isNull);
        expect(await FlutterForegroundTask.isRunningService, isFalse);

        // Pause through the actual visible Flutter control and verify the fake
        // group immediately removes the live point.
        final pauseButton = find.byKey(const Key('group_share_pause'));
        await tester.ensureVisible(pauseButton);
        expect(tester.widget<TextButton>(pauseButton).onPressed, isNotNull);
        await tester.tap(pauseButton);
        await tester.pumpAndSettle();
        final paused = await _waitForMember(
          tester,
          groupClient,
          predicate: (member) =>
              member.sharingStatus == GroupSharingStatus.paused &&
              member.location == null,
        );
        expect(paused.location, isNull);
        expect(find.text('Yönetici • DURAKLATILDI'), findsOneWidget);
        expect(await ownerRuntime.gps.journal.active(), isNull);

        // Resume requires a fresh explicit interaction and consent in the app.
        final resumeButton = find.byKey(const Key('group_share_start'));
        await tester.ensureVisible(resumeButton);
        expect(tester.widget<FilledButton>(resumeButton).onPressed, isNotNull);
        await tester.tap(resumeButton);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('group_consent_confirm')), findsOneWidget);
        await tester.tap(find.byKey(const Key('group_consent_confirm')));
        await tester.pumpAndSettle();
        final resumed = await _waitForMember(
          tester,
          groupClient,
          predicate: (member) =>
              member.sharingStatus == GroupSharingStatus.sharing &&
              member.location?.origin == GroupLocationOrigin.deviceGps &&
              member.location!.recordedAt.isAfter(
                firstFix.location!.recordedAt,
              ),
        );
        expect(resumed.location, isNotNull);
        expect(find.textContaining('Cihaz GPS konumları'), findsOneWidget);

        // Exercise the actual app lifecycle while sharing is active. The user
        // presses Home and returns; sharing must remain paused and not auto-resume.
        debugPrint(
          'A55_GROUP_GPS: press Home, then return to the isolated DriveIt app.',
        );
        final backgroundPaused = await _waitForMember(
          tester,
          groupClient,
          predicate: (member) =>
              member.sharingStatus == GroupSharingStatus.paused &&
              member.location == null,
        );
        expect(backgroundPaused.location, isNull);
        expect(await ownerRuntime.gps.journal.active(), isNull);
        expect(await FlutterForegroundTask.isRunningService, isFalse);

        // A -> B cannot carry the group permission, stream, or point. Returning
        // to A shows the same group paused with no live location.
        auth.emit(b);
        await ownerRuntime.owner.settled;
        expect(ownerRuntime.owner.lease.owner.userId, b);
        final clientB = groupService.forOwner(ownerRuntime.owner.lease);
        expect(await clientB.current(), isNull);
        auth.emit(a);
        await ownerRuntime.owner.settled;
        expect(ownerRuntime.owner.lease.owner.userId, a);
        final clientA = groupService.forOwner(ownerRuntime.owner.lease);
        final afterReturn = await clientA.current();
        expect(
          afterReturn?.members.single.sharingStatus,
          GroupSharingStatus.paused,
        );
        expect(afterReturn?.members.single.location, isNull);
        expect(await ownerRuntime.gps.journal.active(), isNull);
        expect(await FlutterForegroundTask.isRunningService, isFalse);

        // Leave the fake group through its UI and ensure no member grant remains.
        if (find.byType(GroupDriveScreen).evaluate().isEmpty) {
          await tester.tap(find.byKey(const Key('home_group_card')));
          await tester.pump(const Duration(milliseconds: 350));
        }
        expect(find.byKey(const Key('group_leave')), findsOneWidget);
        await tester.tap(find.byKey(const Key('group_leave')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('group_confirm')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(await clientA.current(), isNull);
        expect(await ownerRuntime.gps.journal.active(), isNull);
        debugPrint('A55_GROUP_GPS: acceptance assertions completed.');
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
        await client?.close();
        await runtime?.closeAfterProducerDetached();
        await auth.events.close();
        await groupService.close();
        await archiveHive.close();
        maps.GoogleMapsFlutterPlatform.instance = oldMaps;
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}

Future<GroupDriveMember> _waitForMember(
  WidgetTester tester,
  GroupDriveClient client, {
  required bool Function(GroupDriveMember) predicate,
}) async {
  for (var i = 0; i < 240; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final snapshot = await client.current();
    final member = snapshot?.members.firstOrNull;
    if (member != null && predicate(member)) return member;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
  }
  throw TestFailure(
    'Timed out waiting for isolated group GPS state; coordinates withheld.',
  );
}

class _NeverArchiveAuthorizer implements DeviceArchiveAuthorizer {
  @override
  Future<bool> verifyDeviceAccess() async => false;
}
