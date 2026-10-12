import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'gps_session_ownership.dart';
import 'local_source_bundle.dart';
import 'owner_scoped_local_store.dart';

enum OwnerSyncMutationKind { driveUpsert, driveTombstone }

enum OwnerSyncMutationState {
  queued,
  sending,
  retryableFailure,
  conflict,
  acknowledged,
}

/// Versioned, account-bound local mutation contract. It is intentionally not
/// an HTTP/Supabase implementation; the final backend phase owns that mapping.
class OwnerSyncMutation {
  const OwnerSyncMutation({
    required this.version,
    required this.kind,
    required this.ownerScope,
    required this.ownerId,
    required this.idempotencyKey,
    required this.payloadFingerprint,
    required this.sourceIdentity,
    required this.payload,
  });

  final int version;
  final OwnerSyncMutationKind kind;
  final String ownerScope;
  final String ownerId;
  final String idempotencyKey;
  final String payloadFingerprint;
  final String sourceIdentity;
  final Map<String, dynamic> payload;

  Map<String, Object?> toMap() => {
    'version': version,
    'kind': kind.name,
    'ownerScope': ownerScope,
    'ownerId': ownerId,
    'idempotencyKey': idempotencyKey,
    'payloadFingerprint': payloadFingerprint,
    'sourceIdentity': sourceIdentity,
    'payload': payload,
  };

  factory OwnerSyncMutation.fromMap(Map value) {
    if (value['version'] != 1 ||
        value['ownerScope'] is! String ||
        value['ownerId'] is! String ||
        value['idempotencyKey'] is! String ||
        value['payloadFingerprint'] is! String ||
        value['sourceIdentity'] is! String ||
        value['payload'] is! Map) {
      throw StateError('Unsupported owner sync mutation');
    }
    return OwnerSyncMutation(
      version: 1,
      kind: OwnerSyncMutationKind.values.byName(value['kind'] as String),
      ownerScope: value['ownerScope'] as String,
      ownerId: value['ownerId'] as String,
      idempotencyKey: value['idempotencyKey'] as String,
      payloadFingerprint: value['payloadFingerprint'] as String,
      sourceIdentity: value['sourceIdentity'] as String,
      payload: Map<String, dynamic>.from(value['payload'] as Map),
    );
  }
}

class OwnerSyncReceipt {
  const OwnerSyncReceipt({
    required this.ownerScope,
    required this.idempotencyKey,
    required this.payloadFingerprint,
    required this.remoteId,
  });

  final String ownerScope;
  final String idempotencyKey;
  final String payloadFingerprint;
  final String remoteId;
}

class OwnerSyncTransportFailure implements Exception {
  const OwnerSyncTransportFailure(this.code);
  final String code;
}

class OwnerSyncConflict implements Exception {
  const OwnerSyncConflict(this.code);
  final String code;
}

class OwnerSyncReconciliationResult {
  const OwnerSyncReconciliationResult({
    required this.queued,
    required this.skipped,
  });

  final int queued;
  final int skipped;
}

class OwnerSyncWorkerResult {
  const OwnerSyncWorkerResult({
    required this.attempted,
    required this.acknowledged,
    required this.notAcknowledged,
  });

  final int attempted;
  final int acknowledged;
  final int notAcknowledged;
}

abstract interface class OwnerSyncRemoteAdapter {
  Future<OwnerSyncReceipt> apply(OwnerSyncMutation mutation);
}

/// Durable queue for only new, proven, account-owned drives. Construction is
/// explicit and there is no production network adapter or automatic worker.
class OwnerDriveSyncClient {
  OwnerDriveSyncClient({required this.store, required this.requireCurrent});

  static const boxName = 'owner_sync_outbox_v1';
  static const contractVersion = 1;

  final OwnerScopedLocalStore store;
  final void Function() requireCurrent;
  GpsOwner get owner => store.owner;

