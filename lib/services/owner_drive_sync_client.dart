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
import 'owner_sync_canonical_json.dart';

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
    if ((value['version'] != 1 && value['version'] != 2) ||
        value['ownerScope'] is! String ||
        value['ownerId'] is! String ||
        value['idempotencyKey'] is! String ||
        value['payloadFingerprint'] is! String ||
        value['sourceIdentity'] is! String ||
        value['payload'] is! Map) {
      throw StateError('Unsupported owner sync mutation');
    }
    return OwnerSyncMutation(
      version: value['version'] as int,
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
    this.changeSequence,
  });

  final String ownerScope;
  final String idempotencyKey;
  final String payloadFingerprint;
  final String remoteId;
  final int? changeSequence;
}

enum OwnerSyncStagingState { staging, finalized }

/// Metadata sent to an authenticated staging endpoint. Payload bytes are
/// uploaded separately to a private owner-scoped staging object.
class OwnerSyncUploadDescriptor {
  const OwnerSyncUploadDescriptor({
    required this.contractVersion,
    required this.ownerId,
    required this.ownerScope,
    required this.sourceIdentity,
    required this.idempotencyKey,
    required this.payloadFingerprint,
    required this.objectSha256,
    required this.objectBytes,
  });

  final int contractVersion;
  final String ownerId;
  final String ownerScope;
  final String sourceIdentity;
  final String idempotencyKey;
  final String payloadFingerprint;
  final String objectSha256;
  final int objectBytes;
}

class OwnerSyncStagingIntent {
  const OwnerSyncStagingIntent({
    required this.id,
    required this.state,
    this.receipt,
  });

  final String id;
  final OwnerSyncStagingState state;
  final OwnerSyncReceipt? receipt;
}

/// Maps to authenticated begin-upload, private Storage upload, and
/// server-side finalization. It deliberately does not expose service-role
/// credentials or allow clients to write public manifests/change feeds.
abstract interface class OwnerSyncStagedUploadAdapter {
  Future<OwnerSyncStagingIntent> beginUpload(
    OwnerSyncUploadDescriptor descriptor,
  );

  Future<void> uploadPrivateObject({
    required String intentId,
    required List<int> envelopeBytes,
  });

  Future<OwnerSyncReceipt> finalizeUpload(String intentId);
}

class OwnerSyncTransportFailure implements Exception {
  const OwnerSyncTransportFailure(this.code);
  final String code;
}

class OwnerSyncConflict implements Exception {
  const OwnerSyncConflict(this.code);
  final String code;
}

/// The private staging path already contains an immutable object. The client
/// must not overwrite it; it may ask the server finalizer to verify the bytes.
class OwnerSyncStagedObjectAlreadyExists implements Exception {
  const OwnerSyncStagedObjectAlreadyExists();
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
    this.hasMore = false,
  });
  final String ownerId;
  final String fromCursor;
  final String nextCursor;
  final List<OwnerSyncRemoteChange> changes;
  final bool hasMore;
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

/// Authenticated staged transport used by the normal owner composition.
/// Readiness is verified before any local outbox data leaves the device.
abstract interface class OwnerSyncAccountRemoteAdapter
    implements OwnerSyncStagedUploadAdapter, OwnerSyncDownloadAdapter {
  Future<void> verifyBackend();
}

/// M2 is a separate capability: an M1 transport is never treated as a deleter.
abstract interface class OwnerSyncDeletionAdapter {
  Future<({int sequence, String fingerprint})> observeDrive(String source);
  Future<OwnerSyncMutation> deleteDrive(OwnerSyncMutation mutation);
}

/// Optional M2 extension; a 404 alone is never a cancellation receipt.
abstract interface class OwnerSyncStagingCancellationAdapter {
  Future<({String intentId, String fingerprint})> observeStagingDrive(
    String source,
  );
}

class OwnerSyncDownloadResult {
  const OwnerSyncDownloadResult({
    required this.applied,
    required this.duplicates,
    required this.cursor,
    this.hasMore = false,
  });
  final int applied;
  final int duplicates;
  final String cursor;
  final bool hasMore;
}

/// Durable queue for only new, proven, account-owned drives. Construction is
/// explicit and there is no production network adapter or automatic worker.
class OwnerDriveSyncClient {
  OwnerDriveSyncClient({required this.store, required this.requireCurrent});

  static const boxName = 'owner_sync_outbox_v1';
  static const downloadStateBox = 'owner_sync_download_v1';
  static const receivedBox = 'owner_sync_received_v1';
  static const driveIdMapBox = 'owner_sync_drive_id_map_v1';
  static const deletionBox = 'owner_sync_deletions_v2';
  static const contractVersion = 2;
  static const maxStagedEnvelopeBytes = 10 * 1024 * 1024;

  final OwnerScopedLocalStore store;
  final void Function() requireCurrent;
  GpsOwner get owner => store.owner;

  /// Local evidence that this particular source was acknowledged/downloaded.
  /// Queued or ambiguous uploads are deliberately not proof of cloud absence.
  bool hasCloudDrive(String driveId) {
    requireCurrent();
    if (owner.kind != GpsOwnerKind.account) return false;
    return store.keys(owner, boxName).any((key) {
          final row = store.read<Map>(owner, boxName, key);
          if (row?['mutation'] is! Map) return false;
          final m = OwnerSyncMutation.fromMap(row!['mutation'] as Map);
          return m.kind == OwnerSyncMutationKind.driveUpsert &&
              (row['state'] == OwnerSyncMutationState.acknowledged.name ||
                  (row['attemptCount'] as int? ?? 0) > 0) &&
              (m.payload['drive'] as Map?)?['id'] == driveId;
        }) ||
        store
            .keys(owner, driveIdMapBox)
            .any(
              (key) =>
                  store.read<Map>(owner, driveIdMapBox, key)?['localDriveId'] ==
                  driveId,
            );
  }

