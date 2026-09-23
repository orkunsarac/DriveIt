import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:driveit_project/features/drive_poster/poster_background.dart';
import 'package:driveit_project/features/drive_poster/poster_canvas.dart';
import 'package:driveit_project/features/drive_poster/poster_layout.dart';
import 'package:driveit_project/features/drive_poster/poster_screens.dart';
import 'package:driveit_project/features/drive_poster/poster_store.dart';
import 'package:driveit_project/features/drive_poster/poster_theme.dart';
import 'package:driveit_project/features/drive_poster/drive_route_thumbnail.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

DriveSession sampleDrive() => DriveSession(
  id: 'poster-test-drive',
  date: DateTime(2026, 9, 12, 18, 30),
  distance: 25432,
  durationSeconds: 3601,
  averageSpeed: 25.4,
  maxSpeed: 78.2,
  mapImagePath: '',
  route: [
    RoutePoint(latitude: 40.75, longitude: 29.9),
    RoutePoint(latitude: 40.754, longitude: 29.904),
    RoutePoint(latitude: 40.758, longitude: 29.903),
    RoutePoint(latitude: 40.762, longitude: 29.911),
  ],
);

String get testBackground =>
    File('assets/branding/driveit_hero.png').absolute.path;

double distanceToRect(Offset point, Rect rect) {
  final dx = math.max(rect.left - point.dx, math.max(point.dx - rect.right, 0));
  final dy = math.max(rect.top - point.dy, math.max(point.dy - rect.bottom, 0));
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('route thumbnail renders real, empty, and degenerate routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 160,
              height: 80,
              child: DriveRouteThumbnail(route: sampleDrive().route),
            ),
            SizedBox(
              width: 160,
              height: 80,
              child: DriveRouteThumbnail(route: <RoutePoint>[]),
            ),
            SizedBox(
              width: 160,
              height: 80,
              child: DriveRouteThumbnail(route: [sampleDrive().route.first]),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DriveRouteThumbnail), findsNWidgets(3));
  });

  test('free transforms keep a visible fraction and bounded scale', () {
    for (final size in [const Size(116, 72), posterEditArea.size]) {
      for (final scale in [-100.0, 0.0, .35, 3.0, 100.0, double.nan]) {
        final transform = PosterTransform(
          x: -9,
          y: 9,
          scale: scale,
        ).constrained(size);
        final rect = transform.rect(size);
        expect(transform.scale, inInclusiveRange(.35, 3));
        final visible = rect.intersect(posterEditArea);
        expect(
          visible.width,
          greaterThanOrEqualTo(
            math.min(rect.width, posterEditArea.width) *
                    posterMinimumVisibleFraction -
                1e-8,
          ),
        );
        expect(
          visible.height,
          greaterThanOrEqualTo(
            math.min(rect.height, posterEditArea.height) *
                    posterMinimumVisibleFraction -
                1e-8,
          ),
        );
        expect(
          rect.width / rect.height,
          closeTo(size.width / size.height, 1e-8),
        );
      }
    }
    expect(posterDistrict('Gazanfer Bilge Caddesi, Başiskele'), 'Başiskele');
    expect(posterDistrict('40.70, 29.90'), '—');
  });

  testWidgets('saved poster reopens with the same normalized arrangement', (
    tester,
  ) async {
    const layout = PosterLayout(
      score: PosterTransform(x: .7, y: .4, scale: 1.2),
      route: PosterTransform(x: .5, y: .6, scale: .6),
    );
    final saved = SavedDrivePoster.fromMap(
      SavedDrivePoster(
        id: 'layout-test',
        driveId: sampleDrive().id,
        createdAt: DateTime(2026),
        fileName: 'poster.png',
        backgroundSourceType: PosterBackgroundSourceType.customImage,
        startLabel: 'Yenişehir',
        endLabel: 'Başiskele',
        showMaxSpeed: false,
        layout: layout,
      ).toMap(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PosterEditorScreen(
          drive: sampleDrive(),
          savedPoster: saved,
          savedBackgroundPath: testBackground,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final preview = tester.widget<PosterCanvas>(find.byType(PosterCanvas));
    expect(preview.layout!.toMap(), layout.toMap());
    expect(preview.showMaxSpeed, isFalse);
    expect(preview.showRoute, isTrue);
    expect(find.text('Yenişehir'), findsWidgets);
    expect(find.text('Başiskele'), findsWidgets);
    expect(find.text('Otomatik Yerleştir'), findsNothing);
    expect(find.text('Otomatik Konumlandır'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Sıfırla'),
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('poster_editor_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Sıfırla'), findsOneWidget);
    final scrollFinder = find.byKey(const ValueKey('poster_editor_scroll'));
    expect(
      tester.widget<ListView>(scrollFinder).physics!.allowUserScrolling,
      isTrue,
    );
    final routeArea = find.byKey(const ValueKey('poster_edit_route'));
    await tester.ensureVisible(routeArea);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(routeArea));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    expect(
      tester.widget<ListView>(scrollFinder).physics!.allowUserScrolling,
      isFalse,
    );
    await gesture.up();
    await tester.pump();
    expect(
      tester.widget<ListView>(scrollFinder).physics!.allowUserScrolling,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  test('poster themes keep independent palettes and Classic defaults', () {
    expect(PosterThemeData.fromId(null).id, PosterThemeId.classic);
    expect(posterLogoVariantFromName(null), PosterLogoVariant.symbol);
    expect(PosterThemeData.softWhite.startPinColor, isNot(posterStartPinColor));
    expect(PosterThemeData.softWhite.endPinColor, isNot(posterEndPinColor));
    expect(PosterThemeData.values.map((theme) => theme.displayName), [
      'Classic',
      'Soft White',
      'Ice',
      'Blackout',
    ]);
    expect(PosterThemeData.blackout.routeColor, const Color(0xff25282c));
    expect(posterThemeIdFromName('mono'), PosterThemeId.blackout);
    expect(PosterThemeData.ice.routeColor, const Color(0xffbceaff));

    final legacy = SavedDrivePoster.fromMap({
      'id': 'theme-legacy',
      'driveId': 'drive',
      'createdAt': DateTime(2026).millisecondsSinceEpoch,
      'fileName': 'legacy.png',
    });
    expect(legacy.themeId, 'classic');
    expect(legacy.logoVariant, 'symbol');

    final monoRecord = SavedDrivePoster.fromMap({
      ...legacy.toMap(),
      'themeId': 'mono',
      'logoVariant': 'wordmark',
    });
    expect(monoRecord.themeId, 'blackout');
    expect(monoRecord.toMap()['themeId'], 'blackout');

    final selected = SavedDrivePoster.fromMap({
      ...legacy.toMap(),
      'themeId': 'ice',
      'logoVariant': 'wordmark',
    });
    expect(selected.themeId, 'ice');
    expect(selected.logoVariant, 'wordmark');
  });

  testWidgets('theme and logo selectors update the live poster canvas', (
    tester,
  ) async {
    final saved = SavedDrivePoster(
      id: 'live-theme',
      driveId: sampleDrive().id,
      createdAt: DateTime(2026),
      fileName: 'poster.png',
      backgroundSourceType: PosterBackgroundSourceType.customImage,
      startLabel: 'Yenişehir',
      endLabel: 'Başiskele',
      showMaxSpeed: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PosterEditorScreen(
          drive: sampleDrive(),
          savedPoster: saved,
          savedBackgroundPath: testBackground,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PosterCanvas>(find.byType(PosterCanvas)).themeId,
      PosterThemeId.classic,
    );
    expect(
      tester.widget<PosterCanvas>(find.byType(PosterCanvas)).logoVariant,
      PosterLogoVariant.symbol,
    );

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('poster_editor_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Ice'),
      220,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Ice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('poster_canvas_tap_area')),
      -220,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    var canvas = tester.widget<PosterCanvas>(find.byType(PosterCanvas));
    expect(canvas.themeId, PosterThemeId.ice);
    expect(canvas.logoVariant, PosterLogoVariant.symbol);

    await tester.scrollUntilVisible(
      find.text('DriveIt Yazı'),
      180,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('DriveIt Yazı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DriveIt Yazı'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('poster_canvas_tap_area')),
      -220,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    canvas = tester.widget<PosterCanvas>(find.byType(PosterCanvas));
    expect(canvas.themeId, PosterThemeId.ice);
    expect(canvas.logoVariant, PosterLogoVariant.wordmark);
    final logo = tester.widget<Image>(
      find.byKey(const Key('poster_fixed_logo')),
    );
    expect(
      (logo.image as AssetImage).assetName,
      'assets/onboarding/driveit_wordmark.png',
    );
    final routePaint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is PosterRoutePainter,
      ),
    );
    expect(
      (routePaint.painter! as PosterRoutePainter).theme.id,
      PosterThemeId.ice,
    );
  });

  testWidgets('badge slots share geometry and hidden slots collapse', (
    tester,
  ) async {
    Future<void> pump({
      bool showLocation = true,
      bool showDate = true,
      bool showScore = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PosterCanvas(
                drive: sampleDrive(),
                score: 835,
                startName: 'Yenişehir',
                endName: 'Başiskele',
                showMaxSpeed: true,
                showLocation: showLocation,
                showDate: showDate,
                showScore: showScore,
                backgroundPath: testBackground,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump();
    final logo = tester.getRect(find.byKey(const ValueKey('badge_logo')));
    final startLocation = tester.getRect(
      find.byKey(const ValueKey('badge_location_start')),
    );
    final endLocation = tester.getRect(
      find.byKey(const ValueKey('badge_location_end')),
    );
    final date = tester.getRect(find.byKey(const ValueKey('badge_date')));
    final score = tester.getRect(find.byKey(const ValueKey('badge_score')));
    final column = tester.getRect(
      find.byKey(const ValueKey('poster_badge_column')),
    );
    final canvas = tester.getRect(find.byType(PosterCanvas));
    final scale = canvas.width / posterSize.width;
    expect(column.width, closeTo(posterBadgeColumnWidth * scale, .01));
    expect(
      canvas.right - column.right,
      closeTo(posterBadgeRightMargin * scale, .01),
    );
    expect(column.top - canvas.top, closeTo(posterBadgeTopMargin * scale, .01));
    for (final slot in [startLocation, endLocation, date, score]) {
      expect(slot.width, closeTo(logo.width, .01));
      expect(slot.left, closeTo(logo.left, .01));
      expect(slot.right, closeTo(logo.right, .01));
    }
    final startBadge = tester.getRect(
      find.byKey(const ValueKey('poster_start_badge')),
    );
    final endBadge = tester.getRect(
      find.byKey(const ValueKey('poster_end_badge')),
    );
    final startPin = tester.getRect(
      find.byKey(const ValueKey('poster_start_badge_pin')),
    );
    final endPin = tester.getRect(
      find.byKey(const ValueKey('poster_end_badge_pin')),
    );
    expect(startPin.center.dy, closeTo(startBadge.center.dy, .01));
    expect(endPin.center.dy, closeTo(endBadge.center.dy, .01));
    expect(startPin.size, equals(endPin.size));
    expect(startPin.width, closeTo(posterBadgePinSize * scale, .01));
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('Bitiş'), findsOneWidget);
    final fullScoreTop = score.top;

    await pump(showLocation: false, showDate: false);
    expect(find.byKey(const ValueKey('badge_location_start')), findsNothing);
    expect(find.byKey(const ValueKey('badge_location_end')), findsNothing);
    expect(find.byKey(const ValueKey('badge_date')), findsNothing);
    final collapsedScore = tester.getRect(
      find.byKey(const ValueKey('badge_score')),
    );
    expect(collapsedScore.top, lessThan(fullScoreTop));

    await pump(showLocation: false, showDate: false, showScore: false);
    final collapsedColumn = tester.getRect(
      find.byKey(const ValueKey('poster_badge_column')),
    );
    final logoOnly = tester.getRect(find.byKey(const ValueKey('badge_logo')));
    expect(collapsedColumn.height, closeTo(logoOnly.height, .01));
  });

  testWidgets('route selection, outside tap and visibility toggle stay local', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const layout = PosterLayout(
      score: PosterTransform(),
      route: PosterTransform(x: .48, y: .52, scale: .7),
    );
    final saved = SavedDrivePoster(
      id: 'route-selection',
      driveId: sampleDrive().id,
      createdAt: DateTime(2026),
      fileName: 'poster.png',
      backgroundSourceType: PosterBackgroundSourceType.customImage,
      startLabel: 'Yenişehir',
      endLabel: 'Başiskele',
      showMaxSpeed: true,
      layout: layout,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PosterEditorScreen(
          drive: sampleDrive(),
          savedPoster: saved,
          savedBackgroundPath: testBackground,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('poster_route_move_handle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('poster_route_scale_handle')),
      findsOneWidget,
    );
    final canvas = tester.getRect(find.byType(PosterCanvas));
    await tester.tapAt(canvas.topLeft + const Offset(6, 6));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('poster_route_scale_handle')),
      findsNothing,
    );
    final routeSelector = find.byKey(const ValueKey('poster_select_route'));
    await tester.ensureVisible(routeSelector);
    await tester.tap(routeSelector);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('poster_route_scale_handle')),
      findsOneWidget,
    );

    final toggle = find.widgetWithText(ChoiceChip, 'Rota');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    var preview = tester.widget<PosterCanvas>(find.byType(PosterCanvas));
    expect(preview.showRoute, isFalse);
    expect(find.byKey(const ValueKey('poster_route_visual')), findsNothing);
    expect(
      find.byKey(const ValueKey('poster_route_scale_handle')),
      findsNothing,
    );
    await tester.tap(toggle);
    await tester.pump();
    preview = tester.widget<PosterCanvas>(find.byType(PosterCanvas));
    expect(preview.showRoute, isTrue);
    expect(preview.layout!.route.toMap(), layout.route.toMap());
    expect(find.byKey(const ValueKey('poster_select_route')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('poster_route_scale_handle')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final element in [PosterElement.route]) {
    testWidgets(
      '${element.name} drag and pinch preserve fixed header and source',
      (tester) async {
        final drive = sampleDrive();
        var layout = automaticPosterLayout(projectPosterRoute(drive.route));
        final interactionStates = <bool>[];
        final source = drive.route
            .map((p) => [p.latitude, p.longitude])
            .toList();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setLocalState) => PosterCanvas(
                    drive: drive,
                    score: 738,
                    startName: 'Yenişehir',
                    endName: 'Başiskele',
                    showMaxSpeed: true,
                    backgroundPath: testBackground,
                    layout: layout,
                    selectedElement: element,
                    onTransform: (changed, transform) => setLocalState(() {
                      layout = PosterLayout(
                        score: changed == PosterElement.score
                            ? transform
                            : layout.score,
                        route: changed == PosterElement.route
                            ? transform
                            : layout.route,
                      );
                    }),
                    onInteraction: interactionStates.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final logo = tester.getRect(find.byKey(const Key('poster_fixed_logo')));
        final badge = tester.getRect(find.byKey(const ValueKey('badge_logo')));
        final canvas = tester.getRect(find.byType(PosterCanvas));
        expect(
          badge.right,
          closeTo(
            canvas.right -
                posterBadgeRightMargin * canvas.width / posterSize.width,
            .01,
          ),
        );
        expect(logo.center.dx, closeTo(badge.center.dx, .01));
        expect(find.text('Yenişehir'), findsWidgets);
        expect(find.text('Başiskele'), findsWidgets);
        final moveHandle = find.byKey(
          const ValueKey('poster_route_move_handle'),
        );
        final scaleHandle = find.byKey(
          const ValueKey('poster_route_scale_handle'),
        );
        expect(moveHandle, findsNothing);
        expect(scaleHandle, findsOneWidget);
        final frameRect = tester.getRect(
          find.byKey(const ValueKey('poster_route_selection_frame')),
        );
        final scaleHandleRect = tester.getRect(scaleHandle);
        expect(scaleHandleRect.center.dx, closeTo(frameRect.right, .01));
        expect(scaleHandleRect.center.dy, closeTo(frameRect.bottom, .01));
        final beforeHandleScale = layout.route.scale;
        await tester.drag(scaleHandle, const Offset(35, 35));
        await tester.pump();
        expect(layout.route.scale, greaterThan(beforeHandleScale));
        expect(interactionStates, containsAllInOrder([true, false]));
        final target = find.byKey(ValueKey('poster_edit_${element.name}'));
        final before = element == PosterElement.score
            ? layout.score
            : layout.route;
        await tester.drag(target, const Offset(15, 10));
        await tester.pump();
        final moved = element == PosterElement.score
            ? layout.score
            : layout.route;
        expect(moved.x, isNot(before.x));
        final center = tester.getCenter(target);
        final a = await tester.startGesture(
          center - const Offset(25, 0),
          pointer: 1,
        );
        final b = await tester.startGesture(
          center + const Offset(25, 0),
          pointer: 2,
        );
        await tester.pump();
        await a.moveTo(center - const Offset(45, 0));
        await b.moveTo(center + const Offset(45, 0));
        await tester.pump();
        await a.up();
        await b.up();
        await tester.pump();
        final scaled = element == PosterElement.score
            ? layout.score
            : layout.route;
        expect(scaled.scale, greaterThan(before.scale));
        expect(
          tester.getRect(find.byKey(const Key('poster_fixed_logo'))),
          logo,
        );
        expect(
          drive.route.map((p) => [p.latitude, p.longitude]).toList(),
          source,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PosterStore.channel, (call) async {
          if (call.method == 'endpointNames') return <String, String>{};
          if (call.method == 'saveToGallery') {
            return 'content://media/external/images/media/42';
          }
          return null;
        });
  });

  test('AI prompt uses selections and forbids generated overlay data', () {
    const request = PosterBackgroundRequest(
      brand: 'Volvo',
      model: 'S60',
      year: '2024',
      color: 'Mavi',
      scene: PosterScenePreset.rainyHighway,
    );
    expect(request.prompt, contains('Brand: Volvo'));
    expect(request.prompt, contains('Model: S60'));
    expect(request.prompt, contains('Year: 2024'));
    expect(request.prompt, contains('Color: Mavi'));
    expect(request.prompt, contains('Scene: Yağmurlu Otoyol'));
    for (final forbidden in [
      'Do not generate any text.',
      'Do not generate logos.',
      'Do not generate maps.',
      'Do not generate route lines.',
      'Do not generate statistics.',
    ]) {
      expect(request.prompt, contains(forbidden));
    }
    expect(PosterScenePreset.values, hasLength(8));
  });

  test(
    'unconfigured AI provider fails explicitly without a fake image',
    () async {
      final result = await const UnconfiguredPosterBackgroundGenerator()
          .generate(
            const PosterBackgroundRequest(
              brand: 'BMW',
              model: 'M3',
              year: '2025',
              color: 'Siyah',
              scene: PosterScenePreset.cityLights,
            ),
          );
      expect(result.isSuccess, isFalse);
      expect(result.imagePath, isNull);
      expect(result.errorMessage, contains('yapılandırılmadı'));
    },
  );

  test('route projection is deterministic and does not mutate source', () {
    final drive = sampleDrive();
    final before = drive.route
        .map((point) => [point.latitude, point.longitude])
        .toList();
    final projected = projectPosterRoute(drive.route);
    expect(projected, hasLength(drive.route.length));
    expect(projected.every(posterRouteRect.contains), isTrue);
    expect(
      drive.route.map((point) => [point.latitude, point.longitude]).toList(),
      before,
    );
    expect(projectPosterRoute(drive.route), projected);
  });

  test('empty and degenerate routes remain safe; duration keeps hours', () {
    expect(projectPosterRoute([]), isEmpty);
    expect(
      projectPosterRoute([RoutePoint(latitude: 40, longitude: 29)]).single,
      posterRouteRect.center,
    );
    expect(posterDuration(5315), '01:28:35');
  });

  test('score placement avoids route and endpoint occupied areas', () {
    final leftRoute = [
      const Offset(35, 190),
      const Offset(35, 390),
      const Offset(80, 450),
    ];
    expect(posterScoreRect(leftRoute).left, greaterThan(180));
    final rightRoute = [
      const Offset(280, 190),
      const Offset(280, 390),
      const Offset(250, 450),
    ];
    expect(posterScoreRect(rightRoute).left, lessThan(180));
  });

  test('endpoint labels stay near pins and do not overlap each other', () {
    final route = [
      const Offset(150, 290),
      const Offset(220, 290),
      const Offset(300, 290),
    ];
    final labels = posterLocationLabelRects(route);
    expect(labels, hasLength(2));
    expect(labels.first.overlaps(labels.last), isFalse);
    expect(distanceToRect(route.first, labels.first), lessThanOrEqualTo(10));
    expect(distanceToRect(route.last, labels.last), lessThanOrEqualTo(10));
    expect(labels.first.right, lessThan(route.first.dx));
    expect(labels.last.right, lessThan(route.last.dx));
    expect(labels.first.contains(route[1]), isFalse);
    expect(labels.last.contains(route[1]), isFalse);
  });

  test('endpoint label direction and poster-edge fallback remain close', () {
    final vertical = [
      const Offset(180, 300),
      const Offset(180, 230),
      const Offset(180, 160),
    ];
    final verticalLabels = posterLocationLabelRects(vertical);
    expect(verticalLabels.first.top, greaterThan(vertical.first.dy));
    expect(verticalLabels.last.top, greaterThan(vertical.last.dy));
    expect(
      distanceToRect(vertical.first, verticalLabels.first),
      lessThanOrEqualTo(10),
    );
    expect(
      distanceToRect(vertical.last, verticalLabels.last),
      lessThanOrEqualTo(10),
    );

    final boundary = [
      const Offset(9, 18),
      const Offset(80, 18),
      const Offset(160, 18),
    ];
    final boundaryLabels = posterLocationLabelRects(boundary);
    for (var index = 0; index < boundaryLabels.length; index++) {
      final marker = index == 0 ? boundary.first : boundary.last;
      expect(boundaryLabels[index].left, greaterThanOrEqualTo(8));
      expect(boundaryLabels[index].top, greaterThanOrEqualTo(8));
      expect(
        distanceToRect(marker, boundaryLabels[index]),
        lessThanOrEqualTo(10),
      );
      expect(boundaryLabels[index].contains(marker), isFalse);
    }
  });

  test('legacy poster metadata remains readable', () {
    final restored = SavedDrivePoster.fromMap({
      'id': 'legacy',
      'driveId': 'drive',
      'createdAt': DateTime(2026).millisecondsSinceEpoch,
      'fileName': 'legacy.png',
    });
    expect(
      restored.backgroundSourceType,
      PosterBackgroundSourceType.customImage,
    );
    expect(restored.showMaxSpeed, isTrue);
    expect(restored.showRoute, isTrue);
    expect(restored.startLabel, isEmpty);
    expect(restored.layout, isNull);
    expect(restored.themeId, 'classic');
    expect(restored.logoVariant, 'symbol');
  });

  test('rich poster metadata and PNG survive Hive reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'driveit_poster_test_',
    );
    final source = File('${directory.path}/source.png');
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
    await source.writeAsBytes(png);
    try {
      Hive.init(directory.path);
      var box = await Hive.openBox<dynamic>(PosterStore.boxName);
      final saved = await PosterStore(box, directory).save(
        PosterSaveRequest(
          driveId: 'original-drive',
          png: png,
          backgroundSourceType: PosterBackgroundSourceType.aiGenerated,
          backgroundPath: source.path,
          aiVehicle: const {
            'brand': 'Volvo',
            'model': 'S60',
            'year': '2024',
            'color': 'Mavi',
            'scene': 'rainyHighway',
          },
          startLabel: 'Başlangıç',
          endLabel: 'Bitiş',
          showMaxSpeed: false,
          showRoute: false,
          themeId: 'ice',
          logoVariant: 'wordmark',
          layout: const PosterLayout(
            score: PosterTransform(x: .3, y: .4, scale: .8),
            route: PosterTransform(x: .5, y: .55, scale: .7),
          ),
        ),
      );
      expect(await PosterStore(box, directory).file(saved).exists(), isTrue);
      expect(saved.backgroundFileName, isNotNull);
      await box.close();
      box = await Hive.openBox<dynamic>(PosterStore.boxName);
      final restored = PosterStore(box, directory).all.single;
      expect(restored.driveId, 'original-drive');
      expect(
        restored.backgroundSourceType,
        PosterBackgroundSourceType.aiGenerated,
      );
      expect(restored.aiVehicle?['scene'], 'rainyHighway');
      expect(restored.startLabel, 'Başlangıç');
      expect(restored.endLabel, 'Bitiş');
      expect(restored.showMaxSpeed, isFalse);
      expect(restored.showRoute, isFalse);
      expect(restored.themeId, 'ice');
      expect(restored.logoVariant, 'wordmark');
      expect(restored.layout!.score.toMap(), {'x': .3, 'y': .4, 'scale': .8});
      expect(restored.layout!.route.scale, .7);
      await box.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'poster delete removes local files and Hive but preserves gallery copy',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'driveit_delete_test_',
      );
      final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
      try {
        Hive.init(directory.path);
        final box = await Hive.openBox<dynamic>(PosterStore.boxName);
        final saved = await PosterStore(box, directory).save(
          PosterSaveRequest(
            driveId: 'delete-drive',
            png: png,
            backgroundSourceType: PosterBackgroundSourceType.customImage,
            startLabel: 'Başlangıç',
            endLabel: 'Bitiş',
            showMaxSpeed: true,
          ),
        );
        final galleryCopy = File('${directory.path}/gallery-copy.png');
        await galleryCopy.writeAsBytes(png);
        final store = PosterStore(box, directory);
        expect(await store.file(saved).exists(), isTrue);
        await store.delete(saved);
        expect(box.containsKey(saved.id), isFalse);
        expect(await store.file(saved).exists(), isFalse);
        expect(await galleryCopy.exists(), isTrue);
        await box.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'poster delete tolerates a missing local PNG and removes stale Hive record',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'driveit_delete_stale_test_',
      );
      try {
        Hive.init(directory.path);
        final box = await Hive.openBox<dynamic>(PosterStore.boxName);
        final saved = SavedDrivePoster(
          id: 'stale-poster',
          driveId: 'stale-drive',
          createdAt: DateTime(2026),
          fileName: 'missing.png',
          backgroundSourceType: PosterBackgroundSourceType.customImage,
          startLabel: '',
          endLabel: '',
          showMaxSpeed: true,
        );
        await box.put(saved.id, saved.toMap());
        await PosterStore(box, directory).delete(saved);
        expect(box.containsKey(saved.id), isFalse);
        await box.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'gallery export validates a temporary PNG and returns MediaStore URI',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'driveit_gallery_test_',
      );
      final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
      try {
        Hive.init(directory.path);
        final box = await Hive.openBox<dynamic>('gallery_export_test');
        String? bridgedPath;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PosterStore.channel, (call) async {
              if (call.method != 'saveToGallery') return null;
              final arguments = Map<Object?, Object?>.from(
                call.arguments as Map,
              );
              bridgedPath = arguments['path'] as String;
              final source = File(bridgedPath!);
              expect(await source.exists(), isTrue);
              expect(await source.length(), png.length);
              expect(arguments['name'], startsWith('DriveIt_Poster_'));
              return 'content://media/external/images/media/99';
            });
        final uri = await PosterStore(
          box,
          directory,
          temporaryDirectory: directory,
        ).savePngToGallery(png);
        expect(uri, 'content://media/external/images/media/99');
        expect(bridgedPath, isNotNull);
        expect(await File(bridgedPath!).exists(), isFalse);
        await box.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'poster exports 1080x1920 and redistributes three metrics without map UI',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: PosterCanvas(
                  drive: sampleDrive(),
                  score: 738,
                  startName: 'İzmit',
                  endName: 'Gölcük',
                  showMaxSpeed: false,
                  backgroundPath: testBackground,
                  layout: const PosterLayout(
                    score: PosterTransform(x: .75, y: .3, scale: 1.1),
                    route: PosterTransform(x: .4, y: .55, scale: .6),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('738'), findsOneWidget);
      expect(find.text('MESAFE'), findsOneWidget);
      expect(find.text('SÜRE'), findsOneWidget);
      expect(find.text('ORT. HIZ'), findsOneWidget);
      expect(find.text('MAKS. HIZ'), findsNothing);
      expect(find.textContaining('Google'), findsNothing);
      expect(find.byKey(const ValueKey('poster_edit_score')), findsNothing);
      expect(find.byKey(const ValueKey('poster_edit_route')), findsNothing);
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        expect(image.width, 1080);
        expect(image.height, 1920);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        expect(bytes, isNotNull);
      });
    },
  );

  testWidgets('hidden route is absent from the export canvas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterCanvas(
            drive: sampleDrive(),
            score: 738,
            startName: 'İzmit',
            endName: 'Gölcük',
            showMaxSpeed: true,
            showRoute: false,
            backgroundPath: testBackground,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('poster_route_visual')), findsNothing);
    expect(
      find.byKey(const ValueKey('poster_route_scale_handle')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('route keeps endpoint pins without route location text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterCanvas(
            drive: sampleDrive(),
            score: 738,
            startName: 'İzmit',
            endName: 'Gölcük',
            showMaxSpeed: true,
            showLocation: false,
            backgroundPath: testBackground,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('poster_route_visual')), findsOneWidget);
    expect(find.text('İzmit'), findsNothing);
    expect(find.text('Gölcük'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels and unavailable score render without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FittedBox(
            child: PosterCanvas(
              drive: sampleDrive(),
              score: null,
              startName: 'Çok uzun başlangıç konumu ' * 4,
              endName: 'Çok uzun bitiş konumu ' * 4,
              showMaxSpeed: true,
              backgroundPath: testBackground,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DRIVE SCORE · VERİ YOK'), findsOneWidget);
    expect(find.text('MAKS. HIZ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor starts directly at the three-option background step', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: PosterEditorScreen(drive: sampleDrive()),
      ),
    );
    await tester.pump();
    expect(find.text('Arkaplan Seç'), findsOneWidget);
    expect(find.text('Kendi Görselimi Kullan'), findsOneWidget);
    expect(find.text('Araç Fotoğrafımı Kullan'), findsOneWidget);
    expect(find.text('AI ile Arkaplan Oluştur'), findsOneWidget);
    expect(find.byType(PosterCanvas), findsNothing);
  });

  testWidgets('home card still opens existing poster center flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const HomeScreen()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(const Key('home_poster_card')));
    await tester.tap(find.byKey(const Key('home_poster_card')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Poster oluşturmak için sürüş seçin'), findsOneWidget);
  });

  testWidgets('post-drive prompt opens exact drive at background step', (
    tester,
  ) async {
    final drive = sampleDrive();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => offerDrivePoster(context, drive),
              child: const Text('Saved'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poster Oluştur'));
    await tester.pumpAndSettle();
    final editor = tester.widget<PosterEditorScreen>(
      find.byType(PosterEditorScreen),
    );
    expect(editor.drive, same(drive));
    expect(find.text('Arkaplan Seç'), findsOneWidget);
  });
}
