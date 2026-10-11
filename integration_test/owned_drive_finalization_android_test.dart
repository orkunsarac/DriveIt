import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/drive_route_projection.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, a, b;
import '../test/owned_drive_delivery_test.dart' show DeliveryMatcher;

@pragma('vm:entry-point')
void ownedDeliveryProbeCallback() =>
    FlutterForegroundTask.setTaskHandler(_OwnedDeliveryProbe());

/// Real headless Android FlutterEngine + native sqflite, synthetic producer.
/// No geolocation subscription, network, app.main() or shared Hive bootstrap.
class _OwnedDeliveryProbe extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final encoded = await FlutterForegroundTask.getData<String>(
      key: OwnedForegroundBootstrap.preferenceKey,
    );
    if (encoded == null) throw StateError('Synthetic descriptor missing');
    final descriptor = await OwnedForegroundBootstrap.decode(encoded);
    final journal = await descriptor.openJournal(databaseFactory);
    try {
      final session = (await journal.active())!;
      await descriptor.verifyHandoff(databaseFactory, session.id);
      final after = (await journal.last(session.id))?.sequence ?? 0;
      final end = after == 0 ? 150 : 301;
      for (var sequence = after + 1; sequence <= end; sequence++) {
        final i = sequence - 1;
        await journal.append(
          session.id,
          sequence,
          CanonicalTelemetryPoint(
            latitude: 40 + i * .00018,
            longitude: 30,
            timestamp: session.startedAt.add(Duration(seconds: i)),
            speedMps: 20,
            headingDegrees: 0,
            altitudeMeters: 10,
            accuracyMeters: 5,
            distanceFromPreviousMeters: i == 0 ? 0 : 20,
            accelerationMps2: 0,
            speedSource: 'native',
          ),
        );
      }
      FlutterForegroundTask.sendDataToMain({'syntheticDeliverySequence': end});
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
  testWidgets(
    'native foreground recreation then owner Score World Career save',
    (tester) async {
      expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
      expect(await SupabaseBootstrap.initializeIfConfigured(), false);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('İzole sentetik foreground/finalization testi'),
          ),
        ),
      );
      final root = await (await getTemporaryDirectory()).createTemp(
        'driveit_owner_test_',
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
          attachForeground: (gps, d) async =>
              ForegroundService.attachForTesting(gps, d),
          detachForeground: ForegroundService.detachForTesting,
        ),
      ))!;
      try {
        await ForegroundService.init();
        final session = await runtime.gps.start(
          startNative: (s, binding) async {
            await FlutterForegroundTask.saveData(
              key: OwnedForegroundBootstrap.preferenceKey,
              value: descriptor
                  .forSession(s, binding, ownerEpoch: runtime.owner.lease.epoch)
                  .encode(),
            );
          },
        );
        final original = await runtime.gps.requireBinding(session.id);
        for (final expected in [150, 301]) {
          final done = Completer<int>();
          void receive(Object value) {
            if (value is Map &&
                value['syntheticDeliverySequence'] is int &&
                !done.isCompleted) {
              done.complete(value['syntheticDeliverySequence'] as int);
            }
          }

          FlutterForegroundTask.addTaskDataCallback(receive);
          try {
            final result = await FlutterForegroundTask.startService(
              serviceId: 909,
              notificationTitle: 'Sentetik DriveIt testi',
              notificationText: 'Gerçek sürüş kaydı yapılmaz',
              serviceTypes: const [ForegroundServiceTypes.location],
              callback: ownedDeliveryProbeCallback,
            );
            if (result is ServiceRequestFailure) throw result.error;
            expect(
              await done.future.timeout(const Duration(seconds: 45)),
              expected,
            );
            final stopped = await FlutterForegroundTask.stopService();
            if (stopped is ServiceRequestFailure) throw stopped.error;
          } finally {
            FlutterForegroundTask.removeTaskDataCallback(receive);
          }
          expect(
            (await runtime.gps.requireBinding(
              session.id,
            )).provenance.sourceIdentity,
            original.provenance.sourceIdentity,
          );
        }
        final rows = await runtime.gps.journal.read(session.id);
        expect(
          rows.map((p) => p.sequence).toList(),
          List.generate(301, (i) => i + 1),
        );
        final projection = DriveRouteProjection(
          rows.map((p) => p.point).toList(),
        );
        await runtime.gps.journal.requestStop(
          session.id,
          at: rows.last.point.timestamp,
        );
        await ForegroundService.stop();
        final drive = DriveSession(
          id: session.id,
          date: DateTime.now(),
          distance: projection.distanceMeters,
          durationSeconds: 300,
          averageSpeed: 72,
          maxSpeed: 72,
          mapImagePath: '',
          route: projection.route,
        );
        Future<void> save() => DriveStorageService.saveDrive(
          drive,
          acquisitionMetadata: {'sessionId': session.id},
        );
        await save();
        await save();
        final lease = runtime.owner.lease;
        expect(lease.drives(), hasLength(1));
        expect(lease.requireDrive(session.id).route, hasLength(301));
        expect(lease.telemetry(session.id)!.points, hasLength(301));
        expect(lease.score(session.id), isNotNull);
        expect(lease.career().totalDistanceMeters, 6000);
        expect((await lease.worldSnapshot())!.traces, isNotEmpty);
        expect(
          await runtime.gps.ownership.verified(
            runtime.gps.journalId,
            session.id,
          ),
          true,
        );
        await ForegroundService.acknowledgeSaved(session.id, session.id);
        auth.emit(b);
        await runtime.owner.settled;
        expect(runtime.owner.lease.drives(), isEmpty);
        expect(runtime.owner.lease.career().totalDistanceMeters, 0);
        auth.emit(a);
        await runtime.owner.settled;
        expect(runtime.owner.lease.drives().single.id, session.id);
      } finally {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
        await runtime.closeAfterProducerDetached();
        await auth.events.close();
        await root.delete(
          recursive: true,
        ); // This newly-created synthetic root only.
      }
    },
  );
}
