import 'package:driveit_project/features/onboarding/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding CTAs advance through completed pages', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Hoş Geldin'), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('DriveIt Neler Sunar?'), findsNothing);

    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    expect(find.text('DriveIt Neler Sunar?'), findsOneWidget);
    expect(find.text('2 / 6'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 6'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);

    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.text('Gerekli İzinler'), findsOneWidget);
    expect(find.text('3 / 6'), findsOneWidget);
  });
}