  Map? deletionStatus(String driveId) {
    requireCurrent();
    return store.read<Map>(owner, deletionBox, 'drive:$driveId');
  }

  /// Persist user consent BEFORE any network operation or local removal.
  /// Old M1 ACKs lack sequence evidence: refresh it, never invent it.
  Future<void> prepareCloudDeletion(String driveId) async {
    requireCurrent();
    _requireAccount();
    final existing = deletionStatus(driveId);
    if (existing != null) {
      final proof = store.read<Map>(
        owner,
        'drive_source_provenance_v1',
        driveId,
      );
      if (store.read(owner, 'drives', driveId) != null &&
          (proof?['status'] != 'proven' ||
              proof?['ownerScope'] != store.scope ||
              proof?['sourceIdentity'] != existing['sourceIdentity'])) {
        throw const OwnerSyncConflict('deletion_local_drive_id_reused');
      }
      await store.put(owner, deletionBox, 'drive:$driveId', existing);
      return;
    }
    final bundle = _tryVerifiedLocalBundle(driveId);
    if (!hasCloudDrive(driveId) || bundle?.sourceProvenance?.isProven != true) {
      throw const OwnerSyncConflict('deletion_source_unproven');
    }
    final identity = bundle!.sourceProvenance!.sourceIdentity!;
    String? expectedHash;
    for (final key in store.keys(owner, boxName)) {
      final m = store.read<Map>(owner, boxName, key)?['mutation'];
      if (m is Map &&
          m['kind'] == 'driveUpsert' &&
          m['sourceIdentity'] == identity) {
        expectedHash = m['payloadFingerprint'] as String?;
      }
    }
    expectedHash ??=
        store.read<Map>(owner, driveIdMapBox, identity)?['payloadFingerprint']
            as String?;
    if (expectedHash == null) {
      throw const OwnerSyncConflict('deletion_revision_unavailable');
    }
    await store.put(owner, deletionBox, 'drive:$driveId', {
      'ownerId': owner.userId,
      'ownerScope': store.scope,
      'sourceIdentity': identity,
      'expectedPayloadFingerprint': expectedHash,
      'deletionId': DriveSourceProvenance.newUuidV4(),
      'deletedAt': DateTime.now().toUtc().toIso8601String(),
      'state': 'queued',
      'attemptCount': 0,
    });
    requireCurrent();
  }

  Future<OwnerSyncMutation> _buildDeletionMutation(
    Map row,
    OwnerSyncDeletionAdapter remote, {
    bool finalizedOnly = false,
  }) async {
    Map<String, Object?> evidence;
    try {
      final observed = await remote.observeDrive(
        row['sourceIdentity'] as String,
      );
      requireCurrent();
      if (observed.sequence < 1 ||
          observed.fingerprint != row['expectedPayloadFingerprint']) {
        throw const OwnerSyncConflict('deletion_observation_invalid');
      }
      evidence = {
        'causalVersion': 1,
        'observedRemoteSequence': observed.sequence,
        'observedPayloadFingerprint': observed.fingerprint,
      };
    } on OwnerSyncConflict catch (error) {
      if (finalizedOnly ||
          error.code != 'source_unavailable' ||
          remote is! OwnerSyncStagingCancellationAdapter) {
        rethrow;
      }
      try {
        final staged = await (remote as OwnerSyncStagingCancellationAdapter)
            .observeStagingDrive(row['sourceIdentity'] as String);
        requireCurrent();
        if (!_isUuid(staged.intentId) ||
            staged.fingerprint != row['expectedPayloadFingerprint']) {
          throw const OwnerSyncConflict('cancellation_observation_invalid');
        }
        evidence = {
          'causalVersion': 2,
          'intentId': staged.intentId,
          'cancelledPayloadFingerprint': staged.fingerprint,
        };
      } on OwnerSyncConflict catch (race) {
        if (race.code != 'source_already_finalized') rethrow;
        return _buildDeletionMutation(row, remote, finalizedOnly: true);
      }
    }
    requireCurrent();
    final m = _mutation(
      kind: OwnerSyncMutationKind.driveTombstone,
      accountId: owner.userId!,
      sourceIdentity: row['sourceIdentity'] as String,
      payload: {
        'deletionId': row['deletionId'],
        'deletedAt': row['deletedAt'],
        ...evidence,
      },
    );
    return OwnerSyncMutation(
      version: m.version,
      kind: m.kind,
      ownerScope: m.ownerScope,
      ownerId: m.ownerId,
      sourceIdentity: m.sourceIdentity,
      payload: m.payload,
      payloadFingerprint: m.payloadFingerprint,
      idempotencyKey: _idempotencyKey(
        owner.userId!,
        m.kind,
        row['deletionId'] as String,
      ),
    );
  }

