/// One gate for Auth, screens, GPS routing and import. No dart-define can
/// enable a partially wired production migration in this phase.
class LocalOwnershipGate {
  const LocalOwnershipGate.disabled() : enabled = false;

  /// Explicit synthetic harness only. Keep this core dependency Flutter-free
  /// so standalone journal/Hive crash-recovery tools can use the OFF path.
  factory LocalOwnershipGate.synthetic() {
    if (!debugBuild) {
      throw StateError('Synthetic ownership requires debug mode');
    }
    return const LocalOwnershipGate._(true);
  }
  const LocalOwnershipGate._(this.enabled);
  final bool enabled;
  static const production = LocalOwnershipGate.disabled();
  static const debugBuild =
      !bool.fromEnvironment('dart.vm.product') &&
      !bool.fromEnvironment('dart.vm.profile');
}
