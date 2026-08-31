import 'dart:ui' as ui;
import 'dart:io';

import 'package:driveit_project/main.dart';
import 'package:driveit_project/screens/world_mode_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _artwork = 'assets/images/world_card_digital_horizon.webp';

void main() {
  setUpAll(() async {
    const fontPath = String.fromEnvironment('WORLD_CARD_CAPTURE_FONT');
    if (fontPath.isNotEmpty) {
      final loader = FontLoader('Noto Sans')
        ..addFont(
          File(
            fontPath,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  testWidgets('World artwork decodes at its native near-2K resolution', (
    tester,
  ) async {
    final data = await rootBundle.load(_artwork);
    final codec = await tester.runAsync(
      () => ui.instantiateImageCodec(data.buffer.asUint8List()),
    );
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    expect(frame!.image.width, 1958);
    expect(frame.image.height, 803);
    expect(frame.image.width / frame.image.height, closeTo(346 / 142, .002));
    frame.image.dispose();
    codec!.dispose();
  });

  for (final width in [320.0, 360.0, 384.0, 412.0, 480.0]) {
    testWidgets(
      'World card retains bounds, typography and outline at $width dp',
      (tester) async {
        // Obtain the actual private card widget, not a test-only imitation.
        await tester.pumpWidget(const DriveItApp());
        final card = tester
            .widget<GestureDetector>(find.byKey(const Key('home_world_card')))
            .child!;
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          DriveItApp(
            initialScreen: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      key: const Key('world_card_capture'),
                      child: card,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(_artwork),
            tester.element(find.byWidget(card)),
          ),
        );
        await tester.pump();
        final imageFinder = find.byType(Image);
        final image = tester.widget<Image>(imageFinder);
        expect((image.image as AssetImage).assetName, _artwork);
        expect(image.fit, BoxFit.cover);
        expect(image.alignment, Alignment.centerRight);
        expect(tester.getSize(find.byWidget(card)), Size(width - 38, 142));
        final frame = tester.widget<Container>(
          find
              .descendant(
                of: find.byWidget(card),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(frame.clipBehavior, Clip.hardEdge);
        final border = frame.foregroundDecoration! as BoxDecoration;
        expect(border.borderRadius, BorderRadius.circular(22));
        expect(
          border.border,
          Border.all(color: const Color(0xff315071), width: .9),
        );
        expect(
          find.descendant(
            of: find.byWidget(card),
            matching: find.byType(CustomPaint),
          ),
          findsNothing,
        );
        expect(find.text('Dünya'), findsOneWidget);
        expect(find.text('Gezegende iz bırakmaya hazır ol!'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Dünya')).style!.fontSize, 23);
        expect(tester.takeException(), isNull);
        const captureDirectory = String.fromEnvironment(
          'WORLD_CARD_CAPTURE_DIR',
        );
        if (captureDirectory.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('world_card_capture')),
            );
            final capture = await boundary.toImage(pixelRatio: 2.8125);
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$captureDirectory/world-card-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            capture.dispose();
          });
        }
      },
    );
  }

  testWidgets('World card still opens existing World selection screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DriveItApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byKey(const Key('home_world_card')));
    await tester.tap(find.byKey(const Key('home_world_card')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WorldModeSelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