  /// One bounded attempt. A response loss retains exactly the same operation.
  /// Data stays locally available/pending until a validated server ACK arrives.
  Future<bool> sendCloudDeletion(
    String driveId,
    OwnerSyncDeletionAdapter remote,
  ) async {
    requireCurrent();
    _requireAccount();
    var row = deletionStatus(driveId);
    if (row == null ||
        row['ownerId'] != owner.userId ||
        row['ownerScope'] != store.scope ||
        !store.writeDurable(deletionBox, 'drive:$driveId')) {
      throw const OwnerSyncConflict('deletion_not_durable');
    }
    if (row['state'] == 'acknowledged') {
      return true;
    }
    await store.put(owner, deletionBox, 'drive:$driveId', {
      ...row,
      'attemptCount': (row['attemptCount'] as int) + 1,
    });
    try {
      OwnerSyncMutation mutation;
      if (row['mutation'] is Map) {
        mutation = OwnerSyncMutation.fromMap(row['mutation'] as Map);
      } else {
        mutation = await _buildDeletionMutation(row, remote);
        await store.put(owner, deletionBox, 'drive:$driveId', {
          ...deletionStatus(driveId)!,
          'mutation': mutation.toMap(),
        });
      }
      _validateMutationOwner(mutation);
      OwnerSyncMutation ack;
      try {
        ack = await remote.deleteDrive(mutation);
      } on OwnerSyncConflict catch (race) {
        if (mutation.payload['causalVersion'] != 2 ||
            race.code != 'source_already_finalized') {
          rethrow;
        }
        // Finalization won the source lock. No cancellation was accepted;
        // use real manifest evidence with the SAME consent UUID/time, once.
        mutation = await _buildDeletionMutation(
          row,
          remote,
          finalizedOnly: true,
        );
        await store.put(owner, deletionBox, 'drive:$driveId', {
          ...deletionStatus(driveId)!,
          'mutation': mutation.toMap(),
        });
        ack = await remote.deleteDrive(mutation);
      }
      requireCurrent();
      if (canonicalOwnerSyncSha256(ack.toMap()) !=
          canonicalOwnerSyncSha256(mutation.toMap())) {
        throw const OwnerSyncConflict('deletion_ack_mismatch');
      }
      await _applyRemoteDeletion(ack);
      requireCurrent();
      await store.put(owner, deletionBox, 'drive:$driveId', {
        ...deletionStatus(driveId)!,
        'state': 'acknowledged',
      });
      return true;
    } on OwnerSyncTransportFailure catch (e) {
      requireCurrent();
      await store.put(owner, deletionBox, 'drive:$driveId', {
        ...deletionStatus(driveId)!,
        'state': 'retryableFailure',
        'error': e.code,
      });
      return false;
    } on OwnerSyncConflict catch (e) {
      requireCurrent();
      await store.put(owner, deletionBox, 'drive:$driveId', {
        ...deletionStatus(driveId)!,
        'state': 'conflict',
        'error': e.code,
      });
      rethrow;
    }
  }

  Future<bool> _applyRemoteDeletion(OwnerSyncMutation mutation) async {
    _validateMutationOwner(mutation);
    final source = mutation.sourceIdentity;
    final previous = store.read<Map>(owner, deletionBox, 'source:$source');
    if (previous != null &&
        previous['mutation'] is Map &&
        canonicalOwnerSyncSha256(previous['mutation']) !=
            canonicalOwnerSyncSha256(mutation.toMap())) {
      throw const OwnerSyncConflict('remote_deletion_conflict');
    }
    // Durable source barrier first: a crash cannot permit an old page/upload.
    await store.put(owner, deletionBox, 'source:$source', {
      'mutation': mutation.toMap(),
    });
    requireCurrent();
    final ids = <String>{};
    final map = store.read<Map>(owner, driveIdMapBox, source);
    if (map?['localDriveId'] is String) ids.add(map!['localDriveId'] as String);
    for (final id in store.keys(owner, 'drives').whereType<String>()) {
      final proof = store.read<Map>(owner, 'drive_source_provenance_v1', id);
      if (proof?['sourceIdentity'] == source ||
          store
                  .repositories(owner)
                  .source(id)
                  ?.sourceProvenance
                  ?.sourceIdentity ==
              source) {
        ids.add(id);
      }
    }
    for (final id in ids) {
      requireCurrent();
      final importing = store.read<Map>(
        owner,
        'owned_drive_finalization_v1',
        id,
      );
      final proof = store.read<Map>(owner, 'drive_source_provenance_v1', id);
      final matchingImport =
          importing?['state'] == 'sync_importing' &&
          importing?['syncImport'] == true &&
          importing?['sourceIdentity'] == source;
      if (store.read(owner, 'drives', id) != null &&
          !matchingImport &&
          (proof?['status'] != 'proven' ||
              proof?['ownerScope'] != store.scope ||
              proof?['sourceIdentity'] != source)) {
        throw const OwnerSyncConflict('deletion_local_identity_conflict');
      }
      // M1 replica imports intentionally have no M3 World/Career projection.
      // An authenticated remote tombstone may remove that History copy without
      // manufacturing a Career contribution. Never bypass active World proof.
      final unprojectedImport =
          importing?['syncImport'] == true &&
          importing?['sourceIdentity'] == source &&
          (await store.worldIndex(owner).getActiveTracesForDrive(id)).isEmpty;
      requireCurrent();
      if (matchingImport || unprojectedImport) {
        await store.put(owner, 'local_lifecycle_v1', 'history:$id', {
          'version': 1,
          'state': 'prepared',
          'remoteTombstone': mutation.idempotencyKey,
        });
      }
      await store.repositories(owner).deleteHistory(id);
    }
    return previous == null;
  }

  void _assertNotDeleted(OwnerSyncMutation mutation) {
    final mapping = store.read<Map>(
      owner,
      driveIdMapBox,
      mutation.sourceIdentity,
    );
    final driveId =
        mapping?['localDriveId'] ?? (mutation.payload['drive'] as Map?)?['id'];
    if ((driveId is String &&
            store.read(owner, 'local_lifecycle_v1', 'history:$driveId') !=
                null) ||
        store.read(owner, deletionBox, 'source:${mutation.sourceIdentity}') !=
            null ||
        store
            .keys(owner, deletionBox)
            .any(
              (key) =>
                  !key.toString().startsWith('source:') &&
                  store.read<Map>(owner, deletionBox, key)?['sourceIdentity'] ==
                      mutation.sourceIdentity,
            )) {
      throw const OwnerSyncConflict('source_deleted_or_pending');
    }
  }

