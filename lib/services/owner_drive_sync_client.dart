import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'gps_session_ownership.dart';
import 'local_source_bundle.dart';
import 'owner_scoped_local_store.dart';
import 'gps_hive_transfer_sink.dart';
import 'gps_session_transfer.dart';
import 'drive_score_storage_service.dart';
import '../models/drive_session.dart';
import '../models/drive_score_record.dart';
import '../models/canonical_telemetry_point.dart';
import 'drive_source_provenance.dart';

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

class OwnerSyncRemoteChange {
  const OwnerSyncRemoteChange({required this.cursor, required this.mutation});
  final String cursor;
  final OwnerSyncMutation mutation;
}

class OwnerSyncDownloadPage {
  const OwnerSyncDownloadPage({
    required this.ownerId,
    required this.fromCursor,
    required this.nextCursor,
    required this.changes,
  });
  final String ownerId;
  final String fromCursor;
  final String nextCursor;
  final List<OwnerSyncRemoteChange> changes;
}

/// Optional download half of the future protocol. Implementations must scope
/// the cursor and every row to the authenticated owner; clients still verify
/// all returned evidence before applying it.
abstract interface class OwnerSyncDownloadAdapter {
  Future<OwnerSyncDownloadPage> download({
    required String ownerId,
    required String afterCursor,
    required int limit,
  });
}

class OwnerSyncDownloadResult {
  const OwnerSyncDownloadResult({
    required this.applied,
    required this.duplicates,
    required this.cursor,
  });
  final int applied;
  final int duplicates;
  final String cursor;
}

/// Durable queue for only new, proven, account-owned drives. Construction is
/// explicit and there is no production network adapter or automatic worker.
class OwnerDriveSyncClient {
  OwnerDriveSyncClient({required this.store, required this.requireCurrent});

  static const boxName = 'owner_sync_outbox_v1';
  static const downloadStateBox = 'owner_sync_download_v1';
  static const receivedBox = 'owner_sync_received_v1';
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
    // World map-matching roads are a mutable derived projection. They have
    // their own lifecycle and must not mutate the immutable drive upsert (or
    // change its fingerprint after a server ACK). Route/telemetry remain the
    // canonical inputs from which this device can derive its own World state.
    final payload = source.toMap()..['roads'] = <dynamic>[];
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

  /// Applies one server page to this account's separate local replica. The
  /// cursor advances only after all rows are durable and read back. Importing
  /// rows stay hidden from History until the finalization marker is committed.
  /// Deletion changes and legacy/unproven rows fail closed.
  Future<OwnerSyncDownloadResult> downloadOnce(
    OwnerSyncDownloadAdapter remote, {
    int limit = 32,
  }) async {
    requireCurrent();
    final accountId = _requireAccount();
    if (limit <= 0 || limit > 100) {
      throw ArgumentError.value(limit, 'limit');
    }
    final stateKey = 'drive_cursor_v1';
    final previous = store.read<Map>(owner, downloadStateBox, stateKey);
    if (previous != null &&
        (previous['ownerId'] != accountId ||
            previous['ownerScope'] != store.scope ||
            previous['version'] != 1 ||
            previous['cursor'] is! String)) {
      throw const OwnerSyncConflict('download_cursor_owner_conflict');
    }
    final cursor = previous?['cursor'] as String? ?? '';
    final page = await remote.download(
      ownerId: accountId,
      afterCursor: cursor,
      limit: limit,
    );
    requireCurrent();
    if (page.ownerId != accountId ||
        page.fromCursor != cursor ||
        (page.nextCursor.isEmpty && page.changes.isNotEmpty) ||
        page.changes.length > limit) {
      throw const OwnerSyncConflict('download_page_scope_or_cursor_conflict');
    }
    // Validate the entire page before any local write. A cross-owner or
    // unsupported mutation therefore cannot partially affect this account.
    for (final change in page.changes) {
      if (change.cursor.isEmpty ||
          change.mutation.kind != OwnerSyncMutationKind.driveUpsert) {
        throw const OwnerSyncConflict('download_change_unsupported');
      }
      _validateMutationOwner(change.mutation);
    }
    var applied = 0;
    var duplicates = 0;
    for (final change in page.changes) {
      requireCurrent();
      final wasApplied = await _applyDownloadedDrive(change.mutation);
      if (wasApplied) {
        applied++;
      } else {
        duplicates++;
      }
    }
    requireCurrent();
    await store.put(owner, downloadStateBox, stateKey, {
      'version': 1,
      'ownerId': accountId,
      'ownerScope': store.scope,
      'cursor': page.nextCursor,
    });
    requireCurrent();
    final saved = store.read<Map>(owner, downloadStateBox, stateKey);
    if (saved?['cursor'] != page.nextCursor ||
        saved?['ownerId'] != accountId ||
        saved?['ownerScope'] != store.scope) {
      throw StateError('Download checkpoint read-back failed');
    }
    return OwnerSyncDownloadResult(
      applied: applied,
      duplicates: duplicates,
      cursor: page.nextCursor,
    );
  }

