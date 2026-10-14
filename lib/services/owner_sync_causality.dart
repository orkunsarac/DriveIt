/// Local value contracts for the planned Phase 8 deletion/lease milestone.
///
/// These types are validation scaffolding only. They are not connected to the
/// production sync worker, GPS start, delete UI, or any remote RPC. In
/// particular, no local History deletion is promoted into a server tombstone.
class OwnerDriveDeletionEvidence {
  OwnerDriveDeletionEvidence({
    required this.ownerId,
    required this.deletionId,
    required this.sourceIdentity,
    required this.deletedAt,
    required this.observedRemoteSequence,
    required this.causalVersion,
  }) {
    if (!_uuid.hasMatch(ownerId) ||
        !_uuidV4.hasMatch(deletionId) ||
        !_uuidV4.hasMatch(sourceIdentity) ||
        !deletedAt.isUtc ||
        observedRemoteSequence < 0 ||
        causalVersion < 1) {
      throw const FormatException('Deletion evidence is incomplete or invalid');
    }
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final String ownerId;
  final String deletionId;
  final String sourceIdentity;
  final DateTime deletedAt;
  final int observedRemoteSequence;
  final int causalVersion;

  /// Exact retry evidence is idempotent; changing any claim is a conflict.
  bool sameOperationAs(OwnerDriveDeletionEvidence other) =>
      ownerId == other.ownerId &&
      deletionId == other.deletionId &&
      sourceIdentity == other.sourceIdentity &&
      deletedAt == other.deletedAt &&
      observedRemoteSequence == other.observedRemoteSequence &&
      causalVersion == other.causalVersion;
}

/// A synthetic model of the server lease/fencing contract. Constructing this
/// value does not acquire or renew a real lease.
class OwnerDriveLeaseEvidence {
  OwnerDriveLeaseEvidence({
    required this.ownerId,
    required this.deviceId,
    required this.sessionId,
    required this.sourceIdentity,
    required this.fencingToken,
    required this.heartbeatAt,
    required this.expiresAt,
  }) {
    final lifetime = expiresAt.difference(heartbeatAt);
    if (!_uuid.hasMatch(ownerId) ||
        deviceId.trim().isEmpty ||
        deviceId.length > 128 ||
        sessionId.trim().isEmpty ||
        sessionId.length > 128 ||
        !_uuidV4.hasMatch(sourceIdentity) ||
        fencingToken < 1 ||
        !heartbeatAt.isUtc ||
        !expiresAt.isUtc ||
        lifetime <= Duration.zero ||
        lifetime > maximumLeaseLifetime) {
      throw const FormatException('Lease evidence is incomplete or invalid');
    }
  }

  static const heartbeatInterval = Duration(seconds: 30);
  static const maximumLeaseLifetime = Duration(minutes: 3);
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final String ownerId;
  final String deviceId;
  final String sessionId;
  final String sourceIdentity;
  final int fencingToken;
  final DateTime heartbeatAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) =>
      now.isUtc && !now.isBefore(heartbeatAt) && now.isBefore(expiresAt);

  /// A lease from the same logical drive with a newer token fences this one.
  bool isFencedBy(OwnerDriveLeaseEvidence current) =>
      ownerId == current.ownerId &&
      sessionId == current.sessionId &&
      sourceIdentity == current.sourceIdentity &&
      current.fencingToken > fencingToken;

  bool sameLeaseAs(OwnerDriveLeaseEvidence other) =>
      ownerId == other.ownerId &&
      deviceId == other.deviceId &&
      sessionId == other.sessionId &&
      sourceIdentity == other.sourceIdentity &&
      fencingToken == other.fencingToken;
}
