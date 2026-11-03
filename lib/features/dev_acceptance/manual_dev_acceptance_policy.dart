import '../../config/supabase_public_key_policy.dart';

/// Build/runtime fence for the interactive DEV acceptance harness.
abstract final class ManualDevAcceptancePolicy {
  static const applicationId = 'com.example.driveit_project.isolated_test';
  static const projectUrl = 'https://viqngnjfgknpxtoapzcg.supabase.co';

  static bool buildPermits({
    required bool manualBuild,
    required bool isolatedBuild,
    required String installedApplicationId,
    required String url,
  }) =>
      manualBuild &&
      isolatedBuild &&
      installedApplicationId == applicationId &&
      url == projectUrl;

  static bool permits({
    required bool manualBuild,
    required bool isolatedBuild,
    required String installedApplicationId,
    required String url,
    required String publishableKey,
  }) =>
      buildPermits(
        manualBuild: manualBuild,
        isolatedBuild: isolatedBuild,
        installedApplicationId: installedApplicationId,
        url: url,
      ) &&
      publishableKey.startsWith('sb_publishable_') &&
      SupabasePublicKeyPolicy.permits(publishableKey);
}