  Future<String> enqueueDrive(String driveId) async {
    requireCurrent();
    final accountId = _requireAccount();
    if (driveId.isEmpty) throw ArgumentError.value(driveId, 'driveId');

    final completed = store.read<Map>(
      owner,
      'owned_drive_finalization_v1',
      driveId,
    );
    if (completed?['state'] != 'completed' ||
        completed?['derivedReady'] != true) {
      throw StateError('Only completed owner drives can be queued');
    }
    if (store.read<Map>(owner, 'local_lifecycle_v1', 'history:$driveId') !=
        null) {
      throw StateError('Deleted owner drives cannot be queued');
    }
    final source = store.repositories(owner).source(driveId);
    if (source == null || source.telemetry == null) {
      throw StateError('Verified owner drive source is incomplete');
    }
    source.validate();
    final provenance = source.sourceProvenance;
    if (provenance?.isProven != true || provenance!.ownerScope != store.scope) {
      throw StateError('Only proven owner drive sources can be queued');
    }
    final payload = source.toMap();
    final key = _idempotencyKey(
      accountId,
      OwnerSyncMutationKind.driveUpsert,
      provenance.sourceIdentity!,
    );
    return _stage(
      key: key,
      mutation: _mutation(
        kind: OwnerSyncMutationKind.driveUpsert,
        accountId: accountId,
        sourceIdentity: provenance.sourceIdentity!,
        payload: payload,
      ),
    );
  }

  /// Reconciles only this account's completed, non-deleted finalizations.
  /// This repairs the crash window between the owner Hive save and the outbox
  /// flush. It never scans the legacy archive, guest scope, or GPS journal.
  Future<OwnerSyncReconciliationResult> reconcileFinalizedDrives() async {
    requireCurrent();
    _requireAccount();
    var queued = 0;
    var skipped = 0;
    final ids = store.keys(owner, 'owned_drive_finalization_v1')
        .whereType<String>()
        .toList(growable: false);
    for (final id in ids) {
      requireCurrent();
      final finalized = store.read<Map>(
        owner,
        'owned_drive_finalization_v1',
        id,
      );
      if (finalized?['state'] != 'completed' ||
          finalized?['derivedReady'] != true ||
          store.read<Map>(owner, 'local_lifecycle_v1', 'history:$id') != null) {
        skipped++;
        continue;
      }
      final source = store.repositories(owner).source(id);
      final provenance = source?.sourceProvenance;
      if (source == null ||
          source.telemetry == null ||
          provenance?.isProven != true ||
          provenance!.ownerScope != store.scope) {
        // Unknown, legacy, incomplete, or contradictory evidence is not
        // promoted into cloud work. A later verified record may be retried.
        skipped++;
        continue;
      }
      source.validate();
      await enqueueDrive(id);
      queued++;
    }
    return OwnerSyncReconciliationResult(queued: queued, skipped: skipped);
  }

  /// Persist a minimal deletion intent only when the existing durable
  /// lifecycle tombstone already carries the exact sync evidence. Current
  /// History tombstones do not yet carry this metadata, so they fail closed.
  Future<String> enqueueTombstone(String driveId) async {
    requireCurrent();
    final accountId = _requireAccount();
    final tombstone = store.read<Map>(
      owner,
      'local_lifecycle_v1',
      'history:$driveId',
    );
    final source = store.repositories(owner).source(driveId);
    final provenance = source?.sourceProvenance;
    final deletionId = tombstone?['syncDeletionId'];
    final deletedAt = tombstone?['deletedAt'];
    if (tombstone?['state'] != 'completed' ||
        deletionId is! String ||
        deletionId.isEmpty ||
        deletedAt is! String ||
        provenance?.isProven != true ||
        provenance!.ownerScope != store.scope ||
        !_isUuid(provenance.sourceIdentity!)) {
      throw StateError('Durable sync tombstone evidence is unavailable');
    }
    final payload = {'deletionId': deletionId, 'deletedAt': deletedAt};
    final key = _idempotencyKey(
      accountId,
      OwnerSyncMutationKind.driveTombstone,
      deletionId,
    );
    return _stage(
      key: key,
      mutation: _mutation(
        kind: OwnerSyncMutationKind.driveTombstone,
        accountId: accountId,
        sourceIdentity: provenance.sourceIdentity!,
        payload: payload,
      ),
    );
  }

