import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/features/drive_replay/drive_replay_screen.dart';
import 'package:driveit_project/features/drive_replay/replay_interpolator.dart';
import 'package:driveit_project/features/drive_replay/replay_telemetry_adapter.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

String hud(WidgetTester tester, String name) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(Key('replay_hud_$name')),
        matching: find.byType(Text),
      ),
    )
    .singleWhere((text) => text.textSpan != null)
    .textSpan!
    .toPlainText();

class _ReplayAndroidMaps extends maps.GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) => const SizedBox(key: Key('replay_android_map_surface'));
}

void expectFrame(WidgetTester tester, DriveSession drive) {
  final progress = tester.widget<Slider>(find.byType(Slider)).value;
  final elapsed = Duration(
    microseconds: (drive.durationSeconds * 1000000 * progress).round(),
  );
  final frame = ReplayInterpolator.frameAt(
    ReplayInterpolator.buildTimeline(drive),
    elapsed,
  );
  final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  expect(hud(tester, 'elapsed'), '$minutes:$seconds');
  expect(hud(tester, 'speed'), '${frame.speedKmh!.toStringAsFixed(0)} km/h');
  expect(
    hud(tester, 'distance'),
    '${(frame.distanceMeters / 1000).toStringAsFixed(2)} km',
  );
  final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
  expect(map.markers.single.position.latitude, closeTo(frame.latitude!, 1e-9));
  expect(
    map.markers.single.position.longitude,
    closeTo(frame.longitude!, 1e-9),
  );
}

