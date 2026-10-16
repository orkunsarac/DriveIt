// One isolated release scenario: screen lock permanently revokes the archive
// capability. No cancellation, Home, or owner-switch case is included.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:hive/src/hive_impl.dart';
import 'package:integration_test/integration_test.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/screens/device_drive_archive_screen.dart';
import 'package:driveit_project/services/android_device_archive_authorizer.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/legacy_source_writer_fence.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, a;
import '../test/owned_drive_delivery_test.dart' show DeliveryMaps;

class _SyntheticFence implements RegisteredSourceWriterFence {
  @override
  void requireRegistered() {}

  @override
  Future<void> pauseAndDrain() async {}

  @override
  Future<void> resume() async {}
}

class _SystemLifecycle with WidgetsBindingObserver {
  final StreamController<AppLifecycleState> states =
      StreamController<AppLifecycleState>.broadcast(sync: true);

  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);

  Future<AppLifecycleState> nextBackground() => states.stream
      .firstWhere((state) => state != AppLifecycleState.resumed)
      .catchError((Object _) => AppLifecycleState.detached);

  Future<AppLifecycleState> nextResume() =>
      states.stream
          .firstWhere((state) => state == AppLifecycleState.resumed)
          .catchError((Object _) => AppLifecycleState.detached);

  void close() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(states.close());
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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
        'DRIVEIT_ARCHIVE_TEST4_ERROR:$testDescription:'
        '${diagnostic.substring(offset, end)}',
      );
    }
    binding.results[testDescription] = diagnostic;
  };
  debugPrint('DRIVEIT_ARCHIVE_TEST4:main_entered');

  testWidgets('Test 4: screen lock revokes existing archive access', (
    tester,
  ) async {
    debugPrint('DRIVEIT_ARCHIVE_TEST4:body_entered');
    expect(SupabaseBootstrap.isIsolatedAndroidTest, isTrue);
    expect(await SupabaseBootstrap.initializeIfConfigured(), isFalse);
    expect(await tester.runAsync(_waitForRealArchiveForeground), isTrue);
    final initialHost = await const MethodChannel(
      'driveit/device_archive_security',
    ).invokeMapMethod<String, Object?>('getArchiveHostState');
    expect(initialHost?['applicationId'], 'com.example.driveit_project.isolated_test');
    expect(initialHost?['activityResumed'], isTrue);
    expect(initialHost?['windowFocus'], isTrue);
    expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed);

    final root = await Directory.systemTemp.createTemp(
      'driveit_archive_lock_revoke_',
    );
    final hive = HiveImpl()
      ..init('${root.path}/source')
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    final box = await hive.openBox<DriveSession>('drives');
    await box.put(
      'synthetic-lock-revoke',
      DriveSession(
        id: 'synthetic-lock-revoke',
        date: DateTime.utc(2026, 9, 28),
        distance: 6000,
        durationSeconds: 300,
        averageSpeed: 72,
        maxSpeed: 88,
        mapImagePath: '',
        route: [
          RoutePoint(latitude: 40, longitude: 30),
          RoutePoint(latitude: 40.01, longitude: 30),
        ],
      ),
    );
    await box.flush();
    final sourceFile = File('${root.path}/source/drives.hive');
    final sourceBytes = await sourceFile.readAsBytes();
    final auth = TestAuth()..userId = a;
    final runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      driveInProgress: () async => false,
      openStore: (owner) => OwnerScopedLocalStore.open(
        root: '${root.path}/owners',
        owner: owner,
      ),
    );
    await runtime.start();
    final lease = runtime.lease;
    final epoch = lease.epoch;
    expect(lease.isCurrent, isTrue);
    expect(lease.owner.userId, a);

    DeviceDriveArchiveContext? context;
    var screenOwnsContext = false;
    final lifecycle = _SystemLifecycle()..attach();
    final originalMaps = maps.GoogleMapsFlutterPlatform.instance;
    try {
      final snapshot = await DeviceDriveArchiveSnapshot.prepare(
        source: SavedDriveArchiveSource(box),
        writers: _SyntheticFence(),
        unfinishedDriveIds: () async => <String>{},
      );
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'TEST 4: Cihaz PIN’i veya parmak iziyle doğrulayın. '
                'Ardından ekrandaki kilit talimatını izleyin.',
              ),
            ),
          ),
        ),
      );
      final access = DeviceDriveArchiveAccess(
        gate: LocalOwnershipGate.synthetic(),
        snapshot: snapshot,
        authorizer: AndroidDeviceArchiveAuthorizer(),
      );
      final granted = await tester.runAsync(() => access.open(lease));
      if (granted == null) {
        throw StateError('native_archive_authentication_did_not_complete');
      }
      context = granted;
      expect(context.isCurrent, isTrue);
      expect(lease.isCurrent, isTrue);
      expect(lease.owner.userId, a);
      expect(lease.epoch, epoch);
      expect(context.drives().map((drive) => drive.id), [
        'synthetic-lock-revoke',
      ]);
      debugPrint('DRIVEIT_ARCHIVE_TEST4:context_granted:ownerEpoch=$epoch');

      await tester.pumpWidget(
        MaterialApp(home: DeviceDriveArchiveScreen(archive: context)),
      );
      screenOwnsContext = true;
      expect(find.text('Cihazdaki Eski Sürüşler'), findsOneWidget);
      await tester.tap(find.text('28.09.2026 00:00'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveDetailScreen), findsOneWidget);
      await tester.tap(find.text('GPS Rota Haritası'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);
      debugPrint('DRIVEIT_ARCHIVE_TEST4:route_access_verified');

      final background = lifecycle.nextBackground();
      final resumed = lifecycle.nextResume();
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(DeviceDriveArchiveMapScreen)),
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ekran kilidi kabulü'),
            content: const Text(
              'Şimdi telefonun güç tuşuyla ekranı kilitle. Test kilit '
              'olayını saptadıktan sonra telefonu normal şekilde açmanı isteyecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Devam'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      debugPrint('DRIVEIT_ARCHIVE_TEST4:lock_action_requested');
      final lockedState = await tester.runAsync(() async {
        try {
          return await background.timeout(const Duration(minutes: 2));
        } on TimeoutException {
          return null;
        }
      });
      expect(lockedState, isNotNull, reason: 'screen-lock lifecycle not observed');
      expect(context!.isCurrent, isFalse);
      expect(
        () => context!.drive('synthetic-lock-revoke'),
        throwsStateError,
      );
      debugPrint('DRIVEIT_ARCHIVE_TEST4:context_revoked_while_locked:$lockedState');

      final unlocked = await tester.runAsync(() async {
        try {
          await resumed.timeout(const Duration(minutes: 2));
          return true;
        } on TimeoutException {
          return false;
        }
      });
      expect(unlocked, isTrue, reason: 'unlock/resume lifecycle not observed');
      expect(await tester.runAsync(_waitForRealArchiveForeground), isTrue);
      if (find.text('Devam').evaluate().isNotEmpty) {
        await tester.tap(find.text('Devam'));
      }
      await tester.pump();

      expect(context!.isCurrent, isFalse);
      expect(
        () => context!.drive('synthetic-lock-revoke'),
        throwsStateError,
      );
      expect(
        find.text('Arşiv erişimi sona erdi. Yeniden doğrulama gerekli.'),
        findsOneWidget,
      );
      expect(find.text('Sürüş tarihi: 28.09.2026 00:00'), findsNothing);
      expect(find.text('GPS Rota Haritası'), findsNothing);
      expect(
        find.byKey(const ValueKey('device-archive-map-synthetic-lock-revoke')),
        findsNothing,
      );
      expect(await sourceFile.readAsBytes(), sourceBytes);
      debugPrint('DRIVEIT_ARCHIVE_TEST4:old_context_still_revoked_after_unlock');
    } finally {
      await tester.pumpWidget(const SizedBox());
      if (!screenOwnsContext) context?.dispose();
      lifecycle.close();
      maps.GoogleMapsFlutterPlatform.instance = originalMaps;
      await runtime.close();
      runtime.dispose();
      await auth.events.close();
      await hive.close();
      await root.delete(recursive: true);
    }
  });
}

Future<bool> _waitForRealArchiveForeground() async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  Map<String, Object?>? lastNative;
  String? lastFlutter;
  while (DateTime.now().isBefore(deadline)) {
    lastFlutter = WidgetsBinding.instance.lifecycleState?.name;
    lastNative = await const MethodChannel(
      'driveit/device_archive_security',
    ).invokeMapMethod<String, Object?>('getArchiveHostState');
    if (lastFlutter == 'resumed' &&
        lastNative?['activityResumed'] == true &&
        lastNative?['windowFocus'] == true) {
      debugPrint('DRIVEIT_ARCHIVE_TEST4:foreground_ready:$lastNative');
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  debugPrint(
    'DRIVEIT_ARCHIVE_TEST4:foreground_timeout:'
    'flutter=$lastFlutter:native=$lastNative',
  );
  return false;
}
