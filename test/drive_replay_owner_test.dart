import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/drive_replay/drive_replay_screen.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/theme/drive_map_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;

import 'local_owner_integration_test.dart' show TestAuth, a, b;

class _ReplayMaps extends maps.GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) => const SizedBox(key: Key('replay_owner_fake_map'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late TestAuth auth;
  late LocalOwnerLifecycle runtime;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_replay_owner_');
    auth = TestAuth()..userId = a;
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
    );
    await runtime.start();
  });
  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await root.delete(recursive: true);
  });

  DriveSession fixture({int durationSeconds = 60}) => DriveSession(
    id: 'owner-replay',
    date: DateTime.utc(2026),
    distance: 500,
    durationSeconds: durationSeconds,
    averageSpeed: 80,
    maxSpeed: 120,
    mapImagePath: '',
    route: List.generate(
      4,
      (i) => RoutePoint(latitude: 41, longitude: 29 + i / 1000),
    ),
  );

  Future<DriveSession> seedCanonical({int? durationSeconds}) async {
    final totalSeconds = durationSeconds ?? 3;
    final sampleCount = durationSeconds == null ? 4 : 121;
    final drive = fixture(durationSeconds: durationSeconds ?? 60);
    final base = DateTime.utc(2026);
    final points = List.generate(sampleCount, (i) {
      final elapsedSeconds = sampleCount == 1
          ? 0
          : (totalSeconds * i / (sampleCount - 1)).round();
      return CanonicalTelemetryPoint(
        latitude: 41,
        longitude: 29 + i / 1000,
        timestamp: base.add(Duration(seconds: elapsedSeconds)),
        speedMps: i == 2 ? 0 : (i == 3 ? 12 : 4),
        headingDegrees: 90,
        altitudeMeters: 0,
        accuracyMeters: 3,
        distanceFromPreviousMeters: i == 0 ? 0 : 100,
        accelerationMps2: 0,
        speedSource: i == 2 ? 'unavailable' : 'native',
        breakBefore: i == 2,
      );
    });
    await runtime.lease.put('drives', drive.id, drive);
    await runtime.lease.put(
      'drive_telemetry',
      drive.id,
      DriveTelemetryRecord(
        driveSessionId: drive.id,
        dataVersion: DriveTelemetryRecord.currentDataVersion,
        createdAt: base,
        points: points,
      ),
    );
    return drive;
  }

  testWidgets(
    'canonical HUD uses GPS labels and a break is rendered as a gap',
    (tester) async {
      final drive = (await tester.runAsync(seedCanonical))!;
      final platform = _ReplayMaps();
      final oldPlatform = maps.GoogleMapsFlutterPlatform.instance;
      maps.GoogleMapsFlutterPlatform.instance = platform;
      addTearDown(() => maps.GoogleMapsFlutterPlatform.instance = oldPlatform);
      await tester.pumpWidget(
        MaterialApp(
          home: DriveReplayScreen(drive: drive, ownerLease: runtime.lease),
        ),
      );
      await tester.runAsync(DriveMapVisuals.createNavigationArrow);
      await tester.pump();
      expect(find.text('GPS KAYNAKLI HIZ'), findsOneWidget);
      expect(find.text('GPS SÜRESİ'), findsOneWidget);
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers, hasLength(1));
      expect(map.polylines, hasLength(2));
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(.5);
      await tester.pump();
      final gapMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(gapMap.markers, isEmpty);
      expect(gapMap.polylines.map((line) => line.points.length).toList(), [
        2,
        2,
        2,
      ]);
      expect(find.textContaining('GPS verisi yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('canonical preview label reflects adaptive and selected speed', (
    tester,
  ) async {
    final drive = (await tester.runAsync(
      () => seedCanonical(durationSeconds: 1200),
    ))!;
    final platform = _ReplayMaps();
    final oldPlatform = maps.GoogleMapsFlutterPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => maps.GoogleMapsFlutterPlatform.instance = oldPlatform);
    await tester.pumpWidget(
      MaterialApp(
        home: DriveReplayScreen(drive: drive, ownerLease: runtime.lease),
      ),
    );
    expect(
      find.textContaining('GPS 00:00 · Önizleme (1×, efektif 40×)'),
      findsOneWidget,
    );
    expect(find.textContaining('00:00 / 00:30'), findsOneWidget);

    tester
        .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>))
        .onSelected!(5);
    await tester.pump();
    expect(find.textContaining('Önizleme (5×, efektif 200×)'), findsOneWidget);

    tester
        .widget<InkWell>(
          find.ancestor(
            of: find.text('Başla!'),
            matching: find.byType(InkWell),
          ).first,
        )
        .onTap!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.pause_rounded),
            matching: find.byType(IconButton),
          ).first,
        )
        .onPressed!();
    await tester.pump();
    expect(find.text('03:20'), findsOneWidget);
    expect(find.textContaining('00:01 / 00:06'), findsOneWidget);
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      closeTo(1 / 6, 1e-9),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('owner A to B revocation hides cached replay screen', (
    tester,
  ) async {
    final drive = (await tester.runAsync(seedCanonical))!;
    final platform = _ReplayMaps();
    final oldPlatform = maps.GoogleMapsFlutterPlatform.instance;
    maps.GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => maps.GoogleMapsFlutterPlatform.instance = oldPlatform);
    await tester.pumpWidget(
      MaterialApp(
        home: DriveReplayScreen(drive: drive, ownerLease: runtime.lease),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      auth.emit(b);
      await runtime.settled;
    });
    await tester.pump();
    expect(
      find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
      findsOneWidget,
    );
    expect(find.text('GPS KAYNAKLI HIZ'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
