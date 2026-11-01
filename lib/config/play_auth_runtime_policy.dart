/// Play Auth remains unavailable until a future reviewed code change.
abstract final class PlayAuthRuntimePolicy {
  static bool permitsBootstrap({
    required String applicationId,
    required bool playAuthEnabled,
  }) => applicationId != 'com.osaracx.driveit' || playAuthEnabled;

  static bool permitsIdentityChange({
    required bool isPlay,
    required bool ownerBound,
  }) => !isPlay || ownerBound;
}