  Future<String> _stage({
    required String key,
    required OwnerSyncMutation mutation,
  }) async {
    final previous = store.read<Map>(owner, boxName, key);
    if (previous != null) {
      final existing = OwnerSyncMutation.fromMap(
        Map.from(previous['mutation'] as Map),
      );
      if (existing.payloadFingerprint != mutation.payloadFingerprint ||
          existing.ownerScope != mutation.ownerScope ||
          existing.sourceIdentity != mutation.sourceIdentity ||
          existing.kind != mutation.kind) {
        throw const OwnerSyncConflict('local_idempotency_payload_conflict');
      }
      return key;
    }
    await store.put(owner, boxName, key, {
      'mutation': mutation.toMap(),
      'state': OwnerSyncMutationState.queued.name,
      'attemptCount': 0,
      'lastErrorCode': null,
      'receipt': null,
    });
    requireCurrent();
    return key;
  }

  Future<bool> send(String key, OwnerSyncRemoteAdapter remote) async {
    requireCurrent();
    _requireAccount();
    final row = store.read<Map>(owner, boxName, key);
    if (row == null) throw StateError('Owner sync mutation not found');
    if (row['state'] == OwnerSyncMutationState.acknowledged.name) return true;
    if (row['state'] == OwnerSyncMutationState.conflict.name) return false;
    final mutation = OwnerSyncMutation.fromMap(
      Map.from(row['mutation'] as Map),
    );
    _validateMutationOwner(mutation);
    final sourceDriveId = mutation.kind == OwnerSyncMutationKind.driveUpsert
        ? LocalSourceBundle.fromMap(mutation.payload).drive.id
        : null;
    if (sourceDriveId != null &&
        store.read<Map>(
              owner,
              'local_lifecycle_v1',
              'history:$sourceDriveId',
            ) !=
            null) {
      await store.put(owner, boxName, key, {
        ...row,
        'state': OwnerSyncMutationState.conflict.name,
        'lastErrorCode': 'drive_deleted_before_sync',
      });
      return false;
    }
    final attemptCount = (row['attemptCount'] as int? ?? 0) + 1;
    await store.put(owner, boxName, key, {
      ...row,
      'state': OwnerSyncMutationState.sending.name,
      'attemptCount': attemptCount,
      'lastErrorCode': null,
    });
    requireCurrent();

    final OwnerSyncReceipt receipt;
    try {
      receipt = await remote.apply(mutation);
    } on OwnerSyncTransportFailure catch (error) {
      if (!_isSafeErrorCode(error.code)) {
        throw const OwnerSyncConflict('transport_error_code_invalid');
      }
      requireCurrent();
      await store.put(owner, boxName, key, {
        ...store.read<Map>(owner, boxName, key)!,
        'state': OwnerSyncMutationState.retryableFailure.name,
        'lastErrorCode': error.code,
      });
      return false;
    } on OwnerSyncConflict catch (error) {
      if (!_isSafeErrorCode(error.code)) {
        throw const OwnerSyncConflict('remote_conflict_code_invalid');
      }
      requireCurrent();
      await store.put(owner, boxName, key, {
        ...store.read<Map>(owner, boxName, key)!,
        'state': OwnerSyncMutationState.conflict.name,
        'lastErrorCode': error.code,
      });
      return false;
    }
    requireCurrent();
    if (receipt.ownerScope != mutation.ownerScope ||
        receipt.idempotencyKey != mutation.idempotencyKey ||
        receipt.payloadFingerprint != mutation.payloadFingerprint ||
        receipt.remoteId.isEmpty) {
      await store.put(owner, boxName, key, {
        ...store.read<Map>(owner, boxName, key)!,
        'state': OwnerSyncMutationState.conflict.name,
        'lastErrorCode': 'remote_receipt_mismatch',
      });
      return false;
    }
    await store.put(owner, boxName, key, {
      ...store.read<Map>(owner, boxName, key)!,
      'state': OwnerSyncMutationState.acknowledged.name,
      'lastErrorCode': null,
      'receipt': {
        'ownerScope': receipt.ownerScope,
        'idempotencyKey': receipt.idempotencyKey,
        'payloadFingerprint': receipt.payloadFingerprint,
        'remoteId': receipt.remoteId,
      },
    });
    return true;
  }

  List<String> pendingKeys() {
    requireCurrent();
    _requireAccount();
    return store
        .keys(owner, boxName)
        .whereType<String>()
        .where((key) {
          final row = store.read<Map>(owner, boxName, key);
          return row != null &&
              row['state'] != OwnerSyncMutationState.conflict.name &&
              row['state'] != OwnerSyncMutationState.acknowledged.name;
        })
        .toList(growable: false);
  }

