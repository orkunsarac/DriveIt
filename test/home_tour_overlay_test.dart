import 'package:driveit_project/features/onboarding/widgets/home_tour_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home tour advances on taps and blocks real targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final keys = List<GlobalKey>.generate(4, (_) => GlobalKey());
    var targetTaps = 0;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              for (var index = 0; index < keys.length; index++)
                Positioned(
                  left: 24.0 + index * 70,
                  top: 120.0 + index * 100,
                  width: 80,
                  height: 60,
                  child: GestureDetector(
                    key: keys[index],
                    onTap: () => targetTaps++,
                    child: ColoredBox(color: Colors.blue.shade900),
                  ),
                ),
              HomeTourOverlay(
                steps: [
                  HomeTourStep(
                    targetKey: keys[0],
                    title: 'Sürüşe Başla',
                    description: 'Bir',
                    radius: 20,
                  ),
                  HomeTourStep(
                    targetKey: keys[1],
                    title: 'Sürüşlerim',
                    description: 'İki',
                    radius: 20,
                  ),
                  HomeTourStep(
                    targetKey: keys[2],
                    title: 'Benim Dünyam',
                    description: 'Üç',
                    radius: 20,
                  ),
                  HomeTourStep(
                    targetKey: keys[3],
                    title: 'Kariyerim',
                    description: 'Dört',
                    radius: 20,
                  ),
                ],
                onComplete: () async => completed = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sürüşe Başla'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    for (final expected in <String>[
      'Sürüşlerim',
      'Benim Dünyam',
      'Kariyerim',
    ]) {
      await tester.tapAt(const Offset(210, 760));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    }
    expect(find.text('4 / 4'), findsOneWidget);
    expect(completed, isFalse);
    await tester.tapAt(const Offset(210, 760));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(targetTaps, 0);
    expect(tester.takeException(), isNull);
  });
}
