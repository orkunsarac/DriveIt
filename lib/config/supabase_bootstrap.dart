import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time client configuration. Only the public publishable key belongs
/// in a client app; secret/service-role keys must never be supplied here.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static List<String> get missingValues => [
    if (url.isEmpty) 'SUPABASE_URL',
    if (publishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
}

/// Initializes Supabase only when both public client values are supplied.
/// Failure is non-fatal so all local DriveIt features remain available.
abstract final class SupabaseBootstrap {
  /// Explicit kill switch for isolated Android integration-test builds. Even
  /// if somebody accidentally supplies real dart-defines, tests stay offline.
  static const isIsolatedAndroidTest =
      bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST');

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<bool> initializeIfConfigured() async {
    if (_initialized) return true;
    if (isIsolatedAndroidTest) {
      if (kDebugMode) {
        debugPrint('[SUPABASE] Disabled in isolated Android integration tests.');
      }
      return false;
    }
    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[SUPABASE] Not configured; missing ${SupabaseConfig.missingValues.join(', ')}. '
          'Continuing with local DriveIt features.',
        );
      }
      return false;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _initialized = true;
      if (kDebugMode) debugPrint('[SUPABASE] Client initialized.');
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[SUPABASE] Initialization failed (${error.runtimeType}); '
          'continuing with local DriveIt features.',
        );
        debugPrintStack(
          label: '[SUPABASE] Initialization stack',
          stackTrace: stackTrace,
        );
      }
      return false;
    }
  }
}
