import 'gps_session_ownership.dart';
import 'local_owner_lifecycle.dart';

/// A preview is not ownership proof or a migration receipt. All uncertain
/// fields stay explicit; in particular distance is not inferred from timestamps.
class LegacyOwnerPreview {
  const LegacyOwnerPreview({
    required this.manifestFingerprint,
    required this.driveCount,
    required this.worldStatus,
    required this.careerStatus,
    this.distanceKm,
    this.unresolved = const [],
    this.copyContractVerified = false,
  });
  final String manifestFingerprint;
  final int driveCount;
  final double? distanceKm;
  final String worldStatus;
  final String careerStatus;
  final List<String> unresolved;

  /// Must cover files, relationships, free space and durable global claims.
  /// The current quarantine manifest alone cannot supply this proof.
  final bool copyContractVerified;
  bool get canCopy =>
      copyContractVerified &&
      unresolved.isEmpty &&
      manifestFingerprint.isNotEmpty &&
      driveCount > 0;
}

class LegacyOwnerConsent {
  LegacyOwnerConsent._(this.lease, this.fingerprint);
  final LocalOwnerLease lease;
  final String fingerprint;
  GpsOwner get target => lease.owner;
  int get epoch => lease.epoch;
  void verify(String currentFingerprint) {
    lease.requireCurrent();
    if (target.kind != GpsOwnerKind.account ||
        currentFingerprint != fingerprint) {
      throw StateError('Legacy consent invalidated');
    }
  }
}

/// Explicit approval only. A caller cannot turn the existing copy-only 5B
/// preparation into an account import by displaying this preview.
class LegacyOwnerConsentController {
  LegacyOwnerConsentController(this.runtime, this.preview)
    : _lease = runtime.lease;
  final LocalOwnerLifecycle runtime;
  final LegacyOwnerPreview preview;
  final LocalOwnerLease _lease;
  bool _decided = false;
  GpsOwner get destination => _lease.owner;
  bool get valid =>
      !_decided && _lease.isCurrent && destination.kind == GpsOwnerKind.account;
  LegacyOwnerConsent approve() {
    if (!valid || !preview.canCopy) {
      throw StateError('Legacy copy evidence incomplete or consent expired');
    }
    _decided = true;
    return LegacyOwnerConsent._(_lease, preview.manifestFingerprint);
  }

  void skip() {
    _decided = true;
  }
}
