import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/features/drive_replay/drive_replay_screen.dart';
import 'package:driveit_project/features/drive_replay/replay_interpolator.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:integration_test/integration_test.dart';

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
  expect(hud(tester, 'speed'), '${frame.speedKmh.toStringAsFixed(0)} km/h');
  expect(
    hud(tester, 'distance'),
    '${(frame.distanceMeters / 1000).toStringAsFixed(2)} km',
  );
  final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
  expect(map.markers.single.position.latitude, closeTo(frame.latitude, 1e-9));
  expect(map.markers.single.position.longitude, closeTo(frame.longitude, 1e-9));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('DI007 stage 1 HUD agrees with replay marker on Android', (
    tester,
  ) async {
    expect(SupabaseBootstrap.isIsolatedAndroidTest, true);
    expect(await SupabaseBootstrap.initializeIfConfigured(), false);
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
}
