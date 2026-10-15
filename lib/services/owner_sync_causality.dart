import 'dart:async';

/// Local value contracts for the Phase 8 deletion/lease milestone.
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

abstract interface class OwnerDriveLeaseTransport {
  Future<OwnerDriveLeaseEvidence> updateLease({
    required String sourceIdentity,
    required String deviceId,
    required String sessionId,
    int? fencingToken,
  });
}

/// Explicit lifecycle-owned heartbeat. Never starts GPS, changes its owner,
/// or discards offline recording. A failed/stale renewal stops this heartbeat
/// and surfaces a conflict; the caller must retain its local session.
class OwnerDriveLeaseHeartbeat {
  OwnerDriveLeaseHeartbeat({
    required this.remote,
    required this.requireCurrent,
    required this.onFailure,
  });
  final OwnerDriveLeaseTransport remote;
  final void Function() requireCurrent;
  final void Function(Object) onFailure;
  Timer? _timer;
  OwnerDriveLeaseEvidence? evidence;
  int _generation = 0;
  bool _busy = false;

  Future<void> start({
    required String sourceIdentity,
    required String deviceId,
    required String sessionId,
  }) async {
    stop();
    final generation = _generation;
    requireCurrent();
    final result = await remote.updateLease(
      sourceIdentity: sourceIdentity,
      deviceId: deviceId,
      sessionId: sessionId,
    );
    requireCurrent();
    if (generation != _generation) throw StateError('Lease start revoked');
    evidence = result;
    _timer = Timer.periodic(
      OwnerDriveLeaseEvidence.heartbeatInterval,
      (_) => unawaited(renew()),
    );
  }

  Future<void> renew() async {
    final previous = evidence;
    if (_busy || previous == null) return;
    final generation = _generation;
    _busy = true;
    try {
      requireCurrent();
      final next = await remote.updateLease(
        sourceIdentity: previous.sourceIdentity,
        deviceId: previous.deviceId,
        sessionId: previous.sessionId,
        fencingToken: previous.fencingToken,
      );
      requireCurrent();
      if (generation != _generation) return;
      if (!previous.sameLeaseAs(next)) throw StateError('Lease fenced');
      evidence = next;
    } catch (e) {
      if (generation == _generation) {
        stop();
        onFailure(e);
      }
    } finally {
      _busy = false;
    }
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    evidence = null;
  }
}
