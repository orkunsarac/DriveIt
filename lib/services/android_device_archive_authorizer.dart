import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'device_drive_archive.dart';
import '../config/local_ownership_gate.dart';

/// Explicit controlled composition. Never discovers/open boxes or changes gate.
DeviceDriveArchiveAccess androidDeviceDriveArchiveAccess({
  required LocalOwnershipGate gate,
  required DeviceDriveArchiveSnapshot snapshot,
}) => DeviceDriveArchiveAccess(
  gate: gate,
  snapshot: snapshot,
  authorizer: AndroidDeviceArchiveAuthorizer(),
);

/// Android system credentials only. Device support alone does not prove that
/// a secure PIN/pattern/password is configured; Keyguard is checked separately.
class AndroidDeviceArchiveAuthorizer implements DeviceArchiveAuthorizer {
  AndroidDeviceArchiveAuthorizer({
    LocalAuthentication? authentication,
    MethodChannel? security,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _security =
           security ?? const MethodChannel('driveit/device_archive_security');
  final LocalAuthentication _authentication;
  final MethodChannel _security;
  bool _busy = false;

  @override
  Future<bool> verifyDeviceAccess() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _busy) {
      return false;
    }
    _busy = true;
    try {
      if (await _security.invokeMethod<bool>('hasSecureDeviceLock') != true ||
          !await _authentication.isDeviceSupported()) {
        return false;
      }
      final accepted = await _authentication.authenticate(
        localizedReason:
            'Cihazdaki eski sürüşleri görüntülemek için kimliğinizi doğrulayın.',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: false,
      );
      // A changed lock configuration during the challenge cannot grant access.
      return accepted &&
          await _security.invokeMethod<bool>('hasSecureDeviceLock') == true;
    } on LocalAuthException {
      return false; // Cancel, lockout, unavailable credentials: all deny access.
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } finally {
      _busy = false;
    }
  }
}
