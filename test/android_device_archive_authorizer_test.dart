import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:driveit_project/services/android_device_archive_authorizer.dart';

class _Authentication extends LocalAuthentication {
  bool supported = true;
  bool accepted = true;
  Object? error;
  Completer<bool>? pending;
  int prompts = 0;
  bool? onlyBiometric, persistent;
  @override
  Future<bool> isDeviceSupported() async => supported;
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    onlyBiometric = biometricOnly;
    persistent = persistAcrossBackgrounding;
    if (error != null) throw error!;
    return pending == null ? accepted : pending!.future;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('driveit/device_archive_security');
  late _Authentication auth;
  bool secure = true;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    auth = _Authentication();
    secure = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'isDeviceArchiveRuntimeAllowed') return true;
      if (call.method == 'hasSecureDeviceLock') return secure;
      fail('Unexpected archive security method: ${call.method}');
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  AndroidDeviceArchiveAuthorizer provider() =>
      AndroidDeviceArchiveAuthorizer(authentication: auth);
  test(
    'system challenge succeeds with biometric OR credential, no background persistence',
    () async {
      expect(await provider().verifyDeviceAccess(), true);
      expect(auth.onlyBiometric, false);
      expect(auth.persistent, false);
    },
  );
  test('no secure screen lock denies before prompting', () async {
    secure = false;
    expect(await provider().verifyDeviceAccess(), false);
    expect(auth.prompts, 0);
  });
  test('unsupported device denies before prompting', () async {
    auth.supported = false;
    expect(await provider().verifyDeviceAccess(), false);
    expect(auth.prompts, 0);
  });
  test('user cancellation denies', () async {
    auth.error = LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
    expect(await provider().verifyDeviceAccess(), false);
  });
  test('failed challenge denies', () async {
    auth.accepted = false;
    expect(await provider().verifyDeviceAccess(), false);
  });
  test('native authentication error denies', () async {
    auth.error = PlatformException(code: 'synthetic_failure');
    expect(await provider().verifyDeviceAccess(), false);
  });
  test('missing security bridge cannot fallback to account login', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    expect(await provider().verifyDeviceAccess(), false);
    expect(auth.prompts, 0);
  });
  test('lock configuration changing during challenge denies', () async {
    auth.pending = Completer<bool>();
    final result = provider().verifyDeviceAccess();
    await Future<void>.value();
    await Future<void>.value();
    secure = false;
    auth.pending!.complete(true);
    expect(await result, false);
  });
  test('parallel taps cannot create parallel credential prompts', () async {
    auth.pending = Completer<bool>();
    final device = provider();
    final first = device.verifyDeviceAccess();
    expect(await device.verifyDeviceAccess(), false);
    auth.pending!.complete(true);
    expect(await first, true);
    expect(auth.prompts, 1);
  });
}
