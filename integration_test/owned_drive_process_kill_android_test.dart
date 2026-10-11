import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/screens/map_screen.dart';
import 'package:driveit_project/screens/owned_drive_screen.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, a;
import '../test/owned_drive_delivery_test.dart'
    show DeliveryLocation, DeliveryMatcher;

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
  void onReceiveData(Object data) {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('DRIVEIT_PROCESS_KILL_PHASE');
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
          '${support.path}/driveit_owner_test_process_kill',
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
            attachForeground: (gps, d) async =>
                ForegroundService.attachForTesting(gps, d),
            detachForeground: ForegroundService.detachForTesting,
          ),
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
          await Completer<void>().future;
        } finally {
          FlutterForegroundTask.removeTaskDataCallback(receive);
          // Process termination is expected before normal Dart teardown.
          if (!await FlutterForegroundTask.isRunningService) {
            await runtime.closeAfterProducerDetached();
            await auth.events.close();
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
          '${support.path}/driveit_owner_test_process_kill',
        );
        final marker = File('${root.path}/process_kill_evidence.json');
        expect(await marker.exists(), true);
        final evidence =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        final auth = TestAuth();
        final descriptor = await OwnedForegroundBootstrap.prepareForTesting(
          root,
        );
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
            attachForeground: (gps, d) async =>
                ForegroundService.attachForTesting(gps, d),
            detachForeground: ForegroundService.detachForTesting,
          ),
        ))!;
        final oldLocation = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = DeliveryLocation();
        try {
          await ForegroundService.init();
          final session = await runtime.gps.journal.session(
            evidence['sessionId'] as String,
          );
          expect(session, isNotNull);
          final recoveredSession = session;
          if (recoveredSession == null) {
            throw StateError('Expected GPS session is missing');
          }
          final binding = await runtime.gps.requireBinding(
            recoveredSession.id,
          );
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

          await tester.pumpWidget(
            MaterialApp(home: OwnedDriveScreen(lease: runtime.owner.lease)),
          );
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
            // Keep recovery pending; no automatic new session or save.
            expect(runtime.owner.lease.drives(), isEmpty);
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
          if (await FlutterForegroundTask.isRunningService) {
            final stopped = await FlutterForegroundTask.stopService();
            expect(stopped, isNot(isA<ServiceRequestFailure>()));
          }
          await runtime.closeAfterProducerDetached();
          await auth.events.close();
          await tester.pumpWidget(const SizedBox());
          await root.delete(recursive: true);
        } finally {
          GeolocatorPlatform.instance = oldLocation;
          if (await FlutterForegroundTask.isRunningService) {
            await FlutterForegroundTask.stopService();
          }
          if (runtime.owner.state.name != 'closed') {
            await runtime.closeAfterProducerDetached();
            await auth.events.close();
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
