import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/screens/map_screen.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/screens/drive_detail_screen.dart';
import 'package:driveit_project/screens/drive_completion_screen.dart';
import 'package:driveit_project/features/drive_poster/poster_screens.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'local_owner_integration_test.dart' show a, b;
import 'owned_drive_delivery_test.dart'
    show DeliveryFixture, DeliveryMaps, DeliveryLocation;

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(ready(), true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DeliveryFixture f;
  late maps.GoogleMapsFlutterPlatform oldMaps;
  late GeolocatorPlatform oldLocation;
  var closed = false;
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  // Hive handles opened by the fixture can deliver completions in the widget
  // zone. Keep pumping that zone while real SQLite/Hive I/O progresses.
  Future<T?> io<T>(WidgetTester tester, Future<T> Function() action) async {
    var done = false;
    T? value;
    Object? failure;
    await tester.runAsync(() async {
      unawaited(
        action().then<void>(
          (result) {
            value = result;
            done = true;
          },
          onError: (Object error) {
            failure = error;
            done = true;
          },
        ),
      );
    });
    await _wait(tester, () => done);
    if (failure != null) throw failure!;
    return value;
  }

  setUp(() async {
    closed = false;
    oldMaps = maps.GoogleMapsFlutterPlatform.instance;
    oldLocation = GeolocatorPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
    GeolocatorPlatform.instance = DeliveryLocation();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          permissions,
          (call) async => call.method == 'requestPermissions'
              ? {for (final id in call.arguments as List) id: 1}
              : 1,
        );
    f = DeliveryFixture();
    await f.open();
  });
  tearDown(() async {
    if (!closed) await f.close();
    maps.GoogleMapsFlutterPlatform.instance = oldMaps;
    GeolocatorPlatform.instance = oldLocation;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  Future<dynamic> finish(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/finish',
        routes: {
          '/': (_) => HomeScreen(ownerLease: f.runtime.owner.lease),
          '/drive': (_) => MapScreen(ownerLease: f.runtime.owner.lease),
          '/finish': (_) => MapScreen(
            ownerLease: f.runtime.owner.lease,
            resumeDrive: true,
            finishOnOpen: true,
          ),
        },
      ),
    );
    await tester.pump();
    return tester.state(find.byType(MapScreen)) as dynamic;
  }

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await io(tester, f.close);
        closed = true;
      }
    });
  }

  scenario(
    'automatic finish verifies once and preserves previous History and journal',
    (tester) async {
      final old = await io(tester, () async {
        final drive = DriveSession(
          id: 'historic',
          date: DateTime.utc(2026, 1, 1),
          distance: 1200,
          durationSeconds: 60,
          averageSpeed: 72,
          maxSpeed: 80,
          mapImagePath: '',
          route: [],
        );
        await f.runtime.owner.lease.put('drives', drive.id, drive);
        return drive;
      });
      final oldManifest = driveTransferManifest(
        f.runtime.owner.lease.requireDrive(old!.id),
      );
      final next = await io(tester, () => f.record(intervals: 16));
      final state = await finish(tester);
      await _wait(
        tester,
        () => find.text('Sürüş Kaydedildi').evaluate().isNotEmpty,
      );
      await io(tester, () async {
        expect(await f.runtime.gps.journal.lifecycle(next!.id), 'VERIFIED');
        await Future.wait<void>([
          state.stopDriving() as Future<void>,
          state.stopDriving() as Future<void>,
        ]);
        expect(f.runtime.owner.lease.drives(), hasLength(2));
        expect(await f.runtime.gps.journal.read(next.id), hasLength(17));
        expect(
          driveTransferManifest(f.runtime.owner.lease.requireDrive(old.id)),
          oldManifest,
        );
        expect(f.runtime.owner.lease.pendingDriveFinalizations(), isEmpty);
      });
      expect(find.text('Sürüşü Kaydet'), findsNothing);
      expect(find.textContaining('poster oluşturmak ister'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  scenario(
    'Hive failure keeps journal and retries the exact drive ID without a success screen',
    (tester) async {
      final drive = await io(tester, () => f.record(intervals: 16));
      f.failGroup = 'drives';
      final state = await finish(tester);
      await _wait(
        tester,
        () => find.text('Tekrar Kontrol Et').evaluate().isNotEmpty,
      );
      expect(find.text('Sürüş Kaydedildi'), findsNothing);
      await io(tester, () async {
        expect(await f.runtime.gps.journal.lifecycle(drive!.id), 'SAVING');
        expect(await f.runtime.gps.journal.read(drive.id), hasLength(17));
      });
      f.failGroup = null;
      await io(tester, () async {
        unawaited(state.stopDriving() as Future<void>);
      });
      await _wait(
        tester,
        () => find.text('Sürüş Kaydedildi').evaluate().isNotEmpty,
      );
      await io(tester, () async {
        expect(await f.runtime.gps.journal.lifecycle(drive!.id), 'VERIFIED');
        expect(f.runtime.owner.lease.drives().map((d) => d.id), [drive.id]);
        expect(await f.runtime.gps.journal.read(drive.id), hasLength(17));
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  scenario('process restart after partial save recovers the same ID', (
    tester,
  ) async {
    final drive = await io(tester, () => f.record(intervals: 16));
    f.failGroup = 'drive_telemetry';
    await finish(tester);
    await _wait(
      tester,
      () => find.text('Tekrar Kontrol Et').evaluate().isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await io(tester, () async {
      f.failGroup = null;
      await f.closeRuntime();
      await f.boot();
    });
    // Startup may reconcile a durable transfer intent before UI is mounted.
    await io(tester, () async {
      if (await f.runtime.gps.journal.lifecycle(drive!.id) != 'VERIFIED') {
        await f.save(drive);
      }
      await ForegroundService.acknowledgeSaved(drive.id, drive.id);
      expect(await f.runtime.gps.journal.lifecycle(drive.id), 'VERIFIED');
      expect(f.runtime.owner.lease.drives().map((d) => d.id), [drive.id]);
      expect(await f.runtime.gps.journal.read(drive.id), hasLength(17));
    });
  });

  scenario(
    'revoked owner cannot retry an unfinished save into another account',
    (tester) async {
      final drive = await io(tester, () => f.record(intervals: 16));
      f.failGroup = 'drives';
      final state = await finish(tester);
      await _wait(
        tester,
        () => find.text('Tekrar Kontrol Et').evaluate().isNotEmpty,
      );
      await io(tester, () async {
        f.failGroup = null;
        f.auth.emit(b);
        await f.runtime.owner.settled;
        await state.stopDriving();
        expect(() => f.runtime.owner.lease, throwsStateError);
        expect((await f.runtime.gps.requireBinding(drive!.id)).owner.userId, a);
        expect(await f.runtime.gps.journal.read(drive.id), hasLength(17));
        f.auth.emit(a);
        await f.runtime.owner.settled;
        await ForegroundService.reconcileOwnerSaves(f.runtime.owner.lease);
        expect(f.runtime.owner.lease.drives().map((d) => d.id), [drive.id]);
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<String> completed(WidgetTester tester) async {
    final drive = await io(tester, () => f.record(intervals: 16));
    await finish(tester);
    await _wait(
      tester,
      () => find.byType(DriveCompletionScreen).evaluate().isNotEmpty,
    );
    return drive!.id;
  }

  scenario(
    'completion shows four ordered actions on a small screen and Home removes recorder',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = await completed(tester);
      final actions = [
        'drive_complete_home',
        'drive_complete_new',
        'drive_complete_detail',
        'drive_complete_poster',
      ];
      var previous = -1.0;
      for (final key in actions) {
        final finder = find.byKey(Key(key));
        expect(finder, findsOneWidget);
        final y = tester.getTopLeft(finder).dy;
        expect(y, greaterThan(previous));
        previous = y;
      }
      expect(tester.takeException(), isNull);
      // Home's existing layout is outside this small completion-screen check.
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('drive_complete_home')));
      await tester.tap(find.byKey(const Key('drive_complete_home')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MapScreen, skipOffstage: false), findsNothing);
      expect(f.runtime.owner.lease.requireDrive(id).id, id);
    },
  );

  scenario(
    'new drive creates a clean map without starting GPS and back cannot reveal the old recorder',
    (tester) async {
      final id = await completed(tester);
      await tester.tap(find.byKey(const Key('drive_complete_new')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final state = tester.state(find.byType(MapScreen)) as dynamic;
      expect(state.isDriving, false);
      expect(state.driveStartTime, null);
      expect(state.routeService.distance, 0);
      expect(find.text('SÜRÜŞE BAŞLA'), findsOneWidget);
      await io(tester, () async {
        expect(await ForegroundService.activeSession(), null);
        expect(await f.runtime.gps.journal.lifecycle(id), 'VERIFIED');
      });
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(DriveCompletionScreen), findsNothing);
    },
  );

  scenario(
    'detail and poster use saved ID even when another History entry exists; cancel preserves drive',
    (tester) async {
      final id = await completed(tester);
      final before = driveTransferManifest(
        f.runtime.owner.lease.requireDrive(id),
      );
      await io(
        tester,
        () => f.runtime.owner.lease.put(
          'drives',
          'other',
          DriveSession(
            id: 'other',
            date: DateTime.now().add(const Duration(days: 1)),
            distance: 1,
            durationSeconds: 1,
            averageSpeed: 1,
            maxSpeed: 1,
            mapImagePath: '',
            route: [],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('drive_complete_detail')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final detail = tester.widget<OwnedDriveDetailScreen>(
        find.byType(OwnedDriveDetailScreen),
      );
      expect(detail.driveId, id);
      expect(detail.lease, same(f.runtime.owner.lease));
      expect(
        tester
            .widget<DriveDetailScreen>(find.byType(DriveDetailScreen))
            .drive
            .id,
        id,
      );
      Navigator.of(tester.element(find.byType(DriveDetailScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('drive_complete_poster')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final editor = tester.widget<PosterEditorScreen>(
        find.byType(PosterEditorScreen),
      );
      expect(editor.drive.id, id);
      expect(editor.ownerLease, same(f.runtime.owner.lease));
      for (final entry in {
        'Marka': 'Test',
        'Model': 'Model',
        'Model yılı': '2026',
        'Renk': 'Mavi',
      }.entries) {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.key,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.ensureVisible(find.text('Arkaplan Oluştur'));
      await tester.tap(find.text('Arkaplan Oluştur'));
      await tester.pump();
      expect(find.textContaining('henüz yapılandırılmadı'), findsOneWidget);
      expect(
        driveTransferManifest(f.runtime.owner.lease.requireDrive(id)),
        before,
      );
      Navigator.of(tester.element(find.byType(PosterEditorScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DriveCompletionScreen), findsOneWidget);
      expect(
        driveTransferManifest(f.runtime.owner.lease.requireDrive(id)),
        before,
      );
      expect(find.textContaining('Kayıt tamamlanamadı'), findsNothing);
      await io(
        tester,
        () async =>
            expect(await f.runtime.gps.journal.lifecycle(id), 'VERIFIED'),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  scenario(
    'real application nested owner navigator handles Android back after completion',
    (tester) async {
      late Widget application;
      await io(tester, () async {
        await f.closeRuntime();
        await f.boot(
          application: true,
          mountApplication: (widget) => application = widget,
        );
      });
      await tester.pumpWidget(application);
      final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
      unawaited(navigator.pushNamed('/drive'));
      await _wait(tester, () => find.byType(MapScreen).evaluate().isNotEmpty);
      final state = tester.state(find.byType(MapScreen)) as dynamic;
      await io(tester, () => state.startDriving() as Future<void>);
      await tester.binding.handlePopRoute();
      await _wait(
        tester,
        () => find.text('Devam eden sürüş').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Sürüşe dön'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(state.isDriving, true);
      final drive = await io(tester, () async {
        final active = (await ForegroundService.activeSession())!;
        return f.populate(active.id, active.startedAt, intervals: 16);
      });
      await io(tester, () async {
        unawaited(state.stopDriving() as Future<void>);
      });
      await _wait(
        tester,
        () => find.byType(DriveCompletionScreen).evaluate().isNotEmpty,
      );
      await tester.binding.handlePopRoute();
      await _wait(
        tester,
        () =>
            find.byType(HomeScreen).evaluate().isNotEmpty &&
            find.byType(DriveCompletionScreen).evaluate().isEmpty,
      );
      expect(f.runtime.owner.lease.requireDrive(drive!.id).id, drive.id);
      await io(
        tester,
        () async =>
            expect(await f.runtime.gps.journal.lifecycle(drive.id), 'VERIFIED'),
      );
    },
  );
}
