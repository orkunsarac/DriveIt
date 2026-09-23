import 'package:driveit_project/features/onboarding/screens/legal_safety_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legal requirements gate the page 5 transition', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegalSafetyOnboardingPage(onContinue: () => continued = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yasal ve Güvenlik'), findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('checkbox_KVKK Aydınlatma Metni')),
          )
          .onChanged,
      isNull,
    );

    for (final title in <String>[
      'KVKK Aydınlatma Metni',
      'Gizlilik Politikası',
      'Kullanım Koşulları',
    ]) {
      await tester.tap(find.byKey(ValueKey('open_$title')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('checkbox_$title')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('open_security_warning')));
    await tester.pumpAndSettle();
    expect(find.text('Sürüş Güvenliği'), findsWidgets);
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kabul Et ve Devam Et'));
    await tester.pump();
    expect(continued, isTrue);
  });
}
