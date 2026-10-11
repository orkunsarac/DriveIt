import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';

void main() {
  test(
    'isolated Android integration build cannot initialize Supabase',
    () async {
      expect(SupabaseBootstrap.isIsolatedAndroidTest, isTrue);
      expect(SupabaseConfig.isConfigured, isTrue);
      expect(LocalOwnershipGate.production.enabled, isFalse);
      expect(await SupabaseBootstrap.initializeIfConfigured(), isFalse);
      expect(SupabaseBootstrap.isInitialized, isFalse);
    },
    skip: !SupabaseBootstrap.isIsolatedAndroidTest
        ? 'Requires explicit isolated Android test compile-time define.'
        : false,
  );
}
