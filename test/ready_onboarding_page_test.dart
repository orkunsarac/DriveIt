import 'package:driveit_project/features/onboarding/screens/ready_onboarding_page.dart';
import 'package:driveit_project/features/onboarding/widgets/onboarding_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpReady(
    WidgetTester tester, {
    required bool profileReady,
    required Future<void> Function() completionWriter,
    VoidCallback? onEnterApp,
  }) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadyOnboardingPage(
            profileReadyLoader: () async => profileReady,
            completionWriter: completionWriter,
            onEnterApp: onEnterApp,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets(
    'created profile is shown and enter completes before navigation',
    (tester) async {
      final events = <String>[];
      await pumpReady(
        tester,
        profileReady: true,
        completionWriter: () async => events.add('completed'),
        onEnterApp: () => events.add('home'),
      );

      expect(find.text('Profil hazır'), findsOneWidget);
      expect(find.text('6 / 6'), findsOneWidget);
      await tester.tap(find.text("DriveIt'a Gir"));
      await tester.pumpAndSettle();
      expect(events, <String>['completed', 'home']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('skipped profile is honest and final page has one CTA', (
    tester,
  ) async {
    final events = <String>[];
    await pumpReady(
      tester,
      profileReady: false,
      completionWriter: () async => events.add('completed'),
      onEnterApp: () => events.add('home'),
    );

    expect(find.text('Profilini daha sonra tamamlayabilirsin'), findsOneWidget);
    expect(find.text('İlk Sürüşümü Başlat'), findsNothing);
    expect(find.byType(OnboardingPrimaryButton), findsOneWidget);
    await tester.tap(find.text("DriveIt'a Gir"));
    await tester.pumpAndSettle();
    expect(events, <String>['completed', 'home']);
    expect(tester.takeException(), isNull);
  });
}
