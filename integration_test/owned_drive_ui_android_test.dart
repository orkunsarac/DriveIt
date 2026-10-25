import 'dart:async';
import 'dart:io';

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
import 'package:driveit_project/main.dart' as app;
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'package:driveit_project/screens/device_drive_archive_screen.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, a, b;
import '../test/owned_drive_delivery_test.dart'
    show
        DeliveryLocation,
        DeliveryMaps,
        DeliveryMatcher,
        DeliveryArchiveAuthorizer;

@pragma('vm:entry-point')
void ownedDriveUiSyntheticCallback() =>
    FlutterForegroundTask.setTaskHandler(_OwnedDriveUiProbe());

/// Real Android foreground-task service with synthetic journal samples.
/// Physical GPS and Supabase are not used. UI uses main's shared startDriveIt.
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
    final limit =
        await FlutterForegroundTask.getData<int>(key: 'ownedUiSampleLimit') ??
        301;
    for (var sequence = last + 1; sequence <= limit; sequence++) {
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
    FlutterForegroundTask.sendDataToMain({'ownedUiSequence': limit});
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

/// Only UI controls are driven here; acquisition is the isolated native probe.
Future<String> _recordGuestThroughUi(
  WidgetTester tester,
  ControlledOwnershipRuntime runtime, {
  int samples = 16,
  bool expectNa = true,
}) async {
  final beforeCount = runtime.owner.lease.drives().length;
  await FlutterForegroundTask.saveData(
    key: 'ownedUiSampleLimit',
    value: samples,
  );
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_AnimatedDriveButton',
    ),
  );
  await tester.pump();
  for (var i = 0; i < 40 && find.byType(MapScreen).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(find.byType(MapScreen), findsOneWidget);
  await tester.tap(find.text('SÜRÜŞE BAŞLA'));
  await tester.pump(const Duration(seconds: 3));
  String? id;
  for (var i = 0; i < 80; i++) {
    final active = await ForegroundService.activeSession();
    if (active != null &&
        (await runtime.gps.journal.last(active.id))?.sequence == samples) {
      id = active.id;
      (tester.state(find.byType(MapScreen)) as dynamic).driveStartTime =
          active.startedAt;
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(id, isNotNull);
  await tester.tap(find.text('SÜRÜŞÜ BİTİR'));
  for (
    var i = 0;
    i < 50 && find.text('Sürüş Kaydedildi').evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  for (
    var i = 0;
    i < 200 && runtime.owner.lease.drives().length == beforeCount;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(runtime.owner.lease.drives(), hasLength(beforeCount + 1));
  if (expectNa) {
    expect(
      runtime.owner.lease.score(id!),
      isNull,
      reason: '15 seconds of five minutes is insufficient coverage',
    );
  }
  await runtime.owner.worldSettled;
  return id!;
}

class _RuntimeMatcher extends DeliveryMatcher {
  bool permanent = false;
  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) {
    if (permanent) {
      return Future.value(
        RoadMatchingResult.failure(
          kind: RoadMatchingFailureKind.invalidInput,
          message: 'Synthetic permanent rejection',
        ),
      );
    }
    return super.match(request);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final releaseAcceptance = const bool.fromEnvironment(
    'DRIVEIT_RELEASE_ACCEPTANCE',
  );
  if (releaseAcceptance) {
    // Flutter 3.44.8's integration_test reporter serializes
    // FlutterErrorDetails.toString(), which loses the actual exception.
    // Preserve its normal recording behavior, but replace the native result
    // with the concrete exception and stack and emit privacy-safe test stages.
    final originalReporter = reportTestException;
    reportTestException = (details, testDescription) {
      originalReporter(details, testDescription);
      final diagnostic = <String>[
        details.exceptionAsString(),
        if (details.stack != null) details.stack.toString(),
      ].join('\n');
      for (var offset = 0; offset < diagnostic.length; offset += 700) {
        final end = offset + 700 < diagnostic.length
            ? offset + 700
            : diagnostic.length;
        debugPrint(
          'DRIVEIT_RELEASE_ERROR:$testDescription:'
          '${diagnostic.substring(offset, end)}',
        );
      }
      binding.results[testDescription] = diagnostic;
    };
    debugPrint('DRIVEIT_RELEASE_STAGE:dart_test_main_entered');
  }
  testWidgets('A owner /drive UI starts, records, saves and isolates drive', (
    tester,
  ) async {
    if (releaseAcceptance) {
      expect(const bool.fromEnvironment('dart.vm.product'), isTrue);
    }
    if (releaseAcceptance) {
      debugPrint('DRIVEIT_RELEASE_STAGE:test_body_entered');
    }
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    expect(await SupabaseBootstrap.initializeIfConfigured(), false);
    if (releaseAcceptance) {
      debugPrint('DRIVEIT_RELEASE_STAGE:backend_guard_passed');
    }
    final originalMaps = maps.GoogleMapsFlutterPlatform.instance;
    final originalLocation = GeolocatorPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
    GeolocatorPlatform.instance = DeliveryLocation();
    final root = await (await getApplicationSupportDirectory()).createTemp(
      'driveit_owner_test_ui_',
    );
    final auth = TestAuth()..userId = null;
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    final legacy = HiveImpl()
      ..init('${root.path}/legacy')
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    final legacyBox = await legacy.openBox<DriveSession>('drives');
    await legacyBox.put(
      'old',
      DriveSession(
        id: 'old',
        date: DateTime.utc(2026, 9, 28),
        distance: 1000,
        durationSeconds: 100,
        averageSpeed: 36,
        maxSpeed: 40,
        mapImagePath: '',
        route: [
          RoutePoint(latitude: 40, longitude: 30),
          RoutePoint(latitude: 40.001, longitude: 30),
        ],
      ),
    );
    await legacyBox.flush();
    final legacyBytes = await File(legacyBox.path!).readAsBytes();
    final matcher = _RuntimeMatcher()..hold = Completer<void>();
    late ControlledOwnershipRuntime runtime;
    Future<void> boot() async {
      final gate = LocalOwnershipGate.synthetic();
      runtime = (await app.startDriveIt(
        gate: gate,
        controlled: ControlledOwnershipDependencies(
          descriptor: descriptor,
          databaseFactory: databaseFactory,
          restoreAuth: () async => auth,
          producerRunning: () => FlutterForegroundTask.isRunningService,
          worldRoadMatching: RoadMatchingService(provider: matcher),
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
        archiveAuthorizer: DeliveryArchiveAuthorizer(),
      ))!;
      ForegroundService.installOwnedStartCallbackForTesting(
        ownedDriveUiSyntheticCallback,
      );
    }

    if (releaseAcceptance) {
      debugPrint('DRIVEIT_RELEASE_STAGE:before_startDriveIt');
    }
    await boot();
    if (releaseAcceptance) {
      debugPrint('DRIVEIT_RELEASE_STAGE:startDriveIt_completed');
    }
    try {
      await tester.pump();
      if (releaseAcceptance) {
        debugPrint('DRIVEIT_RELEASE_STAGE:first_test_frame_pumped');
      }
      expect(runtime.owner.lease.owner.userId, null);
      expect(
        find.textContaining('Misafir sürüşleri bu cihazda'),
        findsOneWidget,
      );
      if (const bool.fromEnvironment('DRIVEIT_RELEASE_BOOTSTRAP_ONLY')) {
        debugPrint('DRIVEIT_RELEASE_STAGE:bootstrap_acceptance_passed');
        return;
      }
      await tester.pump(const Duration(seconds: 1));
      final guestId = await _recordGuestThroughUi(tester, runtime);
      await FlutterForegroundTask.saveData(
        key: 'ownedUiSampleLimit',
        value: 301,
      );
      auth.emit(a);
      await runtime.owner.settled;
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
      if (releaseAcceptance) {
        debugPrint(
          'DRIVEIT_RELEASE_STATE stage=journal_readback_verified '
          'ownerEpoch=${runtime.owner.lease.epoch} '
          'sessionId=${activeBinding.sessionId} '
          'sourceIdentity=${activeBinding.provenance.sourceIdentity} '
          'journalPointCount=${rows?.length ?? 0} sidecarState=${activeBinding.state}',
        );
      }
      expect(find.text('SÜRÜŞÜ BİTİR'), findsOneWidget);

      await tester.tap(find.text('SÜRÜŞÜ BİTİR'));
      for (
        var i = 0;
        i < 50 && find.text('Sürüş Kaydedildi').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.text('Sürüş Kaydedildi'), findsOneWidget);
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
      if (releaseAcceptance) {
        final journalReceipt = await runtime.gps.journal.transferFor(
          activeSession.id,
        );
        final sidecarVerified = await runtime.gps.ownership.verified(
          runtime.gps.journalId,
          activeSession.id,
        );
        final telemetry = ownerA.telemetry(activeSession.id);
        final worldJobs = await ownerA.worldPendingJobs() ?? const [];
        debugPrint(
          'DRIVEIT_RELEASE_STATE stage=save_wait_completed '
          'ownerEpoch=${ownerA.epoch} sessionId=${activeSession.id} '
          'sourceIdentity=${activeBinding.provenance.sourceIdentity} '
          'journalReceiptVerified=${journalReceipt?['verified_us'] != null} '
          'sidecarVerified=$sidecarVerified hiveDrive=${ownerA.read("drives", activeSession.id) != null} '
          'telemetryPoints=${telemetry?.points.length ?? 0} '
          'scorePersisted=${ownerA.score(activeSession.id) != null} '
          'careerDistance=${ownerA.career().totalDistanceMeters} '
          'finalizationState=${finalization?['state']} '
          'derivedReady=${finalization?['derivedReady']} '
          'worldJobs=${worldJobs.length} worldWorkerError=${runtime.owner.worldErrorCode}',
        );
      }
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
      // The matcher is deliberately held. Save and direct detail read-back
      // must finish before World validation can return.
      expect(matcher.hold!.isCompleted, false);
      expect(await runtime.gps.journal.active(), null);
      expect(
        ownerA.read<Map>(
          'owned_drive_finalization_v1',
          drive.id,
        )?['worldQueued'],
        true,
      );
      expect((await ownerA.worldSnapshot())?.traces ?? [], isEmpty);
      expect(ownerA.career().totalDistanceMeters, 6000);
      expect(
        await runtime.gps.ownership.verified(
          runtime.gps.journalId,
          activeSession.id,
        ),
        true,
      );

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

      matcher.retry = true;
      matcher.hold!.complete();
      await runtime.owner.worldSettled;
      final jobKey = WorldPendingJob.idempotencyKey(
        drive.id,
        WorldJobType.validateRoad,
      );
      expect(
        ownerA.read<WorldPendingJob>('my_world_pending_jobs', jobKey)?.status,
        WorldJobStatus.retryScheduled,
      );
      expect(runtime.owner.worldErrorCode, 'owner_world_retry_pending');
      expect(ownerA.drives(), hasLength(1));

      // Close/reopen native SQLite/Hive and the complete application root.
      // This is disk reopen, not the separate OS process-crash acceptance.
      await tester.pumpWidget(const SizedBox());
      await runtime.closeAfterProducerDetached();
      matcher.hold = null;
      await boot();
      await tester.pump();
      await runtime.owner.worldSettled;
      expect(runtime.owner.lease.requireDrive(drive.id).route, hasLength(301));
      expect(
        runtime.owner.lease
            .read<WorldPendingJob>('my_world_pending_jobs', jobKey)
            ?.status,
        WorldJobStatus.retryScheduled,
      );
      expect(runtime.owner.lease.career().totalDistanceMeters, 6000);
      expect(
        (await runtime.gps.requireBinding(drive.id)).provenance.sourceIdentity,
        activeBinding.provenance.sourceIdentity,
      );

      // Archive access is routed through the real lazy application loader.
      // Device-auth provider is synthetic here; the unchanged real PIN/biometry
      // prompt already has its own native acceptance and is not bypassed.
      final reopenedNavigator = Navigator.of(
        tester.element(find.byType(HomeScreen)),
      );
      unawaited(reopenedNavigator.pushNamed<void>('/history'));
      await tester.pump();
      await tester.tap(find.text('Cihazdaki Eski Sürüşler'));
      for (
        var i = 0;
        i < 40 && find.byType(DeviceDriveArchiveScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.byType(DeviceDriveArchiveScreen), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(DeviceDriveArchiveScreen),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pump();
      expect(find.byType(DeviceDriveArchiveDetailScreen), findsOneWidget);
      await tester.tap(find.text('GPS Rota Haritası'));
      await tester.pump();
      expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);
      expect(await File(legacyBox.path!).readAsBytes(), legacyBytes);

      auth.emit(b);
      await runtime.owner.settled;
      await tester.pump();
      expect(runtime.owner.lease.owner.userId, b);
      expect(runtime.owner.lease.drives(), isEmpty);
      expect(runtime.owner.lease.career().totalDistanceMeters, 0);
      matcher.retry = false;
      auth.emit(a);
      await runtime.owner.settled;
      await tester.pump();
      // The pending durable job is processed by the owner-ready root trigger.
      await runtime.owner.worldSettled;
      expect(runtime.owner.lease.drives().single.id, drive.id);
      expect(runtime.owner.lease.career().totalDistanceMeters, 6000);
      final snapshot = (await runtime.owner.lease.worldSnapshot())!;
      expect(snapshot.traces, hasLength(1));
      await DriveStorageService.saveDrive(
        runtime.owner.lease.requireDrive(drive.id),
        acquisitionMetadata: {'sessionId': drive.id},
      );
      await runtime.owner.worldSettled;
      expect(
        (await runtime.owner.lease.worldSnapshot())!.generation,
        snapshot.generation,
      );
      expect(runtime.owner.lease.drives(), hasLength(1));
      expect(runtime.owner.lease.career().totalDistanceMeters, 6000);
      matcher.permanent = true;
      final rejectedId = await _recordGuestThroughUi(
        tester,
        runtime,
        samples: 301,
        expectNa: false,
      );
      final rejectedJob = WorldPendingJob.idempotencyKey(
        rejectedId,
        WorldJobType.validateRoad,
      );
      expect(
        runtime.owner.lease
            .read<WorldPendingJob>('my_world_pending_jobs', rejectedJob)
            ?.status,
        WorldJobStatus.failedPermanent,
      );
      expect(
        runtime.owner.lease.requireDrive(rejectedId).route,
        hasLength(301),
      );
      expect(runtime.owner.lease.drives(), hasLength(2));
      expect(runtime.owner.lease.career().totalDistanceMeters, 12000);
      expect(
        (await runtime.owner.lease.worldSnapshot())!.generation,
        snapshot.generation,
      );
      auth.emit(null);
      await runtime.owner.settled;
      await tester.pump();
      expect(runtime.owner.lease.drives().single.id, guestId);
      expect(runtime.owner.lease.score(guestId), null);
    } finally {
      if (matcher.hold != null && !matcher.hold!.isCompleted) {
        matcher.hold!.complete();
      }
      await tester.pumpWidget(const SizedBox());
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      await runtime.closeAfterProducerDetached();
      await auth.events.close();
      await legacy.close();
      await root.delete(recursive: true);
      GeolocatorPlatform.instance = originalLocation;
      maps.GoogleMapsFlutterPlatform.instance = originalMaps;
    }
  });
}
