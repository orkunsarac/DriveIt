import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owned_gps_session_coordinator.dart';
import 'gps_android_test.dart' show NativeGpsProbeTask;

@pragma('vm:entry-point')
void ownedNativeProbeCallback() =>
    FlutterForegroundTask.setTaskHandler(OwnedNativeProbe());

/// Actual headless engine/MethodChannel; synthetic points ONLY. This validates
/// the production descriptor/read path, not moving GPS or real process death.
class OwnedNativeProbe extends NativeGpsProbeTask {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final descriptor = await OwnedForegroundBootstrap.decode(
        (await FlutterForegroundTask.getData<String>(
          key: OwnedForegroundBootstrap.preferenceKey,
        ))!,
      );
      final journal = await descriptor.openJournal(databaseFactory);
      try {
        final session = (await journal.active())!;
        final owner = await descriptor.verify(databaseFactory, session.id);
        if (owner.owner.userId != 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') {
          throw StateError('Synthetic fixed owner mismatch');
        }
      } finally {
        await journal.close();
      }
    } catch (_) {
      FlutterForegroundTask.sendDataToMain({'gpsProbeDone': false});
      return;
    }
    await super.onStart(timestamp, starter);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const repeats = int.fromEnvironment(
    'OWNED_FOREGROUND_PROBE_REPEATS',
    defaultValue: 1,
  );
  for (var repetition = 1; repetition <= repeats; repetition++) {
    testWidgets(
      'native foreground descriptor/sidecar recovery preserves owner and sequence [$repetition/$repeats]',
      (tester) async {
        final permission = await Geolocator.checkPermission();
        expect(
          permission,
          anyOf(LocationPermission.always, LocationPermission.whileInUse),
          reason:
              'Emulator location permission is a required test precondition',
        );
        final root = await (await getTemporaryDirectory()).createTemp(
          'driveit_owner_test_',
        );
        final descriptor = await OwnedForegroundBootstrap.prepareForTesting(
          root,
        );
        final journal = await descriptor.openJournal(databaseFactory);
        final sidecar = await descriptor.openOwnership(databaseFactory);
        var running = false;
        try {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: Text('Synthetic owner foreground')),
            ),
          );
          final session = await OwnedGpsSessionCoordinator(
            journal: journal,
            ownership: sidecar,
            journalId: descriptor.journalId,
            ownerAtStart: () =>
                GpsOwner.account('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
          ).start();
          FlutterForegroundTask.initCommunicationPort();
          FlutterForegroundTask.init(
            androidNotificationOptions: AndroidNotificationOptions(
              channelId: 'owned_native_probe',
              channelName: 'Synthetic owner probe',
            ),
            iosNotificationOptions: const IOSNotificationOptions(),
            foregroundTaskOptions: ForegroundTaskOptions(
              eventAction: ForegroundTaskEventAction.repeat(1000),
            ),
          );
          expect(await FlutterForegroundTask.isRunningService, false);
          await FlutterForegroundTask.saveData(
            key: OwnedForegroundBootstrap.preferenceKey,
            value: descriptor.encode(),
          );
          await FlutterForegroundTask.saveData(
            key: 'gps_native_probe_path',
            value: descriptor.journalPath,
          );
          for (var round = 1; round <= 2; round++) {
            final done = Completer<Map>();
            void receive(Object data) {
              if (data is Map &&
                  data.containsKey('gpsProbeDone') &&
                  !done.isCompleted) {
                done.complete(data);
              }
            }

            FlutterForegroundTask.addTaskDataCallback(receive);
            try {
              final result = await FlutterForegroundTask.startService(
                serviceId: 908,
                notificationTitle: 'Synthetic owner probe',
                notificationText: 'Emulator only',
                serviceTypes: const [ForegroundServiceTypes.location],
                callback: ownedNativeProbeCallback,
              );
              if (result is ServiceRequestFailure) {
                // Synthetic probe only: preserve the underlying native exception
                // and test stack instead of just printing the wrapper type.
                Error.throwWithStackTrace(result.error, StackTrace.current);
              }
              running = true;
              final response = await done.future.timeout(
                const Duration(seconds: 45),
              );
              expect(response['gpsProbeDone'], true);
              expect(response['sequence'], round * 60);
              expect(
                await FlutterForegroundTask.stopService(),
                isNot(isA<ServiceRequestFailure>()),
              );
              running = false;
            } finally {
              FlutterForegroundTask.removeTaskDataCallback(receive);
            }
          }
          final points = await journal.read(session.id);
          expect(points.length, 120);
          expect(
            points.map((p) => p.sequence),
            List.generate(120, (i) => i + 1),
          );
          expect(
            (await descriptor.verify(databaseFactory, session.id)).owner.userId,
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          );
          expect(await journal.db.getVersion(), 3);
        } finally {
          if (running) await FlutterForegroundTask.stopService();
          await sidecar.close();
          await journal.close();
          await root.delete(recursive: true); // Unique synthetic fixture only.
        }
      },
    );
  }
}
