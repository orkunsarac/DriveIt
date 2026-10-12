import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/screens/map_screen.dart';
import 'package:driveit_project/screens/owned_drive_screen.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/main.dart' as app;
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, a, b;
import '../test/owned_drive_delivery_test.dart'
    show DeliveryLocation, DeliveryMatcher, DeliveryMaps;

@pragma('vm:entry-point')
void processKillProbeCallback() =>
    FlutterForegroundTask.setTaskHandler(_ProcessKillProbe());

/// Synthetic sticky-service callback. It only writes points to the explicitly
/// marked test journal; it never opens a physical location stream.
class _ProcessKillProbe extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final encoded = await FlutterForegroundTask.getData<String>(
      key: OwnedForegroundBootstrap.preferenceKey,
    );
    if (encoded == null) {
      throw StateError('Synthetic recovery descriptor missing');
    }
    final descriptor = await OwnedForegroundBootstrap.decode(encoded);
    final journal = await descriptor.openJournal(databaseFactory);
    try {
      final session = await journal.active();
      if (session == null) {
        throw StateError('Synthetic recovery session missing');
      }
      final binding = await descriptor.verifyHandoff(
        databaseFactory,
        session.id,
      );
      if (binding.owner.userId != a) throw StateError('Fixed owner mismatch');
      final last = (await journal.last(session.id))?.sequence ?? 0;
      for (var sequence = last + 1; sequence <= 16; sequence++) {
        final i = sequence - 1;
        await journal.append(
          session.id,
          sequence,
          CanonicalTelemetryPoint(
            latitude: 40 + i * .00002,
            longitude: 30,
            timestamp: session.startedAt.add(Duration(seconds: i)),
            speedMps: 4,
            headingDegrees: 90,
            altitudeMeters: 10,
            accuracyMeters: 5,
            distanceFromPreviousMeters: i == 0 ? 0 : 2,
            accelerationMps2: 0,
            speedSource: 'synthetic_process_recovery',
          ),
        );
      }
      FlutterForegroundTask.sendDataToMain({'processProbeSequence': 16});
    } finally {
      await journal.close();
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['drainSession'] is String) {
      unawaited(_drain(data['drainSession'] as String));
    }
  }

  Future<void> _drain(String id) async {
    final encoded = await FlutterForegroundTask.getData<String>(
      key: OwnedForegroundBootstrap.preferenceKey,
    );
    if (encoded == null) {
      throw StateError('Synthetic descriptor missing for stop');
    }
    final descriptor = await OwnedForegroundBootstrap.decode(encoded);
    final journal = await descriptor.openJournal(databaseFactory);
    try {
      if ((await journal.active())?.id != id) {
        throw StateError('Synthetic drain session mismatch');
      }
      await journal.stop(
        id,
        expectedSequence: (await journal.last(id))?.sequence ?? 0,
      );
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
  const phase = String.fromEnvironment('DRIVEIT_PROCESS_KILL_PHASE');
  const fixtureSuffix = String.fromEnvironment('DRIVEIT_PROCESS_KILL_FIXTURE');
  if (!RegExp(r'^[a-z0-9_]*$').hasMatch(fixtureSuffix)) {
    throw StateError('Invalid synthetic crash fixture suffix');
  }
  if (phase == 'prepare') {
    testWidgets(
      'prepare durable synthetic session for external OS process kill',
      (tester) async {
        expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
        expect(await SupabaseBootstrap.initializeIfConfigured(), false);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('Synthetic recovery preparation')),
          ),
        );
        final support = await getApplicationSupportDirectory();
        final root = Directory(
          '${support.path}/driveit_owner_test_process_kill$fixtureSuffix',
        );
        final journalFile = File('${root.path}/gps.db');
        if (await journalFile.exists()) {
          throw StateError(
            'Old synthetic process-kill fixture exists; refusing to overwrite',
          );
        }
        final auth = TestAuth();
        final descriptor = await OwnedForegroundBootstrap.prepareForTesting(
          root,
        );
        final legacy = HiveImpl()
          ..init('${root.path}/legacy')
          ..registerAdapter(DriveSessionAdapter())
          ..registerAdapter(RoutePointAdapter());
        final legacyBox = await legacy.openBox<DriveSession>('drives');
        final gate = LocalOwnershipGate.synthetic();
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
            attachForeground: (gps, d) async =>
                ForegroundService.attachForTesting(gps, d),
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
        await ForegroundService.init();
        ForegroundService.installOwnedStartCallbackForTesting(
          processKillProbeCallback,
        );
        final ready = Completer<void>();
        void receive(Object event) {
          if (event is Map &&
              event['processProbeSequence'] == 16 &&
              !ready.isCompleted) {
            ready.complete();
          }
        }

        FlutterForegroundTask.addTaskDataCallback(receive);
        try {
          final session = await ForegroundService.start();
          final binding = await runtime.gps.requireBinding(session.id);
          await ready.future.timeout(const Duration(seconds: 45));
          final rows = await runtime.gps.journal.read(session.id);
          expect(rows, hasLength(16));
          auth.emit(b);
          await runtime.owner.settled;
          expect(runtime.owner.state.name, 'blocked');
          expect(
            (await runtime.gps.requireBinding(session.id)).owner.userId,
            a,
          );
          auth.emit(a);
          await runtime.owner.settled;
          expect(runtime.owner.lease.owner.userId, a);
          await expectLater(
            runtime.gps.requireBinding('missing-synthetic-session'),
            throwsStateError,
          );
          final handoff = descriptor.forSession(
            session,
            binding,
            ownerEpoch: runtime.owner.epoch,
          );
          final mismatched =
              jsonDecode(handoff.encode()) as Map<String, dynamic>;
          (mismatched['handoff'] as Map)['sourceIdentity'] =
              'ffffffff-ffff-4fff-8fff-ffffffffffff';
          final invalid = await OwnedForegroundBootstrap.decode(
            jsonEncode(mismatched),
          );
          await expectLater(
            invalid.verifyHandoff(databaseFactory, session.id),
            throwsStateError,
          );
          expect((await runtime.gps.journal.read(session.id)), hasLength(16));
          final marker = File('${root.path}/process_kill_evidence.json');
          await marker.writeAsString(
            jsonEncode({
              'sessionId': session.id,
              'sourceIdentity': binding.provenance.sourceIdentity,
              'owner': binding.owner.userId,
              'sequence': rows.last.sequence,
              'startedAt': session.startedAt.toIso8601String(),
            }),
            flush: true,
          );
          // The host kills only the isolated package PID after this marker. The
          // test process intentionally remains alive until the OS terminates it.
          // ignore: avoid_print
          print('PHASE5_PROCESS_KILL_READY');
          await Completer<void>().future.timeout(const Duration(minutes: 2));
        } finally {
          FlutterForegroundTask.removeTaskDataCallback(receive);
          // Process termination is expected before normal Dart teardown.
          if (!await FlutterForegroundTask.isRunningService) {
            await runtime.closeAfterProducerDetached();
            await auth.events.close();
            await legacy.close();
          }
        }
      },
    );
  } else if (phase == 'recover') {
    testWidgets(
      'separate process verifies journal and owner recovery UI after OS kill',
      (tester) async {
        expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
        expect(await SupabaseBootstrap.initializeIfConfigured(), false);
        final support = await getApplicationSupportDirectory();
        final root = Directory(
          '${support.path}/driveit_owner_test_process_kill$fixtureSuffix',
        );
        final marker = File('${root.path}/process_kill_evidence.json');
        expect(await marker.exists(), true);
        final evidence =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        final auth = TestAuth();
        final descriptor = await OwnedForegroundBootstrap.prepareForTesting(
          root,
        );
        final legacy = HiveImpl()
          ..init('${root.path}/legacy')
          ..registerAdapter(DriveSessionAdapter())
          ..registerAdapter(RoutePointAdapter());
        final legacyBox = await legacy.openBox<DriveSession>('drives');
        final gate = LocalOwnershipGate.synthetic();
        final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
        maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
        // Only this isolated test service is stopped. The journal remains
        // recording/recoverable, so real startup must offer the Continue path.
        if (await FlutterForegroundTask.isRunningService) {
          final stopped = await FlutterForegroundTask.stopService();
          expect(stopped, isNot(isA<ServiceRequestFailure>()));
        }
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
            attachForeground: (gps, d) async =>
                ForegroundService.attachForTesting(gps, d),
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
        final oldLocation = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = DeliveryLocation();
        try {
          ForegroundService.installOwnedStartCallbackForTesting(
            processKillProbeCallback,
          );
          final session = await runtime.gps.journal.session(
            evidence['sessionId'] as String,
          );
          expect(session, isNotNull);
          final recoveredSession = session;
          if (recoveredSession == null) {
            throw StateError('Expected GPS session is missing');
          }
          final binding = await runtime.gps.requireBinding(recoveredSession.id);
          expect(binding.owner.userId, a);
          expect(binding.provenance.sourceIdentity, evidence['sourceIdentity']);
          expect(recoveredSession.id, evidence['sessionId']);
          expect(
            (await runtime.gps.journal.read(recoveredSession.id)),
            hasLength(16),
          );
          expect(runtime.owner.lease.drives(), isEmpty);
          expect(runtime.owner.lease.pendingDriveFinalizations(), isEmpty);
          final status = await ForegroundService.inspectRecovery();
          expect(status.hasVerifiedSession, true);
          expect(status.session?.id, recoveredSession.id);

          await tester.pump();
          expect(find.byType(OwnedDriveScreen), findsOneWidget);
          for (
            var i = 0;
            i < 30 &&
                find.text('Sürüşe Devam Et').evaluate().isEmpty &&
                find.byType(MapScreen).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pump();
          }
          if (status.requiresDecision) {
            expect(find.text('Sürüşe Devam Et'), findsOneWidget);
            expect(find.text('Kaydet ve Bitir'), findsOneWidget);
            // The real recovery action must resume the original session.
            expect(runtime.owner.lease.drives(), isEmpty);
            await tester.tap(find.text('Sürüşe Devam Et'));
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
            expect(
              (await ForegroundService.activeSession())?.id,
              recoveredSession.id,
            );
            expect(
              (await runtime.gps.requireBinding(
                recoveredSession.id,
              )).provenance.sourceIdentity,
              evidence['sourceIdentity'],
            );
            expect(
              await runtime.gps.journal.read(recoveredSession.id),
              hasLength(16),
            );
          } else {
            expect(find.byType(MapScreen), findsOneWidget);
            final recovered = await ForegroundService.activeSession();
            expect(recovered?.id, recoveredSession.id);
            expect(
              (await runtime.gps.journal.read(recoveredSession.id)),
              hasLength(16),
            );
          }

          // Shut down only the synthetic service and its test-owned directory.
          await ForegroundService.stop();
          expect(
            (await runtime.gps.journal.session(recoveredSession.id))?.state,
            'stopped',
          );
          await runtime.closeAfterProducerDetached();
          await auth.events.close();
          await tester.pumpWidget(const SizedBox());
          await legacy.close();
          await root.delete(recursive: true);
        } finally {
          maps.GoogleMapsFlutterPlatform.instance = oldMaps;
          GeolocatorPlatform.instance = oldLocation;
          if (await FlutterForegroundTask.isRunningService) {
            await FlutterForegroundTask.stopService();
          }
          if (runtime.owner.state.name != 'closed') {
            await runtime.closeAfterProducerDetached();
            await auth.events.close();
            await legacy.close();
          }
        }
      },
    );
  } else {
    test('explicit process-kill phase is required', () {
      fail('Set DRIVEIT_PROCESS_KILL_PHASE=prepare or recover');
    });
  }
}