  /// Read-only candidates: never scans legacy/Guest or enqueues a batch.
  List<({DriveSession drive, String? key, String state})> manualCandidates() {
    requireCurrent();
    _requireAccount();
    final result = <({DriveSession drive, String? key, String state})>[];
    for (final id
        in store
            .keys(owner, 'owned_drive_finalization_v1')
            .whereType<String>()) {
      final completed = store.read<Map>(
        owner,
        'owned_drive_finalization_v1',
        id,
      );
      if (completed?['state'] != 'completed' ||
          completed?['derivedReady'] != true ||
          completed?['syncImport'] == true ||
          !store.writeDurable('owned_drive_finalization_v1', id) ||
          !store.writeDurable('drives', id) ||
          !store.writeDurable('drive_telemetry', id) ||
          !store.writeDurable('drive_source_provenance_v1', id) ||
          store.read<Map>(owner, 'local_lifecycle_v1', 'history:$id') != null) {
        continue;
      }
      final source = _tryVerifiedLocalBundle(id);
      if (source?.sourceProvenance?.isProven != true ||
          source!.sourceProvenance!.ownerScope != store.scope) {
        continue;
      }
      final score = source.score;
      if (score != null &&
          !store.writeDurable(
            'drive_scores',
            DriveScoreStorageService.keyFor(id, score.algorithmVersion),
          )) {
        continue;
      }
      String? key;
      var state = 'pending';
      for (final candidate in store.keys(owner, boxName).whereType<String>()) {
        final row = readRecord(candidate);
        if (row?['mutation'] is! Map) continue;
        final mutation = OwnerSyncMutation.fromMap(
          Map.from(row!['mutation'] as Map),
        );
        _validateMutationOwner(mutation);
        if (mutation.sourceIdentity ==
            source.sourceProvenance!.sourceIdentity) {
          key = candidate;
          state = row['state'] as String;
          break;
        }
      }
      if (source.telemetry!.points.isEmpty) state = 'ineligibleTelemetry';
      if (deletionStatus(id) != null) state = 'deletionPending';
      result.add((drive: source.drive, key: key, state: state));
    }
    result.sort((a, b) => b.drive.date.compareTo(a.drive.date));
    return result;
  }

