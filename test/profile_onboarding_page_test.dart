import 'package:driveit_project/features/onboarding/screens/profile_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile input validation accepts Unicode names and strict usernames',
    () {
      expect(ProfileInputRules.validateDisplayName('  Çağrı Şahin  '), isNull);
      expect(ProfileInputRules.validateDisplayName('A'), isNotNull);
      expect(ProfileInputRules.validateUsername('drive.it_26'), isNull);
      expect(ProfileInputRules.validateUsername('Drive It'), isNotNull);
      expect(ProfileInputRules.validateUsername('şoför'), isNotNull);
      expect(ProfileInputRules.normalizeUsername('  Drive.IT  '), 'drive.it');
    },
  );

  testWidgets('valid profile is normalized, saved once and continues', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var saves = 0;
    String? savedName;
    String? savedUsername;
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: ProfileOnboardingPage(
            onContinue: () => continued = true,
            saveProfile: (name, username) async {
              saves++;
              savedName = name;
              savedUsername = username;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile_name_input')),
      '  Çağrı Şahin  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile_username_input')),
      'Drive.IT_26',
    );
    await tester.pump();
    expect(find.text('drive.it_26'), findsOneWidget);

    await tester.ensureVisible(find.text('Profilimi Oluştur'));
    await tester.tap(find.text('Profilimi Oluştur'));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(savedName, 'Çağrı Şahin');
    expect(savedUsername, 'drive.it_26');
    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid username stays on page and skip preserves profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    var saves = 0;
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: ProfileOnboardingPage(
            onContinue: () => continued = true,
            saveProfile: (_, _) async => saves++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile_name_input')),
      'Orkun',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile_username_input')),
      'geçersiz ad',
    );
    await tester.pump();
    expect(
      find.text('Yalnızca a-z, 0-9, _ ve . kullanabilirsin.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('skip_profile')));
    await tester.tap(find.byKey(const ValueKey('skip_profile')));
    await tester.pump();
    expect(saves, 0);
    expect(continued, isTrue);
  });

  testWidgets('only form responds to keyboard and resets when it closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: ProfileOnboardingPage(
            onContinue: () {},
            saveProfile: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logo = find.byType(Image).first;
    final title = find.text('Seni Tanıyalım');
    final nameInput = find.byKey(const ValueKey('profile_name_input'));
    final usernameInput = find.byKey(const ValueKey('profile_username_input'));
    final closedLogoTop = tester.getTopLeft(logo).dy;
    final closedTitleTop = tester.getTopLeft(title).dy;
    final closedNameTop = tester.getTopLeft(nameInput).dy;
    final nameElement = tester.element(nameInput);
    final usernameElement = tester.element(usernameInput);

    await tester.tap(nameInput);
    await tester.pump();
    expect(tester.widget<TextField>(nameInput).focusNode!.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 5));

    expect(tester.element(nameInput), same(nameElement));
    expect(tester.element(usernameInput), same(usernameElement));
    expect(tester.widget<TextField>(nameInput).focusNode!.hasFocus, isTrue);
    expect(tester.getTopLeft(logo).dy, closeTo(closedLogoTop, .1));
    expect(tester.getTopLeft(title).dy, closeTo(closedTitleTop, .1));

    await tester.enterText(nameInput, 'Orkun');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(usernameInput).focusNode!.hasFocus, isTrue);
    await tester.enterText(usernameInput, 'drive.it');
    await tester.pump();
    expect(tester.widget<TextField>(usernameInput).focusNode!.hasFocus, isTrue);
    expect(tester.getBottomRight(usernameInput).dy, lessThanOrEqualTo(600));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.element(nameInput), same(nameElement));
    expect(tester.element(usernameInput), same(usernameElement));
    expect(tester.widget<TextField>(usernameInput).focusNode!.hasFocus, isTrue);
    expect(tester.getTopLeft(logo).dy, closeTo(closedLogoTop, .1));
    expect(tester.getTopLeft(title).dy, closeTo(closedTitleTop, .1));
    expect(tester.getTopLeft(nameInput).dy, closeTo(closedNameTop, 1));
    expect(tester.takeException(), isNull);
  });
}
