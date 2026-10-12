/// One gate for Auth, screens, GPS routing and import. No dart-define can
/// enable a partially wired production migration in this phase.
class LocalOwnershipGate {
  const LocalOwnershipGate.disabled() : enabled = false;

  /// Explicit synthetic harness only. Android release test builds also set an
  /// isolated package suffix in Gradle when this define is present.
  factory LocalOwnershipGate.synthetic() {
    if (!syntheticRuntimeAvailable) {
      throw StateError('Synthetic ownership requires an isolated test build');
    }
    return const LocalOwnershipGate._(true);
  }
  const LocalOwnershipGate._(this.enabled);
  final bool enabled;
  static const production = LocalOwnershipGate.disabled();
  static const debugBuild =
      !bool.fromEnvironment('dart.vm.product') &&
      !bool.fromEnvironment('dart.vm.profile');
  static const syntheticRuntimeAvailable =
      debugBuild || bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST');
}
