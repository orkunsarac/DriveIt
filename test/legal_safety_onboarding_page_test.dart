import 'package:driveit_project/features/onboarding/models/legal_document_catalog.dart';
import 'package:driveit_project/features/onboarding/screens/legal_safety_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LegalDocumentContent document(String id, String title) => LegalDocumentContent(
  id: id,
  title: title,
  status: LegalDocumentStatus.approved,
  body: 'Approved fixture content for widget testing only.',
  version: 'test-1',
  approvalReference: 'SYNTHETIC-TEST-FIXTURE',
  approvedAt: DateTime.utc(2026, 1, 1),
);

Future<void> pumpPage(
  WidgetTester tester, {
  required ValueChanged<bool> onContinued,
  LegalDocumentCatalogLoader? catalogLoader,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LegalSafetyOnboardingPage(
          onContinue: () => onContinued(true),
          catalogLoader: catalogLoader,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pending legal drafts cannot be accepted or advance onboarding', (
    tester,
  ) async {
    var continued = false;
    await pumpPage(tester, onContinued: (_) => continued = true);

    expect(find.text('Yasal ve Güvenlik'), findsOneWidget);
    expect(find.textContaining('hukuk incelemesinde'), findsOneWidget);
    expect(
      find.text('Hukuki inceleme bekleniyor — kabul alınmıyor.'),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey('checkbox_KVKK Aydınlatma Metni')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('open_KVKK Aydınlatma Metni')));
    await tester.pumpAndSettle();
    expect(find.textContaining('HUKUKİ İNCELEME BEKLİYOR'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open_security_warning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Kabul Et ve Devam Et'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(continued, isFalse);
  });

  testWidgets('approved versioned documents can pass the UI gate', (
    tester,
  ) async {
    final catalog = LegalDocumentCatalog([
      document('kvkk', 'KVKK Aydınlatma Metni'),
      document('privacy', 'Gizlilik Politikası'),
      document('terms', 'Kullanım Koşulları'),
      document('consent', 'Açık Rıza Metni'),
    ]);
    var continued = false;
    await pumpPage(
      tester,
      onContinued: (_) => continued = true,
      catalogLoader: () async => catalog,
    );

    for (final title in <String>[
      'KVKK Aydınlatma Metni',
      'Gizlilik Politikası',
      'Kullanım Koşulları',
    ]) {
      await tester.tap(find.byKey(ValueKey('open_$title')));
      await tester.pumpAndSettle();
      expect(find.text('Sürüm test-1'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('checkbox_$title')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('open_security_warning')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabul Et ve Devam Et'));
    await tester.pump();

    expect(continued, isTrue);
  });
}