  Future<bool> _applyDownloadedDrive(OwnerSyncMutation mutation) async {
    if (mutation.kind != OwnerSyncMutationKind.driveUpsert) {
      throw const OwnerSyncConflict('download_tombstone_not_supported');
    }
    final bundle = LocalSourceBundle.fromMap(mutation.payload);
    bundle.validate();
    final provenance = bundle.sourceProvenance;
    if (bundle.ownerScope != store.scope ||
        provenance?.isProven != true ||
        provenance!.ownerScope != store.scope ||
        provenance.sourceIdentity != mutation.sourceIdentity ||
        !_isUuid(mutation.sourceIdentity)) {
      throw const OwnerSyncConflict('download_provenance_invalid');
    }
    final driveId = bundle.drive.id;
    final receivedKey = mutation.idempotencyKey;
    final receipt = store.read<Map>(owner, receivedBox, receivedKey);
    if (receipt != null &&
        (receipt['ownerId'] != owner.userId ||
            receipt['ownerScope'] != store.scope ||
            receipt['sourceIdentity'] != mutation.sourceIdentity ||
            receipt['driveId'] != driveId ||
            receipt['payloadFingerprint'] != mutation.payloadFingerprint)) {
      throw const OwnerSyncConflict('download_receipt_conflict');
    }
    if (receipt?['state'] == 'completed') {
      _verifyDownloadedDrive(bundle, mutation);
      return false;
    }

    final priorDrive = store.read<DriveSession>(owner, 'drives', driveId);
    final priorFinalization = store.read<Map>(
      owner,
      'owned_drive_finalization_v1',
      driveId,
    );
    final priorProvenance = store.read<Map>(
      owner,
      'drive_source_provenance_v1',
      driveId,
    );
    if (priorDrive != null) {
      final p = priorProvenance == null
          ? null
          : DriveSourceProvenance.fromMap(priorProvenance);
      final matchingImport =
          priorFinalization?['state'] == 'sync_importing' &&
          priorFinalization?['sourceIdentity'] == mutation.sourceIdentity &&
          priorFinalization?['payloadFingerprint'] ==
              mutation.payloadFingerprint;
      if ((p == null && !matchingImport) ||
          (p != null &&
              (p.isProven != true ||
                  p.sourceIdentity != mutation.sourceIdentity)) ||
          (priorFinalization?['state'] != 'completed' && !matchingImport)) {
        throw const OwnerSyncConflict('download_local_drive_identity_conflict');
      }
      if (jsonEncode(driveTransferManifest(priorDrive)) !=
          jsonEncode(driveTransferManifest(bundle.drive))) {
        throw const OwnerSyncConflict('download_local_drive_content_conflict');
      }
    } else if (priorFinalization != null &&
        (priorFinalization['state'] != 'sync_importing' ||
            priorFinalization['sourceIdentity'] != mutation.sourceIdentity ||
            priorFinalization['payloadFingerprint'] !=
                mutation.payloadFingerprint)) {
      throw const OwnerSyncConflict('download_finalization_conflict');
    }

    // The pending marker is written first: owner History readers exclude it.
    // It is also the durable retry descriptor after a process interruption.
    await store.put(owner, 'owned_drive_finalization_v1', driveId, {
      'state': 'sync_importing',
      'derivedReady': false,
      'syncImport': true,
      'ownerId': owner.userId,
      'ownerScope': store.scope,
      'sourceIdentity': mutation.sourceIdentity,
      'payloadFingerprint': mutation.payloadFingerprint,
      'idempotencyKey': receivedKey,
    });
    await store.put(owner, receivedBox, receivedKey, {
      'version': 1,
      'state': 'applying',
      'ownerId': owner.userId,
      'ownerScope': store.scope,
      'sourceIdentity': mutation.sourceIdentity,
      'driveId': driveId,
      'payloadFingerprint': mutation.payloadFingerprint,
    });

    final existingDrive = store.read<DriveSession>(owner, 'drives', driveId);
    if (existingDrive != null &&
        jsonEncode(driveTransferManifest(existingDrive)) !=
        jsonEncode(driveTransferManifest(bundle.drive))) {
      throw const OwnerSyncConflict('download_drive_payload_conflict');
    }
    // Re-put even a matching value: a prior attempt may have failed after Hive
    // put but before flush, and in-memory equality is not durability evidence.
    await store.put(owner, 'drives', driveId, bundle.drive);
    final telemetry = bundle.telemetry;
    if (telemetry == null) {
      throw const OwnerSyncConflict('download_telemetry_missing');
    }
    final existingTelemetry = store.read<DriveTelemetryRecord>(
      owner,
      'drive_telemetry',
      driveId,
    );
    if (existingTelemetry != null &&
        !_sameTelemetry(existingTelemetry, telemetry)) {
      throw const OwnerSyncConflict('download_telemetry_conflict');
    }
    await store.put(owner, 'drive_telemetry', driveId, telemetry);
    final priorSourceEvidence = store.read<Map>(
      owner,
      'drive_source_provenance_v1',
      driveId,
    );
    if (priorSourceEvidence != null &&
        jsonEncode(priorSourceEvidence) != jsonEncode(provenance.toMap())) {
      throw const OwnerSyncConflict('download_source_evidence_conflict');
    }
    await store.put(
      owner,
      'drive_source_provenance_v1',
      driveId,
      provenance.toMap(),
    );
    final score = bundle.score;
    if (score != null) {
      final scoreKey = DriveScoreStorageService.keyFor(
        driveId,
        score.algorithmVersion,
      );
      final priorScore = store.read<DriveScoreRecord>(
        owner,
        'drive_scores',
        scoreKey,
      );
      if (priorScore != null &&
          jsonEncode(_scoreMap(priorScore)) != jsonEncode(_scoreMap(score))) {
        throw const OwnerSyncConflict('download_score_conflict');
      }
      await store.put(owner, 'drive_scores', scoreKey, score);
    }

    _verifyDownloadedCore(bundle, mutation);
    await store.put(owner, 'owned_drive_finalization_v1', driveId, {
      'state': 'completed',
      'derivedReady': true,
      'syncImport': true,
      'ownerId': owner.userId,
      'ownerScope': store.scope,
      'sourceIdentity': mutation.sourceIdentity,
      'payloadFingerprint': mutation.payloadFingerprint,
      'idempotencyKey': receivedKey,
    });
    await store.put(owner, receivedBox, receivedKey, {
      'version': 1,
      'state': 'completed',
      'ownerId': owner.userId,
      'ownerScope': store.scope,
      'sourceIdentity': mutation.sourceIdentity,
      'driveId': driveId,
      'payloadFingerprint': mutation.payloadFingerprint,
    });
    _verifyDownloadedDrive(bundle, mutation);
    return true;
  }

