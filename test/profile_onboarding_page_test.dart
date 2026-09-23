import 'package:driveit_project/features/account/screens/driveit_account_screen.dart';
import 'package:driveit_project/features/account/screens/driveit_account_settings_screen.dart';
import 'package:driveit_project/features/account/widgets/driveit_account_section.dart';
import 'package:driveit_project/features/onboarding/screens/profile_onboarding_page.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/profile_storage_service.dart';
import 'package:driveit_project/screens/profile_settings_screen.dart';
import 'package:driveit_project/features/my_world/services/my_world_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:async';

class _MemoryBox implements Box<dynamic> {
  final _storage = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _storage[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _storage[key] = value;

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _storage.addAll(entries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAccountGateway implements DriveItAccountGateway {
  final changes = StreamController<dynamic>.broadcast();
  bool signedIn = false;
  bool signupHasSession = false;
  bool profileUnavailable = false;
  int signOutCalls = 0;
  int passwordResetCalls = 0;
  int usernameAvailabilityCalls = 0;
  int usernameUpdateCalls = 0;
  int displayNameUpdateCalls = 0;
  int passwordChangeCalls = 0;
  bool usernameIsAvailable = true;
  bool passwordChangeFails = false;
  String _displayName = 'Bulut Adı';
  String _username = 'cloud_user';
  Map<String, String>? signupValues;

  @override
  bool get isAvailable => true;
  @override
  bool get hasSession => signedIn;
  @override
  String? get currentDisplayName => 'Bulut Adı';
  @override
  Stream<dynamic> get authStateChanges => changes.stream;

  @override
  Future<bool> isUsernameAvailable(String username) async {
    usernameAvailabilityCalls++;
    return usernameIsAvailable;
  }

  @override
  Future<bool> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    signupValues = {
      'display_name': displayName,
      'username': username,
      'email': email,
      'password': password,
    };
    signedIn = signupHasSession;
    return signupHasSession;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signedIn = true;
    changes.add(null);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
    changes.add(null);
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    passwordResetCalls++;
  }

  @override
  Future<DriveItAccountProfile?> fetchCurrentProfile() async =>
      signedIn && !profileUnavailable
      ? const DriveItAccountProfile(
          id: 'test-id',
          email: 'cloud@example.com',
          username: 'cloud_user',
          displayName: 'Bulut Adı',
          avatarUrl: null,
        ).copyWithForTest(displayName: _displayName, username: _username)
      : null;

  @override
  Future<DriveItAccountProfile> updateDisplayName(String displayName) async {
    displayNameUpdateCalls++;
    _displayName = displayName;
    return (await fetchCurrentProfile())!;
  }

  @override
  Future<DriveItAccountProfile> updateUsername(String username) async {
    usernameUpdateCalls++;
    _username = username;
    return (await fetchCurrentProfile())!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChangeCalls++;
    if (passwordChangeFails) {
      throw const AccountServiceException('Mevcut şifren yanlış.');
    }
  }
}

extension on DriveItAccountProfile {
  DriveItAccountProfile copyWithForTest({
    String? displayName,
    String? username,
  }) => DriveItAccountProfile(
    id: id,
    email: email,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'effective profile name prefers cloud and never masks fetch failure',
    () {
      const cloudProfile = DriveItAccountProfile(
        id: 'cloud-id',
        email: null,
        username: 'cloud_user',
        displayName: 'Orkun Saraç',
      );
      expect(
        DriveItEffectiveProfile.displayName(
          localName: 'Orkun Local',
          hasSession: false,
          cloudProfile: cloudProfile,
          cloudProfileLoaded: true,
          cloudProfileFailed: false,
        ),
        'Orkun Local',
      );
      expect(
        DriveItEffectiveProfile.displayName(
          localName: 'Orkun Local',
          hasSession: true,
          cloudProfile: cloudProfile,
          cloudProfileLoaded: true,
          cloudProfileFailed: false,
        ),
        'Orkun Saraç',
      );
      const usernameOnly = DriveItAccountProfile(
        id: 'cloud-id',
        email: null,
        username: 'cloud_user',
        displayName: ' ',
      );
      expect(
        DriveItEffectiveProfile.displayName(
          localName: 'Orkun Local',
          hasSession: true,
          cloudProfile: usernameOnly,
          cloudProfileLoaded: true,
          cloudProfileFailed: false,
        ),
        '@cloud_user',
      );
      expect(
        DriveItEffectiveProfile.displayName(
          localName: 'Orkun Local',
          hasSession: true,
          cloudProfile: null,
          cloudProfileLoaded: true,
          cloudProfileFailed: false,
        ),
        'DriveIt kullanıcısı',
      );
      expect(
        DriveItEffectiveProfile.displayName(
          localName: 'Orkun Local',
          hasSession: true,
          cloudProfile: null,
          cloudProfileLoaded: false,
          cloudProfileFailed: true,
        ),
        isNull,
      );
    },
  );

  testWidgets('cloud profile read failure never shows generic identity', (
    tester,
  ) async {
    final gateway = _TestAccountGateway()
      ..signedIn = true
      ..profileUnavailable = true;
    await tester.pumpWidget(
      MaterialApp(home: DriveItAccountSection(accountGateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hesap bilgileri henüz hazır değil.'), findsOneWidget);
    expect(find.text('DriveIt kullanıcısı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile settings locks cloud name but restores local on logout',
    (tester) async {
      final localProfile = ProfileStorageService(_MemoryBox());
      await localProfile.saveName('Orkun Local');
      final gateway = _TestAccountGateway()..signedIn = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsScreen(
            profileLoader: () async => localProfile,
            worldSettings: MemoryMyWorldSettingsStore(),
            accountGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bulut Adı'), findsWidgets);
      expect(find.text('DriveIt hesabındaki ad kullanılıyor.'), findsOneWidget);
      final nameButton = tester.widget<TextButton>(
        find.byKey(const Key('profile_display_name_button')),
      );
      expect(nameButton.onPressed, isNull);
      expect(localProfile.name, 'Orkun Local');

      await tester.runAsync(() => gateway.signOut());
      await tester.pumpAndSettle();
      expect(find.text('Orkun Local'), findsWidgets);
      expect(find.text('DriveIt hesabındaki ad kullanılıyor.'), findsNothing);
      final editableNameButton = tester.widget<TextButton>(
        find.byKey(const Key('profile_display_name_button')),
      );
      expect(editableNameButton.onPressed, isNotNull);
      expect(localProfile.name, 'Orkun Local');
    },
  );

  test('cloud account username and password validation', () {
    expect(AccountInputRules.validateDisplayName('Çağrı Şahin'), isNull);
    expect(AccountInputRules.validateUsername('Orkun_26'), isNull);
    expect(AccountInputRules.normalizeUsername(' OrKun_26 '), 'orkun_26');
    expect(AccountInputRules.validateUsername('ab'), isNotNull);
    expect(AccountInputRules.validateUsername('orkun.s'), isNotNull);
    expect(AccountInputRules.validateEmail('not-an-email'), isNotNull);
    expect(AccountInputRules.validateEmail('driveit@example.com'), isNull);
    expect(AccountInputRules.validatePassword('short'), isNotNull);
    expect(AccountInputRules.validatePassword('long-enough'), isNull);
    expect(
      AccountInputRules.validatePasswordConfirmation('long-enough', 'other'),
      isNotNull,
    );
    expect(
      AccountInputRules.validatePasswordConfirmation(
        'long-enough',
        'long-enough',
      ),
      isNull,
    );
  });

  test('username availability status covers RPC and validation states', () {
    expect(
      AccountUsernameAvailability.resolve(username: 'ab'),
      AccountUsernameStatus.invalid,
    );
    expect(
      AccountUsernameAvailability.resolve(username: 'orkun_26', checking: true),
      AccountUsernameStatus.checking,
    );
    expect(
      AccountUsernameAvailability.resolve(
        username: 'orkun_26',
        available: true,
      ),
      AccountUsernameStatus.available,
    );
    expect(
      AccountUsernameAvailability.resolve(
        username: 'orkun_26',
        available: false,
      ),
      AccountUsernameStatus.taken,
    );
    expect(
      AccountUsernameAvailability.resolve(
        username: 'orkun_26',
        checkFailed: true,
      ),
      AccountUsernameStatus.unavailable,
    );
  });

  testWidgets(
    'onboarding offers account, login and skip without local mutation',
    (tester) async {
      final box = _MemoryBox();
      final profile = ProfileStorageService(box);
      await profile.saveProfile(
        displayName: 'Yerel Profil',
        username: 'local_1',
      );
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileOnboardingPage(
              onContinue: () => continued = true,
              profileLoader: () async => profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hesap Oluştur'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Şimdilik Geç'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('skip_profile')));
      await tester.pump();

      expect(continued, isTrue);
      expect(profile.name, 'Yerel Profil');
      expect(profile.username, 'local_1');
    },
  );

  testWidgets('account entry remains controlled when Supabase is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DriveItAccountScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('Çevrimiçi hesap hizmeti şu anda kullanılamıyor.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'signup sends normalized cloud metadata and handles email confirmation',
    (tester) async {
      final gateway = _TestAccountGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: DriveItAccountScreen(
            initialMode: DriveItAccountMode.create,
            accountGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account_display_name')),
        'Çağrı',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account_username')),
        'DriveUser_1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account_email')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account_password')),
        'securepass',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account_password_repeat')),
        'securepass',
      );
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump();

      final submit = find.byKey(const ValueKey('account_submit_create'));
      await tester.ensureVisible(submit);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(gateway.signupValues?['username'], 'driveuser_1');
      expect(gateway.signupValues?['display_name'], 'Çağrı');
      expect(gateway.signupValues?['password'], 'securepass');
      expect(
        find.textContaining('E-posta adresine doğrulama bağlantısı gönderdik.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'profile account logout leaves the local Hive profile untouched',
    (tester) async {
      final box = _MemoryBox();
      final localProfile = ProfileStorageService(box);
      await localProfile.saveProfile(
        displayName: 'Yerel Profil',
        username: 'local_1',
      );
      final gateway = _TestAccountGateway()..signedIn = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriveItAccountSection(accountGateway: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bulut Adı'), findsOneWidget);
      expect(find.text('@cloud_user'), findsOneWidget);

      await tester.tap(find.text('Hesaptan Çıkış Yap'));
      await tester.pumpAndSettle();

      expect(find.text('Çıkış yapılsın mı?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('driveit_logout_cancel')));
      await tester.pumpAndSettle();
      expect(gateway.signOutCalls, 0);
      expect(gateway.hasSession, isTrue);

      await tester.tap(find.text('Hesaptan Çıkış Yap'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('driveit_logout_confirm')));
      await tester.pumpAndSettle();

      expect(gateway.signOutCalls, 1);
      expect(gateway.hasSession, isFalse);
      expect(localProfile.name, 'Yerel Profil');
      expect(localProfile.username, 'local_1');
      expect(find.text('Hesap Oluştur'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
      await gateway.changes.close();
    },
  );

  testWidgets(
    'signed-in account exposes settings and username updates safely',
    (tester) async {
      final localProfile = ProfileStorageService(_MemoryBox());
      await localProfile.saveProfile(
        displayName: 'Yerel Ad',
        username: 'local_1',
      );
      final gateway = _TestAccountGateway()..signedIn = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriveItAccountSection(accountGateway: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('driveit_account_settings')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('driveit_account_settings')));
      await tester.pumpAndSettle();
      expect(find.text('DriveIt Hesap Ayarları'), findsOneWidget);
      expect(gateway.usernameAvailabilityCalls, 0);

      await tester.enterText(
        find.byKey(const ValueKey('account_settings_display_name')),
        'Bulut Adı Yeni',
      );
      await tester.tap(
        find.byKey(const ValueKey('account_settings_save_profile')),
      );
      await tester.pumpAndSettle();
      expect(gateway.displayNameUpdateCalls, 1);
      expect(gateway.usernameAvailabilityCalls, 0);
      expect(localProfile.name, 'Yerel Ad');

      await tester.enterText(
        find.byKey(const ValueKey('account_settings_username')),
        'New_User',
      );
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();
      expect(gateway.usernameAvailabilityCalls, 1);
      await tester.enterText(
        find.byKey(const ValueKey('account_settings_display_name')),
        'Bulut Adı Yeni',
      );
      await tester.tap(
        find.byKey(const ValueKey('account_settings_save_profile')),
      );
      await tester.pumpAndSettle();
      expect(gateway.usernameUpdateCalls, 1);
      expect(gateway.usernameAvailabilityCalls, 1);
      expect(localProfile.username, 'local_1');
      await gateway.changes.close();
    },
  );

  testWidgets('account settings reports taken username and verifies password', (
    tester,
  ) async {
    final gateway = _TestAccountGateway()
      ..signedIn = true
      ..usernameIsAvailable = false
      ..passwordChangeFails = true;
    await tester.pumpWidget(
      MaterialApp(home: DriveItAccountSettingsScreen(accountGateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('account_settings_username')),
      'taken_user',
    );
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(gateway.usernameAvailabilityCalls, 1);
    expect(find.text('Bu kullanıcı adı kullanımda.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('account_settings_save_profile')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('account_settings_current_password')),
      'wrong-old',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account_settings_new_password')),
      'new-password-1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account_settings_new_password_repeat')),
      'new-password-1',
    );
    final changePassword = find.byKey(
      const ValueKey('account_settings_change_password'),
    );
    await tester.ensureVisible(changePassword);
    await tester.tap(changePassword);
    await tester.pumpAndSettle();
    expect(gateway.passwordChangeCalls, 1);
    expect(find.text('Mevcut şifren yanlış.'), findsOneWidget);
    gateway.passwordChangeFails = false;
    await tester.tap(changePassword);
    await tester.pumpAndSettle();
    expect(gateway.passwordChangeCalls, 2);
    expect(find.text('Şifren güncellendi.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('account_settings_current_password')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await gateway.changes.close();
  });

  testWidgets('login and password reset use the shared account flow', (
    tester,
  ) async {
    final gateway = _TestAccountGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open_login_flow'),
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => DriveItAccountScreen(
                    initialMode: DriveItAccountMode.login,
                    accountGateway: gateway,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open_login_flow')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account_email')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account_password')),
      'securepass',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('account_email')))
          .controller!
          .text,
      'user@example.com',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('account_password')))
          .controller!
          .text,
      'securepass',
    );
    expect(AccountInputRules.validateEmail('user@example.com'), isNull);
    expect(AccountInputRules.validatePassword('securepass'), isNull);
    final loginSubmit = find.byKey(const ValueKey('account_submit_login'));
    await tester.ensureVisible(loginSubmit);
    expect(tester.widget<FilledButton>(loginSubmit).onPressed, isNotNull);
    await tester.tap(loginSubmit);
    await tester.pumpAndSettle();
    expect(gateway.hasSession, isTrue);
    expect(find.byKey(const ValueKey('open_login_flow')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open_login_flow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şifremi Unuttum'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account_email')),
      'user@example.com',
    );
    await tester.pump();
    final resetSubmit = find.byKey(const ValueKey('account_submit_reset'));
    await tester.ensureVisible(resetSubmit);
    expect(tester.widget<FilledButton>(resetSubmit).onPressed, isNotNull);
    await tester.tap(resetSubmit);
    await tester.pumpAndSettle();
    expect(gateway.passwordResetCalls, 1);
    expect(find.textContaining('Şifre sıfırlama bağlantısı'), findsOneWidget);
    await gateway.changes.close();
  });
}
