import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_drive_sync_client.dart';
import 'owner_sync_causality.dart';

/// Real Supabase transport for the Phase 8 M1 staged-drive contract.
///
/// This adapter is intentionally opt-in. The normal factory supplies it only
/// in an explicitly cloud-enabled build after backend acceptance. Every operation checks the
/// currently authenticated Supabase UID against the immutable owner captured
/// by the caller before making a request.
class SupabaseOwnerDriveSyncAdapter
    implements
        OwnerSyncAccountRemoteAdapter,
        OwnerSyncDeletionAdapter,
        OwnerSyncStagingCancellationAdapter,
        OwnerDriveLeaseTransport {
  SupabaseOwnerDriveSyncAdapter({
    required SupabaseClient client,
    required String ownerId,
    required this.requireCurrent,
    this.requestTimeout = const Duration(seconds: 30),
    this.deletionEnabled = false,
    String? Function()? authenticatedUserId,
  }) : _client = client,
       _ownerId = ownerId.toLowerCase(),
       _authenticatedUserId =
           authenticatedUserId ?? (() => client.auth.currentUser?.id) {
    if (!_uuidV4.hasMatch(_ownerId) || ownerId != _ownerId) {
      throw ArgumentError.value(
        ownerId,
        'ownerId',
        'Expected lowercase UUID v4',
      );
    }
  }

  static const bucket = 'phase8-drive-staging';
  static const _maxObjectBytes = 10 * 1024 * 1024;
  static final _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');
  static final _safeErrorCode = RegExp(r'^[a-z0-9_]{1,80}$');

  final SupabaseClient _client;
  final String _ownerId;
  final void Function() requireCurrent;
  final Duration requestTimeout;

  /// Remains OFF in the normal factory until real M2 server acceptance.
  final bool deletionEnabled;
  final Map<String, OwnerDriveLeaseEvidence> _leases = {};
  final Map<String, String> _intentSources = {};
  final String? Function() _authenticatedUserId;

  String get _ownerScope =>
      jsonEncode(['local_account_store_v1', 'account', _ownerId]);

  void _assertOwner() {
    requireCurrent();
    if (_authenticatedUserId()?.toLowerCase() != _ownerId) {
      throw const OwnerSyncConflict('authenticated_owner_mismatch');
    }
    requireCurrent();
  }

  @override
  Future<void> verifyBackend() async {
    final data = await _invokeJson('phase8-drive-begin', {
      'action': 'capabilities',
    });
    _assertOwner();
    if (data['ok'] != true ||
        data['contractVersion'] != 2 ||
        !['202610150001', '202610160001'].contains(data['schemaRevision']) ||
        data['ownerScope'] != _ownerScope ||
        data['driveUpload'] != true ||
        data['driveDownload'] != true ||
        (data['deleteSync'] != false && data['deleteSync'] != true)) {
      throw const OwnerSyncConflict('backend_contract_not_ready');
    }
  }

  Future<void> _requireM2() async {
    _assertOwner();
    if (!deletionEnabled) throw const OwnerSyncConflict('m2_not_activated');
    final data = await _invokeJson('phase8-drive-begin', {
      'action': 'capabilities',
      'milestone': 2,
    });
    if (data['ok'] != true ||
        data['schemaRevision'] != '202610160001' ||
        data['ownerScope'] != _ownerScope ||
        data['deleteSync'] != true ||
        data['leaseFencing'] != true) {
      throw const OwnerSyncConflict('m2_backend_not_ready');
    }
  }

  @override
  Future<({int sequence, String fingerprint})> observeDrive(
    String source,
  ) async {
    await _requireM2();
    if (!_uuidV4.hasMatch(source)) {
      throw const OwnerSyncConflict('source_invalid');
    }
    final data = await _invokeJson('phase8-drive-delete', {
      'action': 'observe',
      'sourceIdentity': source,
    });
    final seq = _integer(data['change_sequence']);
    final hash = data['payload_fingerprint'];
    if (data['ok'] != true ||
        data['ownerId'] != _ownerId ||
        data['source_identity'] != source ||
        seq == null ||
        seq < 1 ||
        hash is! String ||
        !_sha256.hasMatch(hash)) {
      throw const OwnerSyncConflict('observation_invalid');
    }
    return (sequence: seq, fingerprint: hash);
  }

  @override
  Future<OwnerSyncMutation> deleteDrive(OwnerSyncMutation mutation) async {
    await _requireM2();
    if (mutation.ownerId != _ownerId ||
        mutation.ownerScope != _ownerScope ||
        mutation.kind != OwnerSyncMutationKind.driveTombstone) {
      throw const OwnerSyncConflict('deletion_owner_invalid');
    }
    final data = await _invokeJson('phase8-drive-delete', {
      if (mutation.payload['causalVersion'] == 2) 'action': 'cancelStaging',
      'mutation': mutation.toMap(),
    });
    if (data['ok'] != true ||
        data['mutation'] is! Map ||
        (_integer(data['sequence']) ?? 0) < 1) {
      throw const OwnerSyncConflict('deletion_ack_invalid');
    }
    return OwnerSyncMutation.fromMap(data['mutation'] as Map);
  }

  @override
  Future<({String intentId, String fingerprint})> observeStagingDrive(
    String source,
  ) async {
    await _requireM2();
    if (!_uuidV4.hasMatch(source)) {
      throw const OwnerSyncConflict('source_invalid');
    }
    final data = await _invokeJson('phase8-drive-delete', {
      'action': 'observeStaging',
      'sourceIdentity': source,
    });
    if (data['ok'] != true ||
        data['ownerId'] != _ownerId ||
        data['sourceIdentity'] != source ||
        data['intentId'] is! String ||
        !_uuidV4.hasMatch(data['intentId'] as String) ||
        data['payloadFingerprint'] is! String ||
        !_sha256.hasMatch(data['payloadFingerprint'] as String)) {
      throw const OwnerSyncConflict('cancellation_observation_invalid');
    }
    return (
      intentId: data['intentId'] as String,
      fingerprint: data['payloadFingerprint'] as String,
    );
  }

  @override
  Future<OwnerDriveLeaseEvidence> updateLease({
    required String sourceIdentity,
    required String deviceId,
    required String sessionId,
    int? fencingToken,
  }) async {
    await _requireM2();
    final data = await _invokeJson('phase8-drive-lease', {
      'action': fencingToken == null ? 'acquire' : 'heartbeat',
      'sourceIdentity': sourceIdentity,
      'deviceId': deviceId,
      'sessionId': sessionId,
      'fencingToken': ?fencingToken,
    });
    final l = data['lease'];
    if (data['ok'] != true ||
        l is! Map ||
        l['owner_id'] != _ownerId ||
        l['device_id'] != deviceId ||
        l['session_id'] != sessionId ||
        l['source_identity'] != sourceIdentity) {
      throw const OwnerSyncConflict('lease_response_invalid');
    }
    final evidence = OwnerDriveLeaseEvidence(
      ownerId: _ownerId,
      deviceId: deviceId,
      sessionId: sessionId,
      sourceIdentity: sourceIdentity,
      fencingToken: l['fencing_token'] as int,
      heartbeatAt: DateTime.parse(l['heartbeat_at'] as String).toUtc(),
      expiresAt: DateTime.parse(l['expires_at'] as String).toUtc(),
    );
    if (fencingToken != null && evidence.fencingToken != fencingToken) {
      throw const OwnerSyncConflict('lease_fenced');
    }
    _leases[sourceIdentity] = evidence;
    return evidence;
  }

  @override
  Future<OwnerSyncStagingIntent> beginUpload(
    OwnerSyncUploadDescriptor descriptor,
  ) async {
    _assertOwner();
    if (descriptor.contractVersion != OwnerDriveSyncClient.contractVersion ||
        descriptor.ownerId != _ownerId ||
        descriptor.ownerScope != _ownerScope ||
        !_uuidV4.hasMatch(descriptor.sourceIdentity) ||
        !_sha256.hasMatch(descriptor.payloadFingerprint) ||
        !_sha256.hasMatch(descriptor.objectSha256) ||
        descriptor.objectBytes < 1 ||
        descriptor.objectBytes > _maxObjectBytes ||
        !RegExp(
          r'^owner-sync-v2:[0-9a-f]{64}$',
        ).hasMatch(descriptor.idempotencyKey)) {
      throw const OwnerSyncConflict('upload_descriptor_invalid');
    }

    final data = await _invokeJson('phase8-drive-begin', {
      'contractVersion': descriptor.contractVersion,
      'ownerId': descriptor.ownerId,
      'ownerScope': descriptor.ownerScope,
      'sourceIdentity': descriptor.sourceIdentity,
      'idempotencyKey': descriptor.idempotencyKey,
      'payloadFingerprint': descriptor.payloadFingerprint,
      'objectSha256': descriptor.objectSha256,
      'objectBytes': descriptor.objectBytes,
    });
    _assertOwner();
    if (data['ok'] != true || data['intentId'] is! String) {
      throw const OwnerSyncConflict('begin_response_invalid');
    }
    final intentId = data['intentId'] as String;
    _intentSources[intentId] = descriptor.sourceIdentity;
    if (!_uuidV4.hasMatch(intentId)) {
      throw const OwnerSyncConflict('begin_intent_invalid');
    }
    final state = data['state'];
    if (state == 'staging') {
      if (data['receipt'] != null) {
        throw const OwnerSyncConflict('begin_staging_receipt_invalid');
      }
      return OwnerSyncStagingIntent(
        id: intentId,
        state: OwnerSyncStagingState.staging,
      );
    }
    if (state == 'finalized') {
      final rawReceipt = data['receipt'];
      if (rawReceipt is! Map) {
        throw const OwnerSyncConflict('begin_finalized_receipt_missing');
      }
      return OwnerSyncStagingIntent(
        id: intentId,
        state: OwnerSyncStagingState.finalized,
        receipt: _receipt(Map<String, dynamic>.from(rawReceipt)),
      );
    }
    throw const OwnerSyncConflict('begin_state_invalid');
  }

  @override
  Future<void> uploadPrivateObject({
    required String intentId,
    required List<int> envelopeBytes,
  }) async {
    _assertOwner();
    if (!_uuidV4.hasMatch(intentId) ||
        envelopeBytes.isEmpty ||
        envelopeBytes.length > _maxObjectBytes) {
      throw const OwnerSyncConflict('staging_upload_invalid');
    }
    final path = '$_ownerId/$intentId/envelope.json';
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            Uint8List.fromList(envelopeBytes),
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: false,
            ),
            retryAttempts: 0,
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const OwnerSyncTransportFailure('storage_timeout');
    } on StorageException catch (error) {
      if (error.statusCode == '409' && error.error == 'Duplicate') {
        // Never upsert/replace a staged object. The caller will proceed to the
        // server finalizer, which verifies the existing object's exact hash
        // and size before making it visible.
        throw const OwnerSyncStagedObjectAlreadyExists();
      }
      _throwStorageFailure(error);
    }
    _assertOwner();
  }

  @override
  Future<OwnerSyncReceipt> finalizeUpload(String intentId) async {
    _assertOwner();
    if (!_uuidV4.hasMatch(intentId)) {
      throw const OwnerSyncConflict('finalize_intent_invalid');
    }
    final lease = _leases[_intentSources[intentId]];
    final data = await _invokeJson('phase8-drive-finalize', {
      'intentId': intentId,
      if (lease != null) ...{
        'deviceId': lease.deviceId,
        'sessionId': lease.sessionId,
        'fencingToken': lease.fencingToken,
      },
    });
    _assertOwner();
    if (data['ok'] != true || data['receipt'] is! Map) {
      throw const OwnerSyncConflict('finalize_response_invalid');
    }
    return _receipt(Map<String, dynamic>.from(data['receipt'] as Map));
  }

  @override
  Future<OwnerSyncDownloadPage> download({
    required String ownerId,
    required String afterCursor,
    required int limit,
  }) async {
    _assertOwner();
    if (ownerId != _ownerId || limit < 1 || limit > 100) {
      throw const OwnerSyncConflict('download_request_invalid');
    }

    final decodedCursor = afterCursor.isEmpty
        ? null
        : _decodeCursor(afterCursor);
    if (afterCursor.isNotEmpty && decodedCursor == null) {
      throw const OwnerSyncConflict('download_cursor_invalid');
    }
    final request = <String, Object?>{
      'action': decodedCursor == null ? 'begin' : 'page',
      'limit': limit,
      if (decodedCursor != null) 'cursor': afterCursor,
    };
    final data = await _invokeJson('phase8-drive-download', request);
    _assertOwner();

    final snapshotId = data['snapshotId'];
    final from = _integer(data['from']);
    final next = _integer(data['next']);
    final highWater = _integer(data['highWater']);
    final nextCursor = data['nextCursor'];
    final hasMore = data['hasMore'];
    final rawChanges = data['changes'];
    if (data['ok'] != true ||
        snapshotId is! String ||
        !_uuidV4.hasMatch(snapshotId) ||
        from == null ||
        next == null ||
        highWater == null ||
        nextCursor is! String ||
        hasMore is! bool ||
        rawChanges is! List ||
        rawChanges.length > limit) {
      throw const OwnerSyncConflict('download_response_invalid');
    }
    final expectedFrom = decodedCursor?.sequence ?? 0;
    final renewed =
        decodedCursor != null && data['resumedFromCursor'] == afterCursor;
    if (from != expectedFrom ||
        (decodedCursor != null &&
            decodedCursor.snapshotId != snapshotId &&
            !renewed)) {
      throw const OwnerSyncConflict('download_snapshot_cursor_conflict');
    }
    if (next < from || next > highWater) {
      throw const OwnerSyncConflict('download_sequence_range_invalid');
    }
    if (next == from && from < highWater) {
      throw const OwnerSyncConflict('download_page_made_no_progress');
    }
    if (hasMore != (next < highWater)) {
      throw const OwnerSyncConflict('download_high_water_mismatch');
    }
    final parsedNext = _decodeCursor(nextCursor);
    if (parsedNext == null ||
        parsedNext.snapshotId != snapshotId ||
        parsedNext.sequence != next) {
      throw const OwnerSyncConflict('download_next_cursor_invalid');
    }

    final changes = <OwnerSyncRemoteChange>[];
    var previousSequence = from;
    for (final rawChange in rawChanges) {
      if (rawChange is! Map) {
        throw const OwnerSyncConflict('download_change_invalid');
      }
      final change = Map<String, dynamic>.from(rawChange);
      final sequence = _integer(change['sequence']);
      final rawMutation = change['mutation'];
      if (sequence == null ||
          sequence <= previousSequence ||
          sequence > next ||
          rawMutation is! Map) {
        throw const OwnerSyncConflict('download_change_order_invalid');
      }
      final mutation = OwnerSyncMutation.fromMap(
        Map<String, dynamic>.from(rawMutation),
      );
      if (mutation.ownerId != _ownerId || mutation.ownerScope != _ownerScope) {
        throw const OwnerSyncConflict('download_change_owner_mismatch');
      }
      changes.add(
        OwnerSyncRemoteChange(cursor: '$sequence', mutation: mutation),
      );
      previousSequence = sequence;
    }
    if (changes.isNotEmpty && changes.last.cursor != '$next') {
      throw const OwnerSyncConflict('download_page_sequence_gap');
    }
    _assertOwner();
    return OwnerSyncDownloadPage(
      ownerId: _ownerId,
      fromCursor: afterCursor,
      nextCursor: nextCursor,
      changes: List.unmodifiable(changes),
    );
  }

  Future<Map<String, dynamic>> _invokeJson(
    String function,
    Map<String, Object?> body,
  ) async {
    _assertOwner();
    try {
      final response = await _client.functions
          .invoke(function, body: body)
          .timeout(requestTimeout);
      _assertOwner();
      if (response.data is! Map) {
        throw const OwnerSyncConflict('function_response_invalid');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on TimeoutException {
      throw const OwnerSyncTransportFailure('function_timeout');
    } on FunctionException catch (error) {
      _throwFunctionFailure(error);
    }
  }

  OwnerSyncReceipt _receipt(Map<String, dynamic> value) {
    final ownerScope = value['ownerScope'];
    final key = value['idempotencyKey'];
    final fingerprint = value['payloadFingerprint'];
    final remoteId = value['remoteId'];
    if (ownerScope != _ownerScope ||
        key is! String ||
        !RegExp(r'^owner-sync-v2:[0-9a-f]{64}$').hasMatch(key) ||
        fingerprint is! String ||
        !_sha256.hasMatch(fingerprint) ||
        remoteId is! String ||
        remoteId.isEmpty) {
      throw const OwnerSyncConflict('remote_receipt_invalid');
    }
    return OwnerSyncReceipt(
      ownerScope: ownerScope as String,
      idempotencyKey: key,
      payloadFingerprint: fingerprint,
      remoteId: remoteId,
      changeSequence: _integer(value['changeSequence']),
    );
  }

  Never _throwFunctionFailure(FunctionException error) {
    final status = error.status;
    final details = error.details;
    final rawCode = details is Map ? details['error_code'] : null;
    final code = rawCode is String && _safeErrorCode.hasMatch(rawCode)
        ? rawCode
        : 'remote_function_rejected';
    if (status == 0 || status == 408 || status == 429 || status >= 500) {
      throw OwnerSyncTransportFailure(
        status == 0 ? 'function_transport' : 'function_http_$status',
      );
    }
    throw OwnerSyncConflict(code);
  }

  Never _throwStorageFailure(StorageException error) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == null ||
        status == 0 ||
        status == 408 ||
        status == 429 ||
        status >= 500) {
      throw const OwnerSyncTransportFailure('storage_transport');
    }
    throw const OwnerSyncConflict('storage_upload_rejected');
  }

  static int? _integer(Object? value) =>
      value is int && value >= 0 ? value : null;

  static ({String snapshotId, int sequence})? _decodeCursor(String value) {
    if (value.isEmpty ||
        value.length > 128 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      return null;
    }
    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(value)));
      final separator = decoded.lastIndexOf(':');
      if (separator <= 0) return null;
      final snapshotId = decoded.substring(0, separator);
      final sequenceText = decoded.substring(separator + 1);
      if (!_uuidV4.hasMatch(snapshotId) ||
          !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(sequenceText)) {
        return null;
      }
      final sequence = int.tryParse(sequenceText);
      if (sequence == null || sequence > 9007199254740991) return null;
      return (snapshotId: snapshotId, sequence: sequence);
    } on FormatException {
      return null;
    }
  }
}
