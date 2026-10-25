import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:driveit_project/main.dart' as app;
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/screens/drive_completion_screen.dart';
import 'package:driveit_project/screens/drive_detail_screen.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/screens/map_screen.dart';
import 'package:driveit_project/features/drive_poster/poster_screens.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import '../test/local_owner_integration_test.dart' show TestAuth;
import '../test/owned_drive_delivery_test.dart'
    show DeliveryMaps, DeliveryLocation, DeliveryMatcher;
import 'owned_drive_ui_android_test.dart' show ownedDriveUiSyntheticCallback;

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  expect(ready(), true);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'DI004 native foreground journal auto-save and four completion actions',
    (tester) async {
      expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
      expect(await SupabaseBootstrap.initializeIfConfigured(), false);
      final root = await (await getApplicationSupportDirectory()).createTemp(
        'driveit_owner_test_ui_di004_',
      );
      final auth = TestAuth()..userId = null;
      final legacy = HiveImpl()
        ..init('${root.path}/legacy')
        ..registerAdapter(DriveSessionAdapter())
        ..registerAdapter(RoutePointAdapter());
      final legacyBox = await legacy.openBox<DriveSession>('drives');
      final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
      final gate = LocalOwnershipGate.synthetic();
      final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
      final oldLocation = GeolocatorPlatform.instance;
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      GeolocatorPlatform.instance = DeliveryLocation();
      final runtime = (await app.startDriveIt(
        gate: gate,
        controlled: ControlledOwnershipDependencies(
          descriptor: descriptor,
          databaseFactory: databaseFactory,
          restoreAuth: () async => auth,
          producerRunning: () => FlutterForegroundTask.isRunningService,
          worldRoadMatching: RoadMatchingService(provider: DeliveryMatcher()),
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
        ),
        archiveSource: SavedDriveArchiveSource(legacyBox),
        unfinishedArchiveDrives: () async => {},
      ))!;
      ForegroundService.installOwnedStartCallbackForTesting(
        ownedDriveUiSyntheticCallback,
      );
      final ids = <String>[];

      Future<void> click(String key) async {
        final target = find.byKey(Key(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      Future<String> record({bool fromHome = true}) async {
        if (fromHome) {
          unawaited(
            Navigator.of(
              tester.element(find.byType(HomeScreen)),
            ).pushNamed('/drive'),
          );
          await waitFor(
            tester,
            () => find.text('SÜRÜŞE BAŞLA').evaluate().isNotEmpty,
          );
        }
        await FlutterForegroundTask.saveData(
          key: 'ownedUiSampleLimit',
          value: 16,
        );
        await tester.tap(find.text('SÜRÜŞE BAŞLA'));
        await tester.pump(const Duration(seconds: 4));
        String? id;
        for (var i = 0; i < 100; i++) {
          final active = await ForegroundService.activeSession();
          if (active != null &&
              (await runtime.gps.journal.last(active.id))?.sequence == 16) {
            id = active.id;
            (tester.state(find.byType(MapScreen)) as dynamic).driveStartTime =
                active.startedAt;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
        expect(id, isNotNull);
        await tester.tap(find.text('SÜRÜŞÜ BİTİR'));
        await waitFor(
          tester,
          () => find.byType(DriveCompletionScreen).evaluate().isNotEmpty,
        );
        expect(await runtime.gps.journal.lifecycle(id!), 'VERIFIED');
        expect(runtime.owner.lease.telemetry(id)!.points, hasLength(16));
        expect(await runtime.gps.journal.read(id), hasLength(16));
        expect(find.text('Sürüşü Kaydet'), findsNothing);
        expect(find.textContaining('poster oluşturmak ister'), findsNothing);
        ids.add(id);
        expect(
          runtime.owner.lease.drives().map((d) => d.id).toSet(),
          ids.toSet(),
        );
        debugPrint(
          'DI004_EMULATOR: native stop -> VERIFIED; drives=${ids.length}',
        );
        return id;
      }

      try {
        await tester.pump();
        await waitFor(
          tester,
          () => find.byType(HomeScreen).evaluate().isNotEmpty,
        );
        final id = await record();
        await click('drive_complete_detail');
        expect(
          tester
              .widget<OwnedDriveDetailScreen>(
                find.byType(OwnedDriveDetailScreen),
              )
              .driveId,
          id,
        );
        Navigator.of(tester.element(find.byType(DriveDetailScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await click('drive_complete_poster');
        expect(
          tester
              .widget<PosterEditorScreen>(find.byType(PosterEditorScreen))
              .drive
              .id,
          id,
        );
        Navigator.of(tester.element(find.byType(PosterEditorScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(await runtime.gps.journal.lifecycle(id), 'VERIFIED');
        await click('drive_complete_home');
        await waitFor(
          tester,
          () => find.byType(HomeScreen).evaluate().isNotEmpty,
        );
        debugPrint('DI004_EMULATOR: detail ID, poster ID/cancel, Home passed');
        await record();
        await click('drive_complete_new');
        await waitFor(
          tester,
          () => find.text('SÜRÜŞE BAŞLA').evaluate().isNotEmpty,
        );
        final state = tester.state(find.byType(MapScreen)) as dynamic;
        expect(state.isDriving, false);
        expect(state.driveStartTime, null);
        expect(state.routeService.distance, 0);
        expect(await ForegroundService.activeSession(), null);
        debugPrint('DI004_EMULATOR: New Drive opens clean, idle map');
        await record(fromHome: false);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await waitFor(
          tester,
          () => find.byType(HomeScreen).evaluate().isNotEmpty,
        );
        expect(runtime.owner.lease.drives(), hasLength(3));
        for (final id in ids) {
          expect(await runtime.gps.journal.lifecycle(id), 'VERIFIED');
        }
        expect(tester.takeException(), null);
        debugPrint(
          'DI004_EMULATOR: back -> Home; all 3 isolated drives preserved',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (await FlutterForegroundTask.isRunningService) {
          await ForegroundService.stop();
        }
        await runtime.closeAfterProducerDetached();
        await auth.events.close();
        await legacy.close();
        maps.GoogleMapsFlutterPlatform.instance = oldMaps;
        GeolocatorPlatform.instance = oldLocation;
        // Keep the app-private synthetic fixture for diagnosis; never touch the
        // normal package, production files, accounts or drive stores.
      }
    },
  );
}