  void _verifyDownloadedCore(LocalSourceBundle bundle, OwnerSyncMutation m) {
    final id = bundle.drive.id;
    final drive = store.read<DriveSession>(owner, 'drives', id);
    final telemetry = store.read<DriveTelemetryRecord>(
      owner,
      'drive_telemetry',
      id,
    );
    final p = store.read<Map>(owner, 'drive_source_provenance_v1', id);
    if (drive == null ||
        jsonEncode(driveTransferManifest(drive)) !=
            jsonEncode(driveTransferManifest(bundle.drive)) ||
        telemetry == null ||
        !_sameTelemetry(telemetry, bundle.telemetry!) ||
        p == null ||
        jsonEncode(p) != jsonEncode(bundle.sourceProvenance!.toMap()) ||
        m.ownerId != owner.userId ||
        m.ownerScope != store.scope) {
      throw StateError('Downloaded drive read-back failed');
    }
  }

  void _verifyDownloadedDrive(LocalSourceBundle bundle, OwnerSyncMutation m) {
    _verifyDownloadedCore(bundle, m);
    final finalization = store.read<Map>(
      owner,
      'owned_drive_finalization_v1',
      bundle.drive.id,
    );
    final receipt = store.read<Map>(owner, receivedBox, m.idempotencyKey);
    if (finalization?['state'] != 'completed' ||
        finalization?['sourceIdentity'] != m.sourceIdentity ||
        finalization?['payloadFingerprint'] != m.payloadFingerprint ||
        receipt?['state'] != 'completed' ||
        receipt?['payloadFingerprint'] != m.payloadFingerprint) {
      throw StateError('Downloaded drive completion evidence invalid');
    }
  }

  static bool _sameTelemetry(
    DriveTelemetryRecord left,
    DriveTelemetryRecord right,
  ) =>
      left.driveSessionId == right.driveSessionId &&
      left.dataVersion == right.dataVersion &&
      left.createdAt == right.createdAt &&
      jsonEncode(left.acquisitionMetadata) ==
          jsonEncode(right.acquisitionMetadata) &&
      jsonEncode(left.points.map(GpsSessionTransfer.pointContent).toList()) ==
          jsonEncode(right.points.map(GpsSessionTransfer.pointContent).toList());

  static Map<String, Object?> _scoreMap(DriveScoreRecord value) => {
    'driveId': value.driveId,
    'algorithm': value.algorithmVersion,
    'telemetryVersion': value.telemetryDataVersion,
    'calculatedAt': value.calculatedAt.toIso8601String(),
    'total': value.totalScore,
    'confidence': value.overallConfidence,
    'categories': value.categories.map((category) => category.toMap()).toList(),
  };

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
      if (bundle.telemetry == null ||
          bundle.ownerScope != owner.targetStore ||
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
