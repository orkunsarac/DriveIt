import 'dart:io';

import 'package:driveit_project/config/driveit_auth_callback.dart';
import 'package:driveit_project/features/account/screens/driveit_password_recovery_screen.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecoveryGateway implements DriveItAccountGateway {
  int completed = 0;

  @override
  bool get isAvailable => true;
  @override
  bool get hasSession => true;
  @override
  String? get currentDisplayName => null;
  @override
  Stream<dynamic> get authStateChanges => const Stream.empty();
  @override
  Future<bool> isUsernameAvailable(String username) async => true;
  @override
  Future<bool> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async => false;
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> resetPasswordForEmail(String email) async {}
  @override
  Future<void> completePasswordRecovery(String newPassword) async {
    completed++;
  }

  @override
  Future<DriveItAccountProfile?> fetchCurrentProfile() async => null;
  @override
  Future<DriveItAccountProfile> updateDisplayName(String displayName) =>
      throw UnimplementedError();
  @override
  Future<DriveItAccountProfile> updateUsername(String username) =>
      throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

void main() {
  group('DriveItAuthCallback', () {
    test('accepts only the exact callback with Auth response data', () {
      DriveItAuthCallback.configureForApplicationId('com.osaracx.driveit');
      expect(
        DriveItAuthCallback.accepts(
          Uri.parse('com.osaracx.driveit://auth/callback?code=one-time-code'),
        ),
        isTrue,
      );
      expect(
        DriveItAuthCallback.accepts(
          Uri.parse('com.osaracx.driveit://auth/callback#error=access_denied'),
        ),
        isTrue,
      );
    });

    test('opens recovery only for a recovery event backed by a session', () {
      expect(
        DriveItAuthCallback.shouldOpenPasswordRecovery(
          event: AuthChangeEvent.passwordRecovery,
          hasSession: true,
        ),
        isTrue,
      );
      expect(
        DriveItAuthCallback.shouldOpenPasswordRecovery(
          event: AuthChangeEvent.passwordRecovery,
          hasSession: false,
        ),
        isFalse,
      );
      expect(
        DriveItAuthCallback.shouldOpenPasswordRecovery(
          event: AuthChangeEvent.signedIn,
          hasSession: true,
        ),
        isFalse,
      );
    });

    test('callback scheme follows the selected Android application id', () {
      DriveItAuthCallback.configureForApplicationId(
        'com.example.driveit_project.isolated_test',
      );
      expect(
        DriveItAuthCallback.uri,
        'com.example.driveit-project.isolated-test://auth/callback',
      );
      expect(
        DriveItAuthCallback.accepts(
          Uri.parse(
            'com.example.driveit-project.isolated-test://auth/callback?code=x',
          ),
        ),
        isTrue,
      );
      expect(
        DriveItAuthCallback.accepts(
          Uri.parse('com.osaracx.driveit://auth/callback?code=x'),
        ),
        isFalse,
      );
      expect(
        () => DriveItAuthCallback.configureForApplicationId('com.attacker.app'),
        throwsStateError,
      );
      DriveItAuthCallback.configureForApplicationId('com.osaracx.driveit');
    });

    test(
      'rejects wrong scheme, host, path, port and non-Auth/open redirect URIs',
      () {
        DriveItAuthCallback.configureForApplicationId('com.osaracx.driveit');
        for (final value in [
          'https://auth/callback?code=x',
          'com.osaracx.driveit://evil/callback?code=x',
          'com.osaracx.driveit://auth/other?code=x',
          'com.osaracx.driveit://auth:99/callback?code=x',
          'com.osaracx.driveit://auth/callback?next=https://evil.example',
          'com.osaracx.driveit://auth/callback',
        ]) {
          expect(
            DriveItAuthCallback.accepts(Uri.parse(value)),
            isFalse,
            reason: value,
          );
        }
      },
    );

    test('Android manifest registers only the exact custom callback tuple', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains(r'android:scheme="${driveItAuthScheme}"'));
      expect(manifest, contains('android:host="auth"'));
      expect(manifest, contains('android:path="/callback"'));
      expect(manifest, isNot(contains('android:autoVerify="true"')));
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(
        gradle,
        contains(
          "manifestPlaceholders[\"driveItAuthScheme\"] = configuredApplicationId.replace('_', '-')",
        ),
      );
    });
  });

  testWidgets('recovery form validates and submits only the new password', (
    tester,
  ) async {
    final gateway = _RecoveryGateway();
    await tester.pumpWidget(
      MaterialApp(home: DriveItPasswordRecoveryScreen(accountGateway: gateway)),
    );
    await tester.enterText(
      find.byKey(const Key('recovery-new-password')),
      'NewDrive!2026',
    );
    await tester.enterText(
      find.byKey(const Key('recovery-confirm-password')),
      'NewDrive!2026',
    );
    await tester.tap(find.byKey(const Key('recovery-save')));
    await tester.pumpAndSettle();
    expect(gateway.completed, 1);
    expect(find.text('Parolan güncellendi.'), findsOneWidget);
  });

  testWidgets('recovery form refuses a changed session before submission', (
    tester,
  ) async {
    final gateway = _RecoveryGateway();
    var current = true;
    await tester.pumpWidget(
      MaterialApp(
        home: DriveItPasswordRecoveryScreen(
          accountGateway: gateway,
          isRecoveryContextCurrent: () => current,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('recovery-new-password')),
      'NewDrive!2026',
    );
    await tester.enterText(
      find.byKey(const Key('recovery-confirm-password')),
      'NewDrive!2026',
    );
    current = false;
    await tester.tap(find.byKey(const Key('recovery-save')));
    await tester.pump();
    expect(gateway.completed, 0);
    expect(find.byKey(const Key('recovery-error')), findsOneWidget);
  });
}
