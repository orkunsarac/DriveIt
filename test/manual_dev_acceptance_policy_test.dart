import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/features/dev_acceptance/manual_dev_acceptance_policy.dart';

void main() {
  const key = 'sb_publishable_dev_test_key_1234567890';

  test('manual screen build fence does not need an embedded key sentinel', () {
    expect(
      ManualDevAcceptancePolicy.buildPermits(
        manualBuild: true,
        isolatedBuild: true,
        installedApplicationId: ManualDevAcceptancePolicy.applicationId,
        url: ManualDevAcceptancePolicy.projectUrl,
      ),
      isTrue,
    );
    expect(
      ManualDevAcceptancePolicy.buildPermits(
        manualBuild: true,
        isolatedBuild: false,
        installedApplicationId: ManualDevAcceptancePolicy.applicationId,
        url: ManualDevAcceptancePolicy.projectUrl,
      ),
      isFalse,
    );
  });

  test(
    'only explicit isolated build, exact DEV URL and publishable key pass',
    () {
      expect(
        ManualDevAcceptancePolicy.permits(
          manualBuild: true,
          isolatedBuild: true,
          installedApplicationId: ManualDevAcceptancePolicy.applicationId,
          url: ManualDevAcceptancePolicy.projectUrl,
          publishableKey: key,
        ),
        isTrue,
      );
    },
  );

  test('normal, Play, and non-publishable credentials are refused', () {
    const rejectedSecretPrefix = 'sb_secret_';
    for (final input in [
      (
        manualBuild: false,
        isolatedBuild: true,
        app: ManualDevAcceptancePolicy.applicationId,
        url: ManualDevAcceptancePolicy.projectUrl,
        key: key,
      ),
      (
        manualBuild: true,
        isolatedBuild: false,
        app: ManualDevAcceptancePolicy.applicationId,
        url: ManualDevAcceptancePolicy.projectUrl,
        key: key,
      ),
      (
        manualBuild: true,
        isolatedBuild: true,
        app: 'com.osaracx.driveit',
        url: ManualDevAcceptancePolicy.projectUrl,
        key: key,
      ),
      (
        manualBuild: true,
        isolatedBuild: true,
        app: ManualDevAcceptancePolicy.applicationId,
        url: 'https://arwnbogcswisfesayosy.supabase.co',
        key: key,
      ),
      (
        manualBuild: true,
        isolatedBuild: true,
        app: ManualDevAcceptancePolicy.applicationId,
        url: ManualDevAcceptancePolicy.projectUrl,
        key: '${rejectedSecretPrefix}not-a-real-key',
      ),
    ]) {
      expect(
        ManualDevAcceptancePolicy.permits(
          manualBuild: input.manualBuild,
          isolatedBuild: input.isolatedBuild,
          installedApplicationId: input.app,
          url: input.url,
          publishableKey: input.key,
        ),
        isFalse,
      );
    }
  });
}
