import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/screens/drive_detail_screen.dart';
import 'package:driveit_project/screens/history_screen.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/screens/map_screen.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/widgets/owner_personal_navigator.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, a, b;
import '../test/owned_drive_delivery_test.dart'
    show DeliveryLocation, DeliveryMaps, DeliveryMatcher;

@pragma('vm:entry-point')
void ownedDriveUiSyntheticCallback() =>
    FlutterForegroundTask.setTaskHandler(_OwnedDriveUiProbe());

/// Real Android foreground-task service with synthetic journal samples.
/// Physical GPS, Supabase and app.main() are not used.
class _OwnedDriveUiProbe extends TaskHandler {
  OwnedForegroundBootstrap? _descriptor;
  String? _sessionId;
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final encoded = await FlutterForegroundTask.getData<String>(
      key: OwnedForegroundBootstrap.preferenceKey,
    );
    if (encoded == null) throw StateError('Synthetic descriptor missing');
    final descriptor = await OwnedForegroundBootstrap.decode(encoded);
    final journal = await descriptor.openJournal(databaseFactory);
    var session = await journal.active();
    if (session == null) throw StateError('Synthetic session missing');
    // Give the synthetic acquisition a realistic five-minute capture window.
    // This is test-only mutation inside the isolated app's synthetic journal;
    // it lets the real Score/coverage pipeline run without a five-minute wait.
    final syntheticStartedAt = DateTime.now().subtract(
      const Duration(minutes: 5),
    );
    await journal.db.update(
      'sessions',
      {'started_us': syntheticStartedAt.microsecondsSinceEpoch},
      where: 'id=?',
      whereArgs: [session.id],
    );
    session = (await journal.session(session.id))!;
    await descriptor.verifyHandoff(databaseFactory, session.id);
    final last = (await journal.last(session.id))?.sequence ?? 0;
    for (var sequence = last + 1; sequence <= 301; sequence++) {
      final i = sequence - 1;
      await journal.append(
        session.id,
        sequence,
        CanonicalTelemetryPoint(
          latitude: 40 + i * .00018,
          longitude: 30,
          timestamp: session.startedAt.add(Duration(seconds: i)),
          speedMps: 20,
          headingDegrees: 90,
          altitudeMeters: 10,
          accuracyMeters: 5,
          distanceFromPreviousMeters: i == 0 ? 0 : 20,
          accelerationMps2: 0,
          speedSource: 'synthetic_test',
        ),
      );
    }
    _descriptor = descriptor;
    _sessionId = session.id;
    FlutterForegroundTask.sendDataToMain({'ownedUiSequence': 301});
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map || data['drainSession'] != _sessionId) return;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    final descriptor = _descriptor;
    final id = _sessionId;
    if (descriptor == null || id == null) return;
    final journal = await descriptor.openJournal(databaseFactory);
    try {
      final last = await journal.last(id);
      await journal.stop(id, expectedSequence: last?.sequence ?? 0);
      FlutterForegroundTask.sendDataToMain({'ownedUiDrained': id});
    } finally {
      await journal.close();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('A owner /drive UI starts, records, saves and isolates drive', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    expect(await SupabaseBootstrap.initializeIfConfigured(), false);
    final originalMaps = maps.GoogleMapsFlutterPlatform.instance;
    final originalLocation = GeolocatorPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
    GeolocatorPlatform.instance = DeliveryLocation();
    final root = await (await getApplicationSupportDirectory()).createTemp(
      'driveit_owner_test_ui_',
    );
    final auth = TestAuth();
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    final runtime = (await LocalOwnershipBootstrap.run(
      gate: LocalOwnershipGate.synthetic(),
      legacyBootstrap: () async => fail('Shared Hive fallback'),
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
      ),
    ))!;
    try {
      await ForegroundService.init();
      ForegroundService.installOwnedStartCallbackForTesting(
        ownedDriveUiSyntheticCallback,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerPersonalNavigator(
            runtime: runtime.owner,
            legacyChild: const Scaffold(body: Text('Legacy path unused')),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeScreen), findsOneWidget);
      final ownerNavigator = Navigator.of(
        tester.element(find.byType(HomeScreen)),
      );
      // Exercise the real home drive control. Its registered /drive route is
      // OwnedDriveScreen -> MapScreen, the same route used by the app.
      final homeDriveButton = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_AnimatedDriveButton',
      );
      expect(homeDriveButton, findsOneWidget);
      await tester.tap(homeDriveButton);
      await tester.pump();
      for (
        var i = 0;
        i < 40 && find.byType(MapScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.text('SÜRÜŞE BAŞLA'), findsOneWidget);
      await tester.tap(find.text('SÜRÜŞE BAŞLA'));
      // The real UI countdown is part of the exercised start action.
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 45; i++) {
        final active = await tester.runAsync(
          () => ForegroundService.activeSession(),
        );
        if (active != null &&
            (await tester.runAsync(
                  () => runtime.gps.journal.last(active.id),
                ))?.sequence ==
                301) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
      }
      final session = await tester.runAsync(ForegroundService.activeSession);
      expect(session, isNotNull);
      final activeSession = session;
      if (activeSession == null) {
        throw StateError('Owned foreground session was not created');
      }
      // The test producer advances the synthetic journal clock; keep the live
      // /drive view's start marker aligned with that same synthetic session.
      (tester.state(find.byType(MapScreen)) as dynamic).driveStartTime =
          activeSession.startedAt;
      final binding = await tester.runAsync(
        () => runtime.gps.requireBinding(activeSession.id),
      );
      expect(binding, isNotNull);
      final activeBinding = binding;
      if (activeBinding == null) {
        throw StateError('Owned session binding was not persisted');
      }
      final rows = await tester.runAsync(
        () => runtime.gps.journal.read(activeSession.id),
      );
      expect(rows, hasLength(301));
      expect(activeBinding.owner.userId, a);
      expect(activeBinding.provenance.isProven, true);
      expect(find.text('SÜRÜŞÜ BİTİR'), findsOneWidget);

      await tester.tap(find.text('SÜRÜŞÜ BİTİR'));
      for (
        var i = 0;
        i < 50 && find.text('🏁 Sürüş Tamamlandı').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.text('🏁 Sürüş Tamamlandı'), findsOneWidget);
      await tester.tap(find.text('Sürüşü Kaydet'));
      for (
        var i = 0;
        i < 300 &&
            (runtime.owner.lease.drives().isEmpty ||
                runtime.owner.lease.pendingDriveFinalizations().isNotEmpty);
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      final ownerA = runtime.owner.lease;
      final finalization = ownerA.read<Map>(
        'owned_drive_finalization_v1',
        activeSession.id,
      );
      expect(
        ownerA.pendingDriveFinalizations(),
        isEmpty,
        reason:
            'finalization state=${finalization?['state']} '
            'derivedReady=${finalization?['derivedReady']} '
            'scoreAvailable=${finalization?['scoreAvailable']} '
            'saveFailureVisible=${find.textContaining('Kayıt tamamlanamadı').evaluate().isNotEmpty}',
      );
      await tester.pump();

      expect(ownerA.drives(), hasLength(1));
      final drive = ownerA.drives().single;
      expect(drive.route, hasLength(301));
      final savedTelemetry = ownerA.telemetry(drive.id);
      if (savedTelemetry == null) {
        throw StateError('Owned telemetry was not persisted');
      }
      expect(savedTelemetry.points, hasLength(301));
      expect(
        ownerA.score(drive.id),
        isNotNull,
        reason: 'Synthetic five-minute GPS window must produce Drive Score',
      );
      final worldSnapshot = await ownerA.worldSnapshot();
      if (worldSnapshot == null) {
        throw StateError('Owned World snapshot was not persisted');
      }
      expect(worldSnapshot.traces, isNotEmpty);
      expect(ownerA.career().totalDistanceMeters, 6000);
      expect(
        await runtime.gps.ownership.verified(
          runtime.gps.journalId,
          activeSession.id,
        ),
        true,
      );

      // Save retry is safe after the visible UI save.
      await tester.runAsync(
        () => DriveStorageService.saveDrive(
          ownerA.requireDrive(drive.id),
          telemetry: savedTelemetry.points,
          acquisitionMetadata: {'sessionId': activeSession.id},
        ),
      );
      expect(ownerA.drives(), hasLength(1));
      expect(ownerA.career().totalDistanceMeters, 6000);

      expect(
        ownerNavigator.mounted,
        isTrue,
        reason: 'Successful save must retain the owner navigator',
      );
      unawaited(ownerNavigator.pushNamed<void>('/history'));
      await tester.pump();
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Sürüşlerim'), findsOneWidget);
      expect(find.textContaining('6.00 km'), findsWidgets);
      await tester.tap(find.textContaining('Sürüş • ').first);
      await tester.pump();
      expect(find.byType(DriveDetailScreen), findsOneWidget);
      expect(ownerA.requireDrive(drive.id).route, hasLength(301));
      final scoreText = '${ownerA.score(drive.id)!.totalScore.round()} / 1000';
      for (var i = 0; i < 50 && find.text(scoreText).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.text(scoreText), findsOneWidget);

      auth.emit(b);
      await runtime.owner.settled;
      await tester.pump();
      expect(runtime.owner.lease.owner.userId, b);
      expect(runtime.owner.lease.drives(), isEmpty);
      expect(runtime.owner.lease.career().totalDistanceMeters, 0);
      auth.emit(a);
      await runtime.owner.settled;
      await tester.pump();
      expect(runtime.owner.lease.drives().single.id, drive.id);
      expect(runtime.owner.lease.career().totalDistanceMeters, 6000);
    } finally {
      await tester.pumpWidget(const SizedBox());
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      await runtime.closeAfterProducerDetached();
      await auth.events.close();
      await root.delete(recursive: true);
      GeolocatorPlatform.instance = originalLocation;
      maps.GoogleMapsFlutterPlatform.instance = originalMaps;
    }
  });
}