  Future<String> enqueueDrive(
    String driveId, {
    bool automaticSyncEligible = false,
  }) async {
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
    final source = _verifiedLocalBundle(driveId);
    if (source.telemetry!.points.isEmpty) {
      throw const OwnerSyncConflict('upload_telemetry_empty');
    }
    final provenance = source.sourceProvenance;
    if (provenance?.isProven != true || provenance!.ownerScope != store.scope) {
      throw StateError('Only proven owner drive sources can be queued');
    }
    // World map-matching roads are a mutable derived projection. They have
    // their own lifecycle and must not mutate the immutable drive upsert (or
    // change its fingerprint after a server ACK). Route/telemetry remain the
    // canonical inputs from which this device can derive its own World state.
    final payload = source.toMap()..['roads'] = <dynamic>[];
    // A downloaded replica may use a device-local Hive ID which differs from
    // the immutable ID in its received envelope. Re-uploads restore the
    // original wire ID so the same source identity produces the same bytes,
    // fingerprint, and idempotency result on every device.
    final mapping = store.read<Map>(
      owner,
      driveIdMapBox,
      provenance.sourceIdentity!,
    );
    if (mapping != null) {
      if (mapping['ownerId'] != accountId ||
          mapping['ownerScope'] != store.scope ||
          mapping['sourceIdentity'] != provenance.sourceIdentity ||
          mapping['localDriveId'] != driveId ||
          mapping['remoteDriveId'] is! String ||
          mapping['payloadFingerprint'] is! String) {
        throw const OwnerSyncConflict('local_drive_id_mapping_conflict');
      }
      _remapBundleIds(payload, mapping['remoteDriveId'] as String);
    }
    final key = _idempotencyKey(
      accountId,
      OwnerSyncMutationKind.driveUpsert,
      provenance.sourceIdentity!,
    );
    final mutation = _mutation(
      kind: OwnerSyncMutationKind.driveUpsert,
      accountId: accountId,
      sourceIdentity: provenance.sourceIdentity!,
      payload: payload,
    );
    // A previously persisted v1 outbox row is the same logical operation even
    // though the v2 canonical encoding has a different fingerprint/key. Reuse
    // it when its full payload is equal; never enqueue a second cloud write on
    // app upgrade. Contradictory evidence is a durable conflict, not a reason
    // to guess which row should win.
    for (final existingKey in store.keys(owner, boxName).whereType<String>()) {
      final existingRow = store.read<Map>(owner, boxName, existingKey);
      if (existingRow == null || existingRow['mutation'] is! Map) continue;
      final existing = OwnerSyncMutation.fromMap(
        Map.from(existingRow['mutation'] as Map),
      );
      if (existing.kind != OwnerSyncMutationKind.driveUpsert ||
          existing.sourceIdentity != mutation.sourceIdentity) {
        continue;
      }
      if (existing.ownerScope != mutation.ownerScope ||
          existing.ownerId != mutation.ownerId ||
          canonicalOwnerSyncJson(existing.payload) !=
              canonicalOwnerSyncJson(mutation.payload)) {
        throw const OwnerSyncConflict('local_source_identity_conflict');
      }
      if (automaticSyncEligible &&
          existingRow['automaticSyncEligible'] != true) {
        await store.put(owner, boxName, existingKey, {
          ...existingRow,
          'automaticSyncEligible': true,
        });
        requireCurrent();
      }
      return existingKey;
    }
    return _stage(
      key: key,
      mutation: mutation,
      automaticSyncEligible: automaticSyncEligible,
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
    final ids = store
        .keys(owner, 'owned_drive_finalization_v1')
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
          finalized?['automaticSyncEligible'] != true ||
          store.read<Map>(owner, 'local_lifecycle_v1', 'history:$id') != null) {
        skipped++;
        continue;
      }
      final source = _tryVerifiedLocalBundle(id);
      final provenance = source?.sourceProvenance;
      if (source == null ||
          source.telemetry == null ||
          source.telemetry!.points.isEmpty ||
          provenance?.isProven != true ||
          provenance!.ownerScope != store.scope) {
        // Unknown, legacy, incomplete, or contradictory evidence is not
        // promoted into cloud work. A later verified record may be retried.
        skipped++;
        continue;
      }
      await enqueueDrive(id, automaticSyncEligible: true);
      queued++;
    }
    return OwnerSyncReconciliationResult(queued: queued, skipped: skipped);
  }

  LocalSourceBundle _verifiedLocalBundle(String driveId) {
    final result = _tryVerifiedLocalBundle(driveId);
    if (result == null) {
      throw StateError('Verified owner drive source is incomplete');
    }
    return result;
  }

  LocalSourceBundle? _tryVerifiedLocalBundle(String driveId) {
    final drive = store.read<DriveSession>(owner, 'drives', driveId);
    final telemetry = store.read<DriveTelemetryRecord>(
      owner,
      'drive_telemetry',
      driveId,
    );
    final rawProvenance = store.read<Map>(
      owner,
      'drive_source_provenance_v1',
      driveId,
    );
    if (drive == null || telemetry == null || rawProvenance == null) {
      return null;
    }
    final provenance = DriveSourceProvenance.fromMap(rawProvenance);
    final score = store.read<DriveScoreRecord>(
      owner,
      'drive_scores',
      DriveScoreStorageService.keyFor(
        driveId,
        DriveScoreRecord.currentAlgorithmVersion,
      ),
    );
    final result = LocalSourceBundle(
      drive: drive,
      telemetry: telemetry,
      score: score,
      ownerScope: store.scope,
      sourceProvenance: provenance,
    );
    result.validate();
    return result;
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
    bool automaticSyncEligible = false,
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
      if (automaticSyncEligible) 'automaticSyncEligible': true,
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

  /// Executes one Storage/Postgres-safe upload attempt. Storage and Postgres
  /// are not atomic together: the private object is staged first, and only a
  /// server-verified finalizer may publish the manifest/change event. Replays
  /// reuse the outbox mutation's idempotency key and canonical bytes.
  Future<bool> sendStaged(
    String key,
    OwnerSyncStagedUploadAdapter remote,
  ) async {
    requireCurrent();
    final accountId = _requireAccount();
    final row = store.read<Map>(owner, boxName, key);
    if (row == null) throw StateError('Owner sync mutation not found');
    final mutation = OwnerSyncMutation.fromMap(
      Map.from(row['mutation'] as Map),
    );
    _validateMutationOwner(mutation);
    if (mutation.kind != OwnerSyncMutationKind.driveUpsert) {
      throw const OwnerSyncConflict('staged_tombstone_not_supported');
    }
    _assertNotDeleted(mutation);
    if (row['state'] == OwnerSyncMutationState.acknowledged.name) return true;
    if (row['state'] == OwnerSyncMutationState.conflict.name) return false;
    final telemetry = mutation.payload['telemetry'];
    if (telemetry is Map &&
        telemetry['points'] is List &&
        (telemetry['points'] as List).isEmpty) {
      throw const OwnerSyncConflict('upload_telemetry_empty');
    }
    final envelope = _envelopeBytes(mutation);
    if (envelope.isEmpty || envelope.length > maxStagedEnvelopeBytes) {
      throw const OwnerSyncConflict('staged_payload_size_invalid');
    }
    final objectSha = sha256.convert(envelope).toString();
    final descriptor = OwnerSyncUploadDescriptor(
      contractVersion: mutation.version,
      ownerId: accountId,
      ownerScope: store.scope,
      sourceIdentity: mutation.sourceIdentity,
      idempotencyKey: mutation.idempotencyKey,
      payloadFingerprint: mutation.payloadFingerprint,
      objectSha256: objectSha,
      objectBytes: envelope.length,
    );
    final attemptCount = (row['attemptCount'] as int? ?? 0) + 1;
    await store.put(owner, boxName, key, {
      ...row,
      'state': OwnerSyncMutationState.sending.name,
      'attemptCount': attemptCount,
      'lastErrorCode': null,
      'stagedUpload': {
        'version': 1,
        'objectSha256': objectSha,
        'objectBytes': envelope.length,
      },
    });
    requireCurrent();

    try {
      final intent = await remote.beginUpload(descriptor);
      requireCurrent();
      _assertNotDeleted(mutation);
      if (intent.id.isEmpty) {
        throw const OwnerSyncConflict('staging_intent_invalid');
      }
      final progress = <String, Object?>{
        ...store.read<Map>(owner, boxName, key)!,
        'stagedUpload': {
          'version': 1,
          'intentId': intent.id,
          'objectSha256': objectSha,
          'objectBytes': envelope.length,
        },
      };
      if (intent.state == OwnerSyncStagingState.finalized) {
        final receipt = intent.receipt;
        if (receipt == null) {
          throw const OwnerSyncConflict('finalized_receipt_missing');
        }
        return await _persistStagedReceipt(key, progress, mutation, receipt);
      }
      await store.put(owner, boxName, key, progress);
      try {
        await remote.uploadPrivateObject(
          intentId: intent.id,
          envelopeBytes: envelope,
        );
      } on OwnerSyncStagedObjectAlreadyExists {
        // A crash can occur after Storage accepts the immutable object but
        // before the local progress marker is flushed. Never overwrite it;
        // the server finalizer verifies the existing object against the
        // durable SHA-256/size claims before it can publish anything.
      }
      requireCurrent();
      _assertNotDeleted(mutation);
      await store.put(owner, boxName, key, {
        ...store.read<Map>(owner, boxName, key)!,
        'stagedUpload': {
          'version': 1,
          'intentId': intent.id,
          'objectSha256': objectSha,
          'objectBytes': envelope.length,
          'objectUploaded': true,
        },
      });
      final receipt = await remote.finalizeUpload(intent.id);
      requireCurrent();
      return await _persistStagedReceipt(
        key,
        store.read<Map>(owner, boxName, key)!,
        mutation,
        receipt,
      );
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
  }

  List<int> _envelopeBytes(OwnerSyncMutation mutation) => mutation.version == 1
      ? utf8.encode(jsonEncode(mutation.toMap()))
      : canonicalOwnerSyncBytes(mutation.toMap());

  Future<bool> _persistStagedReceipt(
    String key,
    Map row,
    OwnerSyncMutation mutation,
    OwnerSyncReceipt receipt,
  ) async {
    requireCurrent();
    _assertNotDeleted(mutation);
    if (receipt.ownerScope != mutation.ownerScope ||
        receipt.idempotencyKey != mutation.idempotencyKey ||
        receipt.payloadFingerprint != mutation.payloadFingerprint ||
        receipt.remoteId.isEmpty) {
      throw const OwnerSyncConflict('remote_receipt_mismatch');
    }
    await store.put(owner, boxName, key, {
      ...row,
      'state': OwnerSyncMutationState.acknowledged.name,
      'lastErrorCode': null,
      'receipt': {
        'ownerScope': receipt.ownerScope,
        'idempotencyKey': receipt.idempotencyKey,
        'payloadFingerprint': receipt.payloadFingerprint,
        'remoteId': receipt.remoteId,
        if (receipt.changeSequence != null)
          'changeSequence': receipt.changeSequence,
      },
    });
    requireCurrent();
    final saved = store.read<Map>(owner, boxName, key);
    if (saved?['state'] != OwnerSyncMutationState.acknowledged.name ||
        (saved?['receipt'] as Map?)?['idempotencyKey'] !=
            mutation.idempotencyKey ||
        (saved?['receipt'] as Map?)?['payloadFingerprint'] !=
            mutation.payloadFingerprint) {
      throw StateError('Staged sync ACK read-back failed');
    }
    return true;
  }

  /// Applies one server page to this account's separate local replica. The
  /// cursor advances only after all rows are durable and read back. Importing
  /// rows stay hidden from History until the finalization marker is committed.
  /// Deletion changes and legacy/unproven rows fail closed.
  Future<OwnerSyncDownloadResult> downloadOnce(
    OwnerSyncDownloadAdapter remote, {
    int limit = 32,
  }) async => applyDownloadPage(
    await fetchDownloadPage(remote, limit: limit),
    limit: limit,
  );

  /// Fetch outside the owner write barrier; a slow network must not block Save.
  Future<OwnerSyncDownloadPage> fetchDownloadPage(
    OwnerSyncDownloadAdapter remote, {
    int limit = 32,
    bool restartCompletedSnapshot = false,
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
    final cursor = restartCompletedSnapshot && previous?['hasMore'] == false
        ? ''
        : previous?['cursor'] as String? ?? '';
    final page = await remote.download(
      ownerId: accountId,
      afterCursor: cursor,
      limit: limit,
    );
    requireCurrent();
    return page;
  }

  /// Apply a prefetched page under the owner's local write barrier. Recheck
  /// the durable cursor so stale pages cannot race another import or deletion.
  Future<OwnerSyncDownloadResult> applyDownloadPage(
    OwnerSyncDownloadPage page, {
    int limit = 32,
    bool preserveExistingDrives = false,
    bool restartCompletedSnapshot = false,
  }) async {
    requireCurrent();
    final accountId = _requireAccount();
    if (limit <= 0 || limit > 100) throw ArgumentError.value(limit, 'limit');
    const stateKey = 'drive_cursor_v1';
    final previous = store.read<Map>(owner, downloadStateBox, stateKey);
    if (previous != null &&
        (previous['ownerId'] != accountId ||
            previous['ownerScope'] != store.scope ||
            previous['version'] != 1 ||
            previous['cursor'] is! String)) {
      throw const OwnerSyncConflict('download_cursor_owner_conflict');
    }
    final cursor = restartCompletedSnapshot && previous?['hasMore'] == false
        ? ''
        : previous?['cursor'] as String? ?? '';
    if (page.ownerId != accountId ||
        page.fromCursor != cursor ||
        (page.nextCursor.isEmpty && page.changes.isNotEmpty) ||
        page.changes.length > limit) {
      throw const OwnerSyncConflict('download_page_scope_or_cursor_conflict');
    }
    if (page.hasMore && page.nextCursor == cursor) {
      throw const OwnerSyncConflict('download_page_made_no_progress');
    }
    // Validate the entire page before any local write. A cross-owner or
    // unsupported mutation therefore cannot partially affect this account.
    for (final change in page.changes) {
      if (change.cursor.isEmpty) {
        throw const OwnerSyncConflict('download_change_unsupported');
      }
      _validateMutationOwner(change.mutation);
    }
    var applied = 0;
    var duplicates = 0;
    for (final change in page.changes) {
      requireCurrent();
      final wasApplied =
          change.mutation.kind == OwnerSyncMutationKind.driveTombstone
          ? await _applyRemoteDeletion(change.mutation)
          : await _applyDownloadedDrive(
              change.mutation,
              preserveExistingDrives: preserveExistingDrives,
            );
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
      'hasMore': page.hasMore,
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
      hasMore: page.hasMore,
    );
  }

  Future<bool> _applyDownloadedDrive(
    OwnerSyncMutation mutation, {
    bool preserveExistingDrives = false,
  }) async {
    if (mutation.kind != OwnerSyncMutationKind.driveUpsert) {
      throw const OwnerSyncConflict('download_tombstone_not_supported');
    }
    if (store.read(owner, deletionBox, 'source:${mutation.sourceIdentity}') !=
        null) {
      return false;
    }
    final wireBundle = LocalSourceBundle.fromMap(mutation.payload);
    wireBundle.validate();
    final provenance = wireBundle.sourceProvenance;
    if (wireBundle.ownerScope != store.scope ||
        provenance?.isProven != true ||
        provenance!.ownerScope != store.scope ||
        provenance.sourceIdentity != mutation.sourceIdentity ||
        !_isUuid(mutation.sourceIdentity)) {
      throw const OwnerSyncConflict('download_provenance_invalid');
    }
    // Roads are device-derived World projections and intentionally are not
    // transferred. Reject a non-empty remote projection rather than silently
    // remapping or importing stale road ownership.
    if (wireBundle.roads.isNotEmpty) {
      throw const OwnerSyncConflict('download_derived_roads_unsupported');
    }
    final driveId = await _resolveDownloadedLocalDriveId(mutation, wireBundle);
    final localPayload = wireBundle.toMap();
    _remapBundleIds(localPayload, driveId);
    final bundle = LocalSourceBundle.fromMap(localPayload);
    bundle.validate();
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
    final historyTombstone = store.read<Map>(
      owner,
      'local_lifecycle_v1',
      'history:$driveId',
    );
    if (historyTombstone != null) {
      final mapping = store.read<Map>(
        owner,
        driveIdMapBox,
        mutation.sourceIdentity,
      );
      if (historyTombstone['state'] != 'completed' ||
          mapping?['ownerId'] != owner.userId ||
          mapping?['ownerScope'] != store.scope ||
          mapping?['sourceIdentity'] != mutation.sourceIdentity ||
          mapping?['localDriveId'] != driveId ||
          mapping?['payloadFingerprint'] != mutation.payloadFingerprint) {
        throw const OwnerSyncConflict('download_local_tombstone_conflict');
      }
      // Remote deletion sync is deliberately disabled. Preserve this device's
      // explicit History deletion instead of resurrecting the row on replay;
      // the durable cursor may advance, but no remote tombstone is invented.
      await store.put(owner, receivedBox, receivedKey, {
        'version': 1,
        'state': 'locally_suppressed',
        'ownerId': owner.userId,
        'ownerScope': store.scope,
        'sourceIdentity': mutation.sourceIdentity,
        'driveId': driveId,
        'payloadFingerprint': mutation.payloadFingerprint,
      });
      final suppressed = store.read<Map>(owner, receivedBox, receivedKey);
      if (suppressed?['state'] != 'locally_suppressed' ||
          suppressed?['sourceIdentity'] != mutation.sourceIdentity ||
          suppressed?['payloadFingerprint'] != mutation.payloadFingerprint) {
        throw StateError('Local deletion suppression read-back failed');
      }
      return false;
    }
    if (receipt?['state'] == 'completed') {
      _verifyDownloadedDrive(bundle, mutation);
      return false;
    }

    if (preserveExistingDrives &&
        store.read<DriveSession>(owner, 'drives', driveId) != null &&
        store.read<Map>(
              owner,
              'owned_drive_finalization_v1',
              driveId,
            )?['state'] !=
            'sync_importing') {
      // First manual acceptance must not re-put an existing drive, score or
      // telemetry. Only an exact canonical match may advance the cursor.
      final local = _verifiedLocalBundle(driveId).toMap()
        ..['roads'] = <dynamic>[];
      _remapBundleIds(local, wireBundle.drive.id);
      if (canonicalOwnerSyncSha256(local) != mutation.payloadFingerprint) {
        throw const OwnerSyncConflict('download_existing_drive_preserved');
      }
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

  Future<String> _resolveDownloadedLocalDriveId(
    OwnerSyncMutation mutation,
    LocalSourceBundle wireBundle,
  ) async {
    final identity = mutation.sourceIdentity;
    final remoteId = wireBundle.drive.id;
    final prior = store.read<Map>(owner, driveIdMapBox, identity);
    String localId;
    if (prior != null) {
      if (prior['version'] != 1 ||
          prior['ownerId'] != owner.userId ||
          prior['ownerScope'] != store.scope ||
          prior['sourceIdentity'] != identity ||
          prior['remoteDriveId'] != remoteId ||
          prior['payloadFingerprint'] != mutation.payloadFingerprint ||
          prior['localDriveId'] is! String ||
          (prior['localDriveId'] as String).isEmpty) {
        throw const OwnerSyncConflict('download_drive_id_mapping_conflict');
      }
      localId = prior['localDriveId'] as String;
    } else {
      // Reuse a matching proven local record if present. Preserve the remote
      // drive ID when it is free; allocate a deterministic local namespace
      // only when that ID is already occupied by unrelated local data.
      final provenMatches = <String>[];
      for (final key in store.keys(owner, 'drives').whereType<String>()) {
        final evidence = store.read<Map>(
          owner,
          'drive_source_provenance_v1',
          key,
        );
        if (evidence == null || evidence['sourceIdentity'] != identity) {
          continue;
        }
        if (evidence['status'] != 'proven' ||
            evidence['ownerScope'] != store.scope) {
          throw const OwnerSyncConflict(
            'download_existing_provenance_conflict',
          );
        }
        provenMatches.add(key);
      }
      if (provenMatches.length > 1) {
        throw const OwnerSyncConflict(
          'download_duplicate_local_source_identity',
        );
      }
      if (provenMatches.isNotEmpty) {
        localId = provenMatches.single;
      } else {
        final remoteIdOccupied =
            store.read<DriveSession>(owner, 'drives', remoteId) != null;
        localId = remoteIdOccupied ? 'sync_$identity' : remoteId;
      }
      final mapping = {
        'version': 1,
        'ownerId': owner.userId,
        'ownerScope': store.scope,
        'sourceIdentity': identity,
        'remoteDriveId': remoteId,
        'localDriveId': localId,
        'payloadFingerprint': mutation.payloadFingerprint,
      };
      await store.put(owner, driveIdMapBox, identity, mapping);
      final readBack = store.read<Map>(owner, driveIdMapBox, identity);
      if (jsonEncode(readBack) != jsonEncode(mapping)) {
        throw StateError(
          'Downloaded source-to-local ID mapping read-back failed',
        );
      }
    }
    final occupied = store.read<DriveSession>(owner, 'drives', localId);
    if (occupied != null) {
      final evidence = store.read<Map>(
        owner,
        'drive_source_provenance_v1',
        localId,
      );
      final pending = store.read<Map>(
        owner,
        'owned_drive_finalization_v1',
        localId,
      );
      final matchingPartialImport =
          pending?['state'] == 'sync_importing' &&
          pending?['syncImport'] == true &&
          pending?['sourceIdentity'] == identity &&
          pending?['payloadFingerprint'] == mutation.payloadFingerprint;
      if ((evidence?['status'] != 'proven' ||
              evidence?['sourceIdentity'] != identity) &&
          !matchingPartialImport) {
        throw const OwnerSyncConflict('download_local_drive_id_collision');
      }
    }
    return localId;
  }

  static void _remapBundleIds(Map<String, dynamic> payload, String driveId) {
    final drive = payload['drive'];
    final telemetry = payload['telemetry'];
    final score = payload['score'];
    if (drive is! Map || telemetry is! Map || telemetry['driveId'] is! String) {
      throw const OwnerSyncConflict('download_bundle_id_reference_invalid');
    }
    drive['id'] = driveId;
    telemetry['driveId'] = driveId;
    if (score != null) {
      if (score is! Map || score['driveId'] is! String) {
        throw const OwnerSyncConflict('download_score_id_reference_invalid');
      }
      score['driveId'] = driveId;
    }
    final roads = payload['roads'];
    if (roads is! List || roads.isNotEmpty) {
      throw const OwnerSyncConflict('download_derived_roads_unsupported');
    }
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
          jsonEncode(
            right.points.map(GpsSessionTransfer.pointContent).toList(),
          );

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

  /// Automatic worker is deliberately limited to newly finalized account
  /// drives explicitly marked at save time. Historical/manual queue rows do
  /// not become upload consent merely because the app resumed.
  List<String> automaticPendingKeys() => pendingKeys()
      .where(
        (key) =>
            store.read<Map>(owner, boxName, key)?['automaticSyncEligible'] ==
            true,
      )
      .toList(growable: false);

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
    final fingerprint = canonicalOwnerSyncSha256(payload);
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
    String identity, {
    int version = contractVersion,
  }) =>
      'owner-sync-v$version:${sha256.convert(utf8.encode('${store.scope}|$accountId|${kind.name}|$identity'))}';

  void _validateMutationOwner(OwnerSyncMutation mutation) {
    final canonicalFingerprint = mutation.version == 1
        ? sha256.convert(utf8.encode(jsonEncode(mutation.payload))).toString()
        : canonicalOwnerSyncSha256(mutation.payload);
    if ((mutation.version != 1 && mutation.version != contractVersion) ||
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
              version: mutation.version,
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
      if (mutation.payload['causalVersion'] == 2) {
        if (!_isUuid(mutation.payload['deletionId'] as String) ||
            mutation.payload['intentId'] is! String ||
            !_isUuid(mutation.payload['intentId'] as String) ||
            mutation.payload.containsKey('observedRemoteSequence') ||
            mutation.payload['cancelledPayloadFingerprint'] is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(
              mutation.payload['cancelledPayloadFingerprint'] as String,
            )) {
          throw const OwnerSyncConflict('cancellation_evidence_missing');
        }
        return;
      }
      if (!_isUuid(mutation.payload['deletionId'] as String) ||
          mutation.payload['observedRemoteSequence'] is! int ||
          (mutation.payload['observedRemoteSequence'] as int) < 1 ||
          mutation.payload['causalVersion'] != 1 ||
          mutation.payload['observedPayloadFingerprint'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(
            mutation.payload['observedPayloadFingerprint'] as String,
          )) {
        throw const OwnerSyncConflict('tombstone_causal_evidence_missing');
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
  OwnerDriveSyncWorker({required this.client, this.remote});

  final OwnerDriveSyncClient client;
  final OwnerSyncRemoteAdapter? remote;

  /// Processes a snapshot of at most [limit] pending keys once. A retry is a
  /// later explicit invocation, never an immediate loop on failure.
  Future<OwnerSyncWorkerResult> runOnce({int limit = 16}) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final transport = remote;
    if (transport == null) throw StateError('Legacy sync transport missing');
    final keys = client.pendingKeys().take(limit).toList(growable: false);
    var acknowledged = 0;
    var notAcknowledged = 0;
    for (final key in keys) {
      final ok = await client.send(key, transport);
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

  /// One bounded pass using the staged-object protocol. This remains an
  /// explicitly injected adapter; production composition still supplies no
  /// remote and no timer/background polling is created.
  Future<OwnerSyncWorkerResult> runStagedOnce(
    OwnerSyncStagedUploadAdapter remote, {
    int limit = 16,
    bool automaticOnly = false,
  }) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final keys =
        (automaticOnly ? client.automaticPendingKeys() : client.pendingKeys())
            .take(limit)
            .toList(growable: false);
    var acknowledged = 0;
    var notAcknowledged = 0;
    for (final key in keys) {
      final ok = await client.sendStaged(key, remote);
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