void expectCanonicalFrame(
  WidgetTester tester,
  ReplayTelemetryData data,
  Duration totalDuration,
) {
  final progress = tester.widget<Slider>(find.byType(Slider)).value;
  final elapsed = Duration(
    microseconds: (totalDuration.inMicroseconds * progress).round(),
  );
  final frame = ReplayInterpolator.frameAtTelemetry(data, elapsed);
  final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  expect(hud(tester, 'elapsed'), '$minutes:$seconds');
  expect(
    hud(tester, 'distance'),
    '${(frame.distanceMeters / 1000).toStringAsFixed(2)} km',
  );
  final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
  if (frame.isGap || frame.latitude == null || frame.longitude == null) {
    expect(map.markers, isEmpty);
    expect(hud(tester, 'speed'), '—');
  } else {
    expect(map.markers, hasLength(1));
    expect(
      map.markers.single.position.latitude,
      closeTo(frame.latitude!, 1e-9),
    );
    expect(
      map.markers.single.position.longitude,
      closeTo(frame.longitude!, 1e-9),
    );
    expect(
      hud(tester, 'speed'),
      frame.speedKmh == null
          ? '—'
          : '${frame.speedKmh!.toStringAsFixed(0)} km/h',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('DI007 stage 1 HUD agrees with replay marker on Android', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    expect(await SupabaseBootstrap.initializeIfConfigured(), false);
    maps.GoogleMapsFlutterPlatform.instance = _ReplayAndroidMaps();
    // In-memory fixture only. No GPS, account, drive box or journal is opened.
    final drive = DriveSession(
      id: 'synthetic-replay-hud',
      date: DateTime.utc(2026),
      distance: 300,
      durationSeconds: 100,
      averageSpeed: 36,
      maxSpeed: 80,
      mapImagePath: '',
      route: [
        RoutePoint(latitude: 41, longitude: 29),
        RoutePoint(latitude: 41, longitude: 29.001),
        RoutePoint(latitude: 41.001, longitude: 29.003),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DriveReplayScreen(drive: drive),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('GPS ölçümü değildir'), findsOneWidget);
    await tester.tap(find.text('Başla!'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expectFrame(tester, drive);
    final paused = [
      for (final key in ['speed', 'distance', 'elapsed']) hud(tester, key),
    ];
    final progress = tester.widget<Slider>(find.byType(Slider)).value;
    await tester.pump(const Duration(milliseconds: 250));
    expect([
      for (final key in ['speed', 'distance', 'elapsed']) hud(tester, key),
    ], paused);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      greaterThan(progress),
    );
    expectFrame(tester, drive);
    for (final target in [.7, .1]) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(target);
      await tester.pump();
      expectFrame(tester, drive);
    }
    tester
        .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>))
        .onSelected!(5);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expectFrame(tester, drive);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();
    expectFrame(tester, drive);
    expect(find.text('Sürüş tekrarı tamamlandı'), findsOneWidget);
    tester
        .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>))
        .onSelected!(1);
    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, lessThan(1));
    expect(find.text('Sürüş tekrarı tamamlandı'), findsNothing);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0);
    await tester.pump();
    expectFrame(tester, drive);
    expect(drive.distance, 300);
    expect(drive.durationSeconds, 100);
    expect(tester.takeException(), null);
    debugPrint(
      'DI007_EMULATOR: play/pause/resume/seek/5x/complete/restart HUD and marker agree',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets(
    'DI007 canonical replay gaps hide marker and preserve route segments',
    (tester) async {
      expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
      maps.GoogleMapsFlutterPlatform.instance = _ReplayAndroidMaps();
      final root = await (await getApplicationSupportDirectory()).createTemp(
        'driveit_replay_canonical_',
      );
      Hive.init(root.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DriveSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RoutePointAdapter());
      }
      DriveTelemetryHive.registerAdapters(Hive);
      final drives = await Hive.openBox<DriveSession>('drives');
      await DriveTelemetryHive.openBox(Hive);
      final base = DateTime.utc(2026, 8, 1);
      final route = List.generate(
        5,
        (i) => RoutePoint(
          latitude: 41,
          longitude: 29 + i / 1000,
          breakBefore: i == 2,
        ),
      );
      final drive = DriveSession(
        id: 'synthetic-canonical-replay',
        date: DateTime.utc(2026),
        distance: 12000,
        durationSeconds: 1200,
        averageSpeed: 72,
        maxSpeed: 120,
        mapImagePath: '',
        route: route,
      );
      final points = List.generate(241, (i) {
        final longitude = i < 4 ? 29 + i / 1000 : 29.003 + (i - 3) * .0011;
        return CanonicalTelemetryPoint(
          latitude: 41,
          longitude: longitude,
          timestamp: base.add(Duration(seconds: i * 5)),
          speedMps: i == 3 ? 8 : 12,
          headingDegrees: 90,
          altitudeMeters: 0,
          accuracyMeters: 3,
          distanceFromPreviousMeters: i == 0 ? 0 : 100,
          accelerationMps2: 0,
          speedSource: switch (i) {
            2 => 'unavailable',
            3 => 'geometry_estimate',
            _ => 'native',
          },
          breakBefore: i == 2,
        );
      });
      await drives.put(drive.id, drive);
      await DriveTelemetryStorageService.save(
        driveSessionId: drive.id,
        points: points,
        acquisitionMetadata: const {'preserveCanonicalTimestampV1': true},
      );
      await drives.flush();
      await Hive.box<DriveTelemetryRecord>('drive_telemetry').flush();
      final savedTelemetry = Hive.box<DriveTelemetryRecord>(
        'drive_telemetry',
      ).get(drive.id)!;
      expect(savedTelemetry.points, hasLength(241));
      expect(savedTelemetry.points[2].speedSource, 'unavailable');
      expect(savedTelemetry.points[3].speedSource, 'geometry_estimate');
      final replayData = ReplayTelemetryAdapter.build(drive, savedTelemetry);
      expect(replayData.source, ReplayTelemetrySource.canonical);
      expect(
        replayData.samples[3].speedSource,
        ReplaySpeedSource.geometryEstimate,
      );
      expect(replayData.samples[3].speedKmh, closeTo(28.8, 1e-9));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DriveReplayScreen(drive: drive),
        ),
      );
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (tester
            .widget<GoogleMap>(find.byType(GoogleMap))
            .markers
            .isNotEmpty) {
          break;
        }
      }
      final initialMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(initialMap.markers, hasLength(1));
      expect(find.text('KAYITLI GPS MESAFESİ'), findsOneWidget);
      expect(find.text('GPS SÜRESİ'), findsOneWidget);
      expect(find.text('GPS KAYNAKLI HIZ'), findsOneWidget);
      expect(
        find.textContaining('GPS 00:00 · Önizleme (1×, efektif 40×)'),
        findsOneWidget,
      );
      expect(find.textContaining('00:00 / 00:30'), findsOneWidget);
      final speedControl = tester.widget<PopupMenuButton<double>>(
        find.byType(PopupMenuButton<double>),
      );
      for (final (speed, effective) in [
        (1.0, 40.0),
        (2.0, 80.0),
        (5.0, 200.0),
        (10.0, 400.0),
      ]) {
        speedControl.onSelected!(speed);
        await tester.pump();
        expect(
          find.textContaining(
            'Önizleme (${speed.toInt()}×, efektif ${effective.toInt()}×)',
          ),
          findsOneWidget,
        );
        final previewSeconds = (30 / speed).round().toString().padLeft(2, '0');
        expect(
          find.textContaining('00:00 / 00:$previewSeconds'),
          findsOneWidget,
        );
      }
      speedControl.onSelected!(5);
      await tester.pump();
      await tester.tap(find.text('Başla!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expectCanonicalFrame(tester, replayData, const Duration(seconds: 1200));
      final pausedHud = [
        hud(tester, 'speed'),
        hud(tester, 'distance'),
        hud(tester, 'elapsed'),
      ];
      final pausedProgress = tester.widget<Slider>(find.byType(Slider)).value;
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect([
        hud(tester, 'speed'),
        hud(tester, 'distance'),
        hud(tester, 'elapsed'),
      ], pausedHud);
      expect(tester.widget<Slider>(find.byType(Slider)).value, pausedProgress);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        greaterThan(pausedProgress),
      );
      expectCanonicalFrame(tester, replayData, const Duration(seconds: 1200));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      tester.widget<Slider>(find.byType(Slider)).onChanged!(.005);
      await tester.pump();
      final gapMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(gapMap.markers, isEmpty);
      expect(find.text('GPS verisi yok · mesafe sabit'), findsOneWidget);
      expect(hud(tester, 'speed'), '—');
      expect(hud(tester, 'distance'), '0.10 km');
      expect(hud(tester, 'elapsed'), '00:06');
      final fullSegments =
          gapMap.polylines
              .where(
                (line) =>
                    line.polylineId.value.startsWith('replay_full_segment_'),
              )
              .toList()
            ..sort((a, b) => a.polylineId.value.compareTo(b.polylineId.value));
      expect(fullSegments, hasLength(2));
      expect(fullSegments.map((line) => line.points.length), [2, 239]);
      expect(fullSegments[0].points.map((point) => point.longitude), [
        closeTo(29, 1e-9),
        closeTo(29.001, 1e-9),
      ]);
      expect(fullSegments[1].points.take(3).map((point) => point.longitude), [
        closeTo(29.002, 1e-9),
        closeTo(29.003, 1e-9),
        closeTo(29.0041, 1e-9),
      ]);
      expect(
        gapMap.polylines
            .where(
              (line) =>
                  line.polylineId.value.startsWith('replay_visited_segment_'),
            )
            .map((line) => line.polylineId.value),
        ['replay_visited_segment_0'],
      );

      tester.widget<Slider>(find.byType(Slider)).onChanged!(.0125);
      await tester.pump();
      final afterGap = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(afterGap.markers, hasLength(1));
      expect(afterGap.markers.single.position.longitude, closeTo(29.003, 1e-9));
      final speedLabels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('replay_hud_speed')),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? text.textSpan?.toPlainText())
          .toList();
      expect(speedLabels, contains('TAHMİNİ HIZ'), reason: '$speedLabels');
      final forwardTrail =
          afterGap.polylines
              .where(
                (line) =>
                    line.polylineId.value.startsWith('replay_visited_segment_'),
              )
              .toList()
            ..sort((a, b) => a.polylineId.value.compareTo(b.polylineId.value));
      expect(forwardTrail.map((line) => line.polylineId.value), [
        'replay_visited_segment_0',
        'replay_visited_segment_1',
      ]);
      expect(forwardTrail.map((line) => line.points.length), [2, 2]);
      expect(forwardTrail[1].points.map((point) => point.longitude), [
        closeTo(29.002, 1e-9),
        closeTo(29.003, 1e-9),
      ]);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(.0020833333);
      await tester.pump();
      final backward = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
        backward.markers.single.position.longitude,
        closeTo(29.0005, 1e-9),
      );
      final backwardTrail = backward.polylines
          .where(
            (line) =>
                line.polylineId.value.startsWith('replay_visited_segment_'),
          )
          .toList();
      expect(backwardTrail, hasLength(1));
      expect(backwardTrail.single.polylineId.value, 'replay_visited_segment_0');
      expect(backwardTrail.single.points, hasLength(2));
      expect(
        backwardTrail.single.points.last.longitude,
        closeTo(29.0005, 1e-9),
      );

      tester.widget<Slider>(find.byType(Slider)).onChanged!(.0125);
      await tester.pump();
      final seekForward = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
        seekForward.markers.single.position.longitude,
        closeTo(29.003, 1e-9),
      );
      expect(
        seekForward.polylines
            .where(
              (line) =>
                  line.polylineId.value.startsWith('replay_visited_segment_'),
            )
            .map((line) => line.polylineId.value),
        ['replay_visited_segment_0', 'replay_visited_segment_1'],
      );

      tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
      await tester.pump();
      expect(find.text('Sürüş tekrarı tamamlandı'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pump();
      expect(find.text('Sürüş tekrarı tamamlandı'), findsNothing);
      expect(tester.widget<Slider>(find.byType(Slider)).value, lessThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await Hive.close();
      await root.delete(recursive: true);
    },
  );
}
