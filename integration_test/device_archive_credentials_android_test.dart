// Independent Hive registry is used only for freshly-created synthetic data.
// ignore_for_file: implementation_imports
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/android_device_archive_authorizer.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/legacy_source_writer_fence.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/screens/device_drive_archive_screen.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, b;
import '../test/owned_drive_delivery_test.dart' show DeliveryMaps;

class _SyntheticFence implements RegisteredSourceWriterFence {
  @override
  void requireRegistered() {}
  @override
  Future<void> pauseAndDrain() async {}
  @override
  Future<void> resume() async {}
}

/// Interactive device-credential acceptance with newly-created synthetic stores.
/// No app.main(), real drive files, Auth initialization or authentication bypass.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android archive prompt cancellation denies access', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'İZOLE ARŞİV TESTİ 1: Android doğrulamasını İPTAL EDİN.',
            ),
          ),
        ),
      ),
    );
    final accepted = await AndroidDeviceArchiveAuthorizer()
        .verifyDeviceAccess()
        .timeout(const Duration(seconds: 90));
    expect(accepted, false);
  });
  testWidgets('real Android archive prompt device credential grants access', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'İZOLE ARŞİV TESTİ 2: Parmak izi veya cihaz PIN ile DOĞRULAYIN.',
            ),
          ),
        ),
      ),
    );
    final accepted = await AndroidDeviceArchiveAuthorizer()
        .verifyDeviceAccess()
        .timeout(const Duration(seconds: 90));
    expect(accepted, true);
  });
  testWidgets('real Android credential authorizes archive context and route', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    final root = await Directory.systemTemp.createTemp(
      'driveit_archive_native_',
    );
    final hive = HiveImpl()
      ..init('${root.path}/source')
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    final box = await hive.openBox<DriveSession>('drives');
    await box.put(
      'synthetic-old',
      DriveSession(
        id: 'synthetic-old',
        date: DateTime.utc(2026, 9, 28),
        distance: 6000,
        durationSeconds: 300,
        averageSpeed: 72,
        maxSpeed: 72,
        mapImagePath: '',
        route: [
          RoutePoint(latitude: 40, longitude: 30),
          RoutePoint(latitude: 40.01, longitude: 30),
        ],
      ),
    );
    await box.flush();
    final auth = TestAuth();
    final runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      driveInProgress: () async => false,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: '${root.path}/owners', owner: owner),
    );
    await runtime.start();
    final source = SavedDriveArchiveSource(box);
    final snapshot = await DeviceDriveArchiveSnapshot.prepare(
      source: source,
      writers: _SyntheticFence(),
      unfinishedDriveIds: () async => {},
    );
    final before = await File('${root.path}/source/drives.hive').readAsBytes();
    final originalMaps = maps.GoogleMapsFlutterPlatform.instance;
    DeviceDriveArchiveContext? context;
    var screenOwnsContext = false;
    try {
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('İZOLE ARŞİV TESTİ 3: Cihaz doğrulamasını TAMAMLAYIN.'),
          ),
        ),
      );
      context = await DeviceDriveArchiveAccess(
        gate: LocalOwnershipGate.synthetic(),
        snapshot: snapshot,
        authorizer: AndroidDeviceArchiveAuthorizer(),
      ).open(runtime.lease).timeout(const Duration(seconds: 90));
      expect(context.isCurrent, true);
      screenOwnsContext = true;
      await tester.pumpWidget(
        MaterialApp(home: DeviceDriveArchiveScreen(archive: context)),
      );
      await tester.tap(find.text('28.09.2026 00:00'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveDetailScreen), findsOneWidget);
      await tester.tap(find.text('GPS Rota Haritası'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);
      expect(context.drive('synthetic-old').route, hasLength(2));
      auth.emit(b);
      await runtime.settled;
      expect(context.isCurrent, false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Arşiv erişimi sona erdi'), findsWidgets);
      await box.flush();
      expect(
        await File('${root.path}/source/drives.hive').readAsBytes(),
        before,
      );
      await tester.pumpWidget(const SizedBox());
      context = null; // Archive list owns/disposes its capability.
    } finally {
      await tester.pumpWidget(const SizedBox());
      if (!screenOwnsContext) context?.dispose();
      maps.GoogleMapsFlutterPlatform.instance = originalMaps;
      await runtime.close();
      runtime.dispose();
      await auth.events.close();
      await hive.close();
      await root.delete(recursive: true); // New synthetic fixture only.
    }
  });
}
