/// One gate for Auth, screens and GPS routing. Production owner runtime is an
/// explicit local artifact opt-in; the default shipped configuration remains
/// disabled unless the dedicated define and native package marker agree.
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

  /// Opt-in for the locally installed owner-runtime build. The default public
  /// release remains on the legacy path unless this explicit build define is
  /// supplied for the user's device build.
  static const production = LocalOwnershipGate._(
    bool.fromEnvironment('DRIVEIT_LOCAL_OWNER_ACTIVATION'),
  );
  static const localProductionActivation = bool.fromEnvironment(
    'DRIVEIT_LOCAL_OWNER_ACTIVATION',
  );
  static const debugBuild =
      !bool.fromEnvironment('dart.vm.product') &&
      !bool.fromEnvironment('dart.vm.profile');
  static const syntheticRuntimeAvailable =
      debugBuild || bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST');
}
