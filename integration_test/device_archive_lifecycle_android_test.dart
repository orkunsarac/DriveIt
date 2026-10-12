import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:driveit_project/main.dart' as app;
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import '../test/local_owner_integration_test.dart' show TestAuth, b;
import '../test/owned_drive_delivery_test.dart' show DeliveryMaps;

class _SystemLifecycle with WidgetsBindingObserver {
  final StreamController<AppLifecycleState> states =
      StreamController<AppLifecycleState>.broadcast(sync: true);
  void attach() => WidgetsBinding.instance.addObserver(this);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);
  Future<AppLifecycleState> nextBackground() =>
      states.stream.firstWhere((state) => state != AppLifecycleState.resumed);
  Future<AppLifecycleState> nextResume() =>
      states.stream.firstWhere((state) => state == AppLifecycleState.resumed);
  void close() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(states.close());
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Home and lockscreen revoke archive capability', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    expect(await SupabaseBootstrap.initializeIfConfigured(), false);
    final root = await Directory.systemTemp.createTemp(
      'driveit_owner_test_archive_lifecycle_',
    );
    final hive = HiveImpl()
      ..init('${root.path}/source')
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    final box = await hive.openBox<DriveSession>('drives');
    await box.put(
      'synthetic-archive-lifecycle',
      DriveSession(
        id: 'synthetic-archive-lifecycle',
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
    final originalBytes = await sourceFile.readAsBytes();
    final auth = TestAuth();
    final gate = LocalOwnershipGate.synthetic();
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    late app.DriveItApp application;
    final controlled = (await app.startDriveIt(
      gate: gate,
      controlled: ControlledOwnershipDependencies(
        restoreAuth: () async => auth,
        descriptor: descriptor,
        databaseFactory: databaseFactory,
        openStore: (owner) => OwnerScopedLocalStore.open(
          root: '${root.path}/owners',
          owner: owner,
        ),
        producerRunning: () => FlutterForegroundTask.isRunningService,
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
      archiveSource: SavedDriveArchiveSource(box),
      unfinishedArchiveDrives: () async => {},
      // No authorizer override: application's actual Android adapter is used.
      mountApplication: (widget) => application = widget as app.DriveItApp,
    ))!;
    final runtime = controlled.owner;
    final originalMaps = maps.GoogleMapsFlutterPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
    final lifecycle = _SystemLifecycle()..attach();
    DeviceDriveArchiveContext? context;
    var screenOwnsContext = false;
    try {
      Future<DeviceDriveArchiveContext> authenticate() async {
        final access = await application.deviceArchiveLoader!(runtime.lease);
        return access.open(runtime.lease).timeout(const Duration(seconds: 120));
      }

      Future<DeviceDriveArchiveContext> authenticateOnDevice() async {
        final authenticated = await tester.runAsync(authenticate);
        if (authenticated == null) {
          throw StateError('Native archive authentication did not complete');
        }
        return authenticated;
      }

      await tester.pumpWidget(application);
      await tester.pump();
      expect(find.byType(app.DriveItApp), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          key: ValueKey('archive-auth-initial'),
          home: Scaffold(body: Text('İlk Android doğrulamasını İPTAL EDİN')),
        ),
      );
      // Native device-auth callbacks must run outside WidgetTest's FakeAsync
      // zone; otherwise the OS prompt can remain pending without lifecycle
      // delivery to the integration test.
      await tester.runAsync(() async {
        await expectLater(
          authenticate(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'code',
              'archive_device_authorization_required',
            ),
          ),
        );
      });
      debugPrint('ARCHIVE_NATIVE_CANCEL_DENIED');
      final initialContext = await authenticateOnDevice();
      context = initialContext;
      expect(initialContext.isCurrent, true);
      debugPrint('ARCHIVE_NATIVE_GRANTED');
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('archive-list-initial'),
          home: DeviceDriveArchiveScreen(archive: initialContext),
        ),
      );
      screenOwnsContext = true;
      await tester.tap(find.text('28.09.2026 00:00'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveDetailScreen), findsOneWidget);
      await tester.tap(find.text('GPS Rota Haritası'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);

      final homeBackground = lifecycle.nextBackground();
      final homeResume = lifecycle.nextResume();
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(DeviceDriveArchiveMapScreen)),
          builder: (context) => AlertDialog(
            title: const Text('Ana ekran kabulü'),
            content: const Text(
              'Şimdi Android Home tuşuna basın, DriveIt testine geri dönün.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Devam'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final returnedFromHome = await tester.runAsync(() async {
        try {
          await Future.wait([
            homeBackground,
            homeResume,
          ]).timeout(const Duration(minutes: 2));
          return true;
        } on TimeoutException {
          return false;
        }
      });
      expect(returnedFromHome, true, reason: 'Home → app resume not observed');
      if (returnedFromHome != true) return;
      await tester.pump();
      expect(initialContext.isCurrent, false);
      debugPrint('ARCHIVE_HOME_REVOKED');
      expect(
        () => initialContext.drive('synthetic-archive-lifecycle'),
        throwsStateError,
      );
      if (find.text('Ana ekran kabulü').evaluate().isNotEmpty) {
        await tester.tap(find.text('Devam'));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Arşiv erişimi sona erdi'), findsOneWidget);

      // Re-entry requires another real OS credential prompt.
      await tester.pumpWidget(
        const MaterialApp(
          key: ValueKey('archive-auth-reentry'),
          home: Scaffold(body: Text('Arşiv yeniden doğrulama')),
        ),
      );
      screenOwnsContext = false;
      context = null; // The archive route owned and disposed its old lease.
      final resumedContext = await authenticateOnDevice();
      context = resumedContext;
      expect(resumedContext.isCurrent, true);
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('archive-list-reentry'),
          home: DeviceDriveArchiveScreen(archive: resumedContext),
        ),
      );
      screenOwnsContext = true;
      await tester.pumpAndSettle();
      expect(
        resumedContext.isCurrent,
        true,
        reason: 'reauthorized archive lease was revoked before rendering',
      );
      expect(
        resumedContext.drives().map((drive) => drive.id),
        contains('synthetic-archive-lifecycle'),
        reason: 'reauthorized archive snapshot lost its synthetic source row',
      );
      expect(find.text('Cihazdaki Eski Sürüşler'), findsOneWidget);
      expect(find.textContaining('28.09.2026'), findsOneWidget);
      await tester.tap(find.textContaining('28.09.2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPS Rota Haritası'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);

      final lockBackground = lifecycle.nextBackground();
      final lockResume = lifecycle.nextResume();
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(DeviceDriveArchiveMapScreen)),
          builder: (context) => AlertDialog(
            title: const Text('Ekran kilidi kabulü'),
            content: const Text(
              'Telefonu ekran kilidine alın, kilidi açıp bu teste geri dönün.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Devam'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final returnedFromLock = await tester.runAsync(() async {
        try {
          await Future.wait([
            lockBackground,
            lockResume,
          ]).timeout(const Duration(minutes: 2));
          return true;
        } on TimeoutException {
          return false;
        }
      });
      expect(returnedFromLock, true, reason: 'Lock → app resume not observed');
      if (returnedFromLock != true) return;
      await tester.pump();
      expect(resumedContext.isCurrent, false);
      debugPrint('ARCHIVE_LOCK_REVOKED');
      expect(
        () => resumedContext.drive('synthetic-archive-lifecycle'),
        throwsStateError,
      );
      if (find.text('Ekran kilidi kabulü').evaluate().isNotEmpty) {
        await tester.tap(find.text('Devam'));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Arşiv erişimi sona erdi'), findsOneWidget);

      // Account switch also invalidates the renewed device-only capability.
      await tester.pumpWidget(
        const MaterialApp(
          key: ValueKey('archive-auth-account-switch'),
          home: Scaffold(body: Text('Hesap epoch kabulü')),
        ),
      );
      screenOwnsContext = false;
      context = null; // The archive route owned and disposed its old lease.
      final accountContext = await authenticateOnDevice();
      context = accountContext;
      expect(accountContext.isCurrent, true);
      auth.emit(b);
      await runtime.settled;
      expect(accountContext.isCurrent, false);
      debugPrint('ARCHIVE_OWNER_REVOKED');
      expect(
        () => accountContext.drive('synthetic-archive-lifecycle'),
        throwsStateError,
      );

      await box.flush();
      expect(await sourceFile.readAsBytes(), originalBytes);
    } finally {
      await tester.pumpWidget(
        const SizedBox(key: ValueKey('archive-final-cleanup')),
      );
      if (!screenOwnsContext) context?.dispose();
      lifecycle.close();
      maps.GoogleMapsFlutterPlatform.instance = originalMaps;
      await controlled.closeAfterProducerDetached();
      runtime.dispose();
      await auth.events.close();
      await hive.close();
      await root.delete(recursive: true);
    }
  });
}
