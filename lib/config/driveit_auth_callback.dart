import 'package:supabase_flutter/supabase_flutter.dart';

/// Exact DriveIt Android redirect used by Supabase Auth email callbacks.
/// Keep this synchronized with the Android intent filter and hosted allowlist.
abstract final class DriveItAuthCallback {
  static const _supportedApplicationIds = {
    'com.example.driveit_project',
    'com.example.driveit_project.isolated_test',
    'com.osaracx.driveit',
  };
  static String _scheme = 'driveit';

  static String get uri => '$_scheme://auth/callback';

  static void configureForApplicationId(String applicationId) {
    if (!_supportedApplicationIds.contains(applicationId)) {
      throw StateError('Unsupported DriveIt Auth callback application id');
    }
    // Android package IDs may contain underscores; URI schemes may not.
    _scheme = applicationId.replaceAll('_', '-');
  }

  static bool accepts(Uri candidate) =>
      candidate.scheme == _scheme &&
      candidate.host == 'auth' &&
      candidate.path == '/callback' &&
      candidate.userInfo.isEmpty &&
      candidate.port == 0 &&
      _hasAuthParameter(candidate);

  static bool shouldOpenPasswordRecovery({
    required AuthChangeEvent event,
    required bool hasSession,
  }) => event == AuthChangeEvent.passwordRecovery && hasSession;

  static bool _hasAuthParameter(Uri candidate) {
    const keys = {
      'access_token',
      'code',
      'error',
      'error_code',
      'error_description',
    };
    try {
      final fragment = Uri.splitQueryString(candidate.fragment);
      return keys.any(
        (key) =>
            candidate.queryParameters.containsKey(key) ||
            fragment.containsKey(key),
      );
    } on FormatException {
      return false;
    }
  }
}
