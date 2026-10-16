// This target contains exactly one native-auth acceptance method so a prior
// cancellation scenario cannot leave this test in a stale Activity lifecycle.
// ignore_for_file: implementation_imports
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
        'DRIVEIT_ARCHIVE_TEST2_ERROR:$testDescription:'
        '${diagnostic.substring(offset, end)}',
      );
    }
    binding.results[testDescription] = diagnostic;
  };
  debugPrint('DRIVEIT_ARCHIVE_TEST2:main_entered');
  testWidgets('Test 2: native device auth grants isolated archive access', (
    tester,
  ) async {
    debugPrint('DRIVEIT_ARCHIVE_TEST2:body_entered');
    expect(SupabaseBootstrap.isIsolatedAndroidTest, isTrue);
    debugPrint('DRIVEIT_ARCHIVE_TEST2:isolated_composition_verified');
    expect(await SupabaseBootstrap.initializeIfConfigured(), isFalse);

    final foregroundReady = await tester.runAsync(
      _waitForRealArchiveForeground,
    );
    expect(foregroundReady, isTrue);
    final nativeState = await const MethodChannel(
      'driveit/device_archive_security',
    ).invokeMapMethod<String, Object?>('getArchiveHostState');
    expect(nativeState?['applicationId'], 'com.example.driveit_project.isolated_test');
    expect(nativeState?['activityResumed'], isTrue);
    expect(nativeState?['windowFocus'], isTrue);
    expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed);

    final root = await Directory.systemTemp.createTemp(
      'driveit_archive_success_only_',
    );
    final hive = HiveImpl()
      ..init('${root.path}/source')
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    final box = await hive.openBox<DriveSession>('drives');
    await box.put(
      'synthetic-archive-success',
      DriveSession(
        id: 'synthetic-archive-success',
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
                'TEST 2: Cihaz PIN’i veya parmak iziyle doğrulamayı BAŞARIYLA tamamlayın. Geri’ye basmayın.',
              ),
            ),
          ),
        ),
      );
      debugPrint('DRIVEIT_ARCHIVE_TEST2:prompt_imminent');
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
      expect(lease.epoch, epoch);
      expect(context.drives().map((drive) => drive.id), [
        'synthetic-archive-success',
      ]);
      debugPrint('DRIVEIT_ARCHIVE_TEST2:context_granted:ownerEpoch=$epoch');

      await tester.pumpWidget(
        MaterialApp(home: DeviceDriveArchiveScreen(archive: context)),
      );
      screenOwnsContext = true;
      expect(find.text('Cihazdaki Eski Sürüşler'), findsOneWidget);
      expect(find.textContaining('28.09.2026'), findsOneWidget);
      await tester.tap(find.text('28.09.2026 00:00'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveDetailScreen), findsOneWidget);
      await tester.tap(find.text('GPS Rota Haritası'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);
      expect(context.drive('synthetic-archive-success').route, hasLength(2));
      expect(await sourceFile.readAsBytes(), sourceBytes);
      debugPrint('DRIVEIT_ARCHIVE_TEST2:detail_and_route_accessible');
    } finally {
      await tester.pumpWidget(const SizedBox());
      if (!screenOwnsContext) context?.dispose();
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
      debugPrint('DRIVEIT_ARCHIVE_TEST2:foreground_ready:$lastNative');
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  debugPrint(
    'DRIVEIT_ARCHIVE_TEST2:foreground_timeout:'
    'flutter=$lastFlutter:native=$lastNative',
  );
  return false;
}
