import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:driveit_project/main.dart' as app;
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/features/onboarding/screens/onboarding_screen.dart';
import 'package:driveit_project/screens/drive_detail_screen.dart';
import 'package:driveit_project/features/drive_poster/poster_canvas.dart';
import '../test/support/legacy_route_fixture.dart';

// Emulator-only application sandbox, with synthetic legacy frames. Never run
// this test against a user's installed app or device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android startup opens legacy DateTime route field 2', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final legacyHive = HiveImpl()
      ..init((await getApplicationDocumentsDirectory()).path);
    legacyHive.registerAdapter(LegacyDriveFixtureAdapter());
    legacyHive.registerAdapter(LegacyRouteFixtureAdapter());
    final old = await legacyHive.openBox<LegacyDriveFixture>('drives');
    final time = DateTime.utc(2025, 9, 28);
    await old.put(
      'legacy',
      LegacyDriveFixture([
        LegacyRouteFixture(time),
        const LegacyRouteFixture(null),
      ]),
    );
    await legacyHive.close();
    app.main();
    for (
      var i = 0;
      i < 100 && find.byType(OnboardingScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    final drive = Hive.box<DriveSession>('drives').get('legacy')!;
    expect(drive.route.length, 2);
    expect(drive.route.first.legacyHiveFields[2], time);
    expect(drive.route.first.breakBefore, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(home: DriveDetailScreen(drive: drive)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(DriveDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterCanvas(
            drive: drive,
            score: null,
            startName: '',
            endName: '',
            showMaxSpeed: true,
            backgroundPath: '',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PosterCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Repeated rapid detail removal exercises a pending 350 ms camera fit.
    // Each new State must own/cancel its own request, never the next screen's.
    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.pumpWidget(
        MaterialApp(
          home: DriveDetailScreen(key: ValueKey(attempt), drive: drive),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      expect(tester.takeException(), isNull, reason: 'rapid removal $attempt');
    }
  });
}