  Map? readRecord(String key) {
    requireCurrent();
    _requireAccount();
    return store.read<Map>(owner, boxName, key);
  }

  String _requireAccount() {
    if (owner.kind != GpsOwnerKind.account || owner.userId == null) {
      throw StateError('Owner sync requires an authenticated account scope');
    }
    return owner.userId!;
  }

  OwnerSyncMutation _mutation({
    required OwnerSyncMutationKind kind,
    required String accountId,
    required String sourceIdentity,
    required Map<String, dynamic> payload,
  }) {
    final canonicalPayload = jsonEncode(payload);
    final fingerprint = sha256
        .convert(utf8.encode(canonicalPayload))
        .toString();
    return OwnerSyncMutation(
      version: contractVersion,
      kind: kind,
      ownerScope: store.scope,
      ownerId: accountId,
      idempotencyKey: _idempotencyKey(accountId, kind, sourceIdentity),
      payloadFingerprint: fingerprint,
      sourceIdentity: sourceIdentity,
      payload: payload,
    );
  }

  String _idempotencyKey(
    String accountId,
    OwnerSyncMutationKind kind,
    String identity,
  ) =>
      'owner-sync-v$contractVersion:${sha256.convert(utf8.encode('${store.scope}|$accountId|${kind.name}|$identity'))}';

  void _validateMutationOwner(OwnerSyncMutation mutation) {
    final canonicalFingerprint = sha256
        .convert(utf8.encode(jsonEncode(mutation.payload)))
        .toString();
    if (mutation.version != contractVersion ||
        mutation.ownerId != owner.userId ||
        mutation.ownerScope != owner.targetStore ||
        mutation.payloadFingerprint != canonicalFingerprint ||
        mutation.idempotencyKey !=
            _idempotencyKey(
              mutation.ownerId,
              mutation.kind,
              mutation.kind == OwnerSyncMutationKind.driveTombstone
                  ? mutation.payload['deletionId'] as String? ?? ''
                  : mutation.sourceIdentity,
            ) ||
        !_isUuid(mutation.sourceIdentity)) {
      throw const OwnerSyncConflict('mutation_owner_or_identity_conflict');
    }
    if (mutation.kind == OwnerSyncMutationKind.driveUpsert) {
      final bundle = LocalSourceBundle.fromMap(mutation.payload);
      bundle.validate();
      if (bundle.ownerScope != owner.targetStore ||
          bundle.sourceProvenance?.isProven != true ||
          bundle.sourceProvenance!.sourceIdentity != mutation.sourceIdentity) {
        throw const OwnerSyncConflict('mutation_source_provenance_conflict');
      }
    } else if (mutation.kind == OwnerSyncMutationKind.driveTombstone) {
      if (mutation.payload['deletionId'] is! String ||
          mutation.payload['deletedAt'] is! String) {
        throw const OwnerSyncConflict('tombstone_evidence_missing');
      }
      final deletedAt = DateTime.tryParse(
        mutation.payload['deletedAt'] as String,
      );
      if (deletedAt == null || !deletedAt.isUtc) {
        throw const OwnerSyncConflict('tombstone_timestamp_invalid');
      }
    }
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value);

  static bool _isSafeErrorCode(String value) =>
      RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value);
}

/// A bounded, explicitly invoked worker. Supplying the remote adapter is
/// required; there is no timer, networking setup, or automatic production run.
class OwnerDriveSyncWorker {
  OwnerDriveSyncWorker({required this.client, required this.remote});

  final OwnerDriveSyncClient client;
  final OwnerSyncRemoteAdapter remote;

  /// Processes a snapshot of at most [limit] pending keys once. A retry is a
  /// later explicit invocation, never an immediate loop on failure.
  Future<OwnerSyncWorkerResult> runOnce({int limit = 16}) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final keys = client.pendingKeys().take(limit).toList(growable: false);
    var acknowledged = 0;
    var notAcknowledged = 0;
    for (final key in keys) {
      final ok = await client.send(key, remote);
      if (ok) {
        acknowledged++;
      } else {
        notAcknowledged++;
      }
    }
    return OwnerSyncWorkerResult(
      attempted: keys.length,
      acknowledged: acknowledged,
      notAcknowledged: notAcknowledged,
    );
  }
}
