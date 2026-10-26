import 'dart:io';

import 'package:driveit_project/features/drive_replay/drive_replay_screen.dart';
import 'package:driveit_project/features/drive_replay/replay_interpolator.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/theme/drive_map_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

DriveSession replayDrive({double averageSpeed = 36, List<RoutePoint>? route}) =>
    DriveSession(
      id: 'replay-hud-fixture',
      date: DateTime.utc(2026, 1, 1),
      distance: 300,
      durationSeconds: 100,
      averageSpeed: averageSpeed,
      maxSpeed: 80,
      mapImagePath: '',
      route:
          route ??
          [
            RoutePoint(
              latitude: 41,
              longitude: 29,
              legacyHiveFields: {2: DateTime.utc(2025)},
            ),
            RoutePoint(latitude: 41, longitude: 29.001),
            RoutePoint(latitude: 41.001, longitude: 29.003),
          ],
    );

class ReplayTestMaps extends maps.GoogleMapsFlutterPlatform {
  int views = 0;
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) {
    views++;
    // The actual GoogleMap widget still receives marker/polyline updates.
    // No native controller/camera or real location provider is attached.
    return const SizedBox(key: Key('replay_platform_map'));
  }
}

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

Map<String, String> hudValues(WidgetTester tester) => {
  for (final name in ['elapsed', 'distance', 'speed']) name: hud(tester, name),
};

Future<void> mountReplay(WidgetTester tester, DriveSession drive) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: DriveReplayScreen(drive: drive),
    ),
  );
  // Await actual raster work, never a wall-clock delay. The icon's queued
  // raster/encoding work is drained before playback time is advanced.
  await tester.runAsync(DriveMapVisuals.createNavigationArrow);
  await tester.pump();
}

Future<void> step(WidgetTester tester, Duration duration) async {
  var remaining = duration;
  const frameStep = Duration(milliseconds: 16);
  while (remaining > Duration.zero) {
    final delta = remaining > frameStep ? frameStep : remaining;
    await tester.pump(delta);
    remaining -= delta;
  }
  await tester.pump();
}

Future<void> seek(WidgetTester tester, double progress) async {
  tester.widget<Slider>(find.byType(Slider)).onChanged!(progress);
  await tester.pump();
}

void startReplay(WidgetTester tester) {
  final button = tester.widget<InkWell>(
    find
        .ancestor(of: find.text('Başla!'), matching: find.byType(InkWell))
        .first,
  );
  button.onTap!();
}

void toggleReplay(WidgetTester tester, IconData icon) {
  final button = tester.widget<IconButton>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(IconButton))
        .first,
  );
  button.onPressed!();
}

void expectFrame(WidgetTester tester, DriveSession drive, int seconds) {
  final frame = ReplayInterpolator.frameAt(
    ReplayInterpolator.buildTimeline(drive),
    Duration(seconds: seconds),
  );
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  expect(hud(tester, 'elapsed'), '$minutes:$remainder');
  expect(hud(tester, 'speed'), '${frame.speedKmh!.toStringAsFixed(0)} km/h');
  expect(
    hud(tester, 'distance'),
    '${(frame.distanceMeters / 1000).toStringAsFixed(2)} km',
  );
  final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
  final marker = map.markers.single;
  expect(marker.markerId.value, 'driveit_replay_vehicle');
  expect(marker.position.latitude, closeTo(frame.latitude!, 1e-9));
  expect(marker.position.longitude, closeTo(frame.longitude!, 1e-9));
  final trail = map.polylines.singleWhere(
    (p) => p.polylineId.value == 'replay_visited_route',
  );
  expect(trail.points.last, marker.position);
}

int displayedSeconds(WidgetTester tester) {
  final parts = hud(tester, 'elapsed').split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late maps.GoogleMapsFlutterPlatform oldMaps;
  late ReplayTestMaps fakeMaps;
  setUp(() {
    oldMaps = maps.GoogleMapsFlutterPlatform.instance;
    fakeMaps = ReplayTestMaps();
    maps.GoogleMapsFlutterPlatform.instance = fakeMaps;
  });
  tearDown(() => maps.GoogleMapsFlutterPlatform.instance = oldMaps);

  testWidgets(
    'HUD samples at 250ms while map marker continues animating each frame',
    (tester) async {
      final drive = replayDrive();
      await mountReplay(tester, drive);
      expect(fakeMaps.views, greaterThan(0));
      final initialDistance = hud(tester, 'distance');
      startReplay(tester);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 100));
      final movingMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(movingMap.markers.single.position.longitude, greaterThan(29));
      expect(hud(tester, 'elapsed'), '00:00');
      expect(hud(tester, 'distance'), initialDistance);
      await step(tester, const Duration(milliseconds: 150));
      expect(hud(tester, 'elapsed'), isNot('00:00'));
      expect(hud(tester, 'distance'), isNot(initialDistance));

      toggleReplay(tester, Icons.pause_rounded);
      await tester.pump();
      await seek(tester, 0);
      tester
          .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>))
          .onSelected!(5);
      await tester.pump();
      toggleReplay(tester, Icons.play_arrow_rounded);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 100));
      expect(hud(tester, 'elapsed'), '00:00');
      await step(tester, const Duration(milliseconds: 150));
      expect(hud(tester, 'elapsed'), isNot('00:00'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pause freezes all HUD values; resume continues from the same frame',
    (tester) async {
      final drive = replayDrive();
      await mountReplay(tester, drive);
      await seek(tester, .2);
      toggleReplay(tester, Icons.play_arrow_rounded);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 100));
      toggleReplay(tester, Icons.pause_rounded);
      await tester.pump();
      final pausedAt = displayedSeconds(tester);
      expect(pausedAt, inInclusiveRange(20, 21));
      final paused = hudValues(tester);
      final pausedMarker = tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .markers
          .single
          .position;
      await step(tester, const Duration(seconds: 2));
      expect(hudValues(tester), paused);
      expect(
        tester
            .widget<GoogleMap>(find.byType(GoogleMap))
            .markers
            .single
            .position,
        pausedMarker,
      );
      toggleReplay(tester, Icons.play_arrow_rounded);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 100));
      toggleReplay(tester, Icons.pause_rounded);
      await tester.pump();
      final resumedAt = displayedSeconds(tester);
      expect(resumedAt, greaterThan(pausedAt));
      final resumedValues = hudValues(tester);
      await step(tester, const Duration(seconds: 1));
      expect(hudValues(tester), resumedValues);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'paused forward and backward seek immediately synchronize HUD and marker',
    (tester) async {
      final drive = replayDrive();
      await mountReplay(tester, drive);
      await seek(tester, .7);
      expectFrame(tester, drive, 70);
      await seek(tester, .1);
      expectFrame(tester, drive, 10);
      await step(tester, const Duration(seconds: 2));
      expectFrame(tester, drive, 10);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'playback seek and 5x preserve the speed estimate at the same route frame',
    (tester) async {
      final drive = replayDrive();
      await mountReplay(tester, drive);
      await seek(tester, .2);
      toggleReplay(tester, Icons.play_arrow_rounded);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 500));
      final normalAt = displayedSeconds(tester);
      expect(normalAt, inInclusiveRange(24, 25));
      final normal = hudValues(tester);
      toggleReplay(tester, Icons.pause_rounded);
      await tester.pump();
      await seek(tester, .2);
      final seekedValues = hudValues(tester);
      tester
          .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>))
          .onSelected!(5);
      await tester.pump();
      expect(hudValues(tester), seekedValues);
      expect(hud(tester, 'elapsed'), '00:20');
      toggleReplay(tester, Icons.play_arrow_rounded);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 100));
      toggleReplay(tester, Icons.pause_rounded);
      await tester.pump();
      final acceleratedAt = displayedSeconds(tester);
      expect(acceleratedAt, inInclusiveRange(24, 25));
      expect(hudValues(tester)['speed'], isNot(normal['speed']));
      await seek(tester, .6);
      expectFrame(tester, drive, 60);
      await seek(tester, .1);
      expectFrame(tester, drive, 10);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'completion freezes the final frame; restart resets HUD and marker',
    (tester) async {
      final drive = replayDrive();
      await mountReplay(tester, drive);
      await seek(tester, .95);
      toggleReplay(tester, Icons.play_arrow_rounded);
      await tester.pump();
      await step(tester, const Duration(seconds: 1));
      expectFrame(tester, drive, 100);
      expect(find.text('Sürüş tekrarı tamamlandı'), findsOneWidget);
      await step(tester, const Duration(seconds: 2));
      expectFrame(tester, drive, 100);
      toggleReplay(tester, Icons.replay_rounded);
      await tester.pump();
      await step(tester, const Duration(milliseconds: 100));
      toggleReplay(tester, Icons.pause_rounded);
      await tester.pump();
      expect(hud(tester, 'elapsed'), '00:00');
      await step(tester, const Duration(milliseconds: 100));
      final restarted = hudValues(tester);
      final restartedMarker = tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .markers
          .single
          .position;
      await step(tester, const Duration(seconds: 1));
      expect(hudValues(tester), restarted);
      expect(
        tester
            .widget<GoogleMap>(find.byType(GoogleMap))
            .markers
            .single
            .position,
        restartedMarker,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'route-only legacy drive labels estimates without reading a telemetry box',
    (tester) async {
      final drive = replayDrive();
      await mountReplay(tester, drive);
      await seek(tester, .5);
      expectFrame(tester, drive, 50);
      expect(find.text('TAHMİNİ HIZ'), findsOneWidget);
      expect(find.text('TAHMİNİ SÜRE'), findsOneWidget);
      final menu = tester.widget<PopupMenuButton<double>>(
        find.byType(PopupMenuButton<double>),
      );
      final labels = menu
          .itemBuilder(tester.element(find.byType(PopupMenuButton<double>)))
          .whereType<PopupMenuItem<double>>()
          .map((item) => (item.child! as Text).data)
          .toList();
      expect(labels, ['1×', '2×', '3×', '5×']);
      menu.onSelected!(3);
      await tester.pump();
      expect(
        find.textContaining('Önizleme (3×, efektif 30×): 00:01 / 00:03'),
        findsOneWidget,
      );
      expect(find.textContaining('GPS ölçümü değildir'), findsOneWidget);
      expect(find.text('ANLIK HIZ'), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'legacy breakBefore draws separate route segments without a bridge',
    (tester) async {
      final route = [
        RoutePoint(latitude: 41, longitude: 29),
        RoutePoint(latitude: 41, longitude: 29.001),
        RoutePoint(latitude: 41.01, longitude: 29.01, breakBefore: true),
        RoutePoint(latitude: 41.011, longitude: 29.011),
      ];
      await mountReplay(tester, replayDrive(route: route));
      final initial = tester.widget<GoogleMap>(find.byType(GoogleMap));
      final full = initial.polylines
          .where(
            (line) => line.polylineId.value.startsWith('replay_full_segment_'),
          )
          .toList();
      expect(full, hasLength(2));
      expect(full.every((line) => line.points.length == 2), isTrue);
      await seek(tester, .5);
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.position.latitude, closeTo(41.01, .001));
      expect(
        map.polylines
            .where(
              (line) =>
                  line.polylineId.value.startsWith('replay_full_segment_'),
            )
            .every((line) => line.points.length == 2),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final speed in [double.nan, double.infinity, -1.0]) {
    testWidgets('invalid source average $speed never renders a numeric speed', (
      tester,
    ) async {
      await mountReplay(tester, replayDrive(averageSpeed: speed));
      await seek(tester, .5);
      expect(hud(tester, 'speed'), '—');
      expect(hud(tester, 'elapsed'), '00:50');
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final route in [
    <RoutePoint>[],
    [RoutePoint(latitude: 41, longitude: 29)],
  ]) {
    testWidgets(
      '${route.length}-point legacy drive remains safely unavailable',
      (tester) async {
        await mountReplay(tester, replayDrive(route: route));
        expect(find.text('Bu sürüş oynatılamıyor'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'replay controls leave stored Hive bytes and legacy fields unchanged',
    (tester) async {
      late Directory root;
      late HiveImpl hive;
      late DriveSession stored;
      late String boxPath;
      late List<int> before;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('driveit_replay_hud_');
        hive = HiveImpl()
          ..init(root.path)
          ..registerAdapter(DriveSessionAdapter())
          ..registerAdapter(RoutePointAdapter());
        final box = await hive.openBox<DriveSession>('drives');
        await box.put('fixture', replayDrive());
        await box.flush();
        stored = box.get('fixture')!;
        boxPath = box.path!;
        before = await File(boxPath).readAsBytes();
      });
      try {
        await mountReplay(tester, stored);
        await seek(tester, .8);
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();
        await step(tester, const Duration(seconds: 3));
        await tester.tap(find.byIcon(Icons.replay_rounded));
        await tester.pump();
        await seek(tester, .1);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          expect(await File(boxPath).readAsBytes(), before);
          expect(stored.route.first.legacyHiveFields[2], DateTime.utc(2025));
          expect(stored.distance, 300);
          expect(stored.durationSeconds, 100);
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await hive.close();
          await root.delete(recursive: true);
        });
      }
    },
  );
}
