import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/drive_session.dart';
import '../models/drive_score_record.dart';
import '../models/canonical_telemetry_point.dart';
import '../features/my_world/config/my_world_rules.dart';
import '../features/my_world/models/world_pending_job.dart';
import 'device_drive_archive.dart';
import 'drive_score_storage_service.dart';
import 'drive_source_provenance.dart';
import 'gps_session_ownership.dart';
import 'local_source_bundle.dart';
import 'owner_drive_sync_client.dart';
import 'owner_scoped_local_store.dart';
import 'owned_drive_finalization.dart';

class LegacyTransferRow {
  const LegacyTransferRow(this.key, this.drive, this.fingerprint);
  final String key;
  final DriveSession? drive;
  final String? fingerprint;
  String? get incompatibility => drive == null
      ? 'Kayıt okunamıyor; güvenli temizlik için kaynak doğrulanamıyor.'
      : AccountDriveTransfer.incompatibility(drive!);
}

/// Deliberately separate from the read-only archive. Every read/delete requires
/// a fresh revocable device-auth capability and an idle, pinned owner operation.
abstract interface class LegacyTransferSource {
  Future<List<LegacyTransferRow>> read();
  Future<void> remove(LegacyTransferRow expected);
  Future<void> close();
}

class AccountDriveTransferSources {
  const AccountDriveTransferSources({
    required this.openGuest,
    required this.hasLegacy,
    required this.openLegacy,
    required this.authorizer,
  });
  final Future<OwnerScopedLocalStore> Function() openGuest;
  final Future<bool> Function() hasLegacy;
  final Future<LegacyTransferSource> Function(DeviceDriveArchiveContext)
  openLegacy;
  final DeviceArchiveAuthorizer authorizer;
}

class AccountTransferResult {
  const AccountTransferResult(this.transferred, this.rejected, this.localOnly);
  final int transferred;
  final int rejected;
  final int localOnly;
}

/// One durable source-side claim per source, one deterministic destination ID.
/// Claims retain the frozen payload until destination + projections + outbox
/// read-back succeed. Source removal is last; retry never invents provenance.
class AccountDriveTransfer {
  AccountDriveTransfer({
    required this.target,
    required this.guest,
    required this.requireCurrent,
  });
  final OwnerScopedLocalStore target;
  final OwnerScopedLocalStore guest;
  final void Function() requireCurrent;
  static const _prefix = 'account_transfer_v1:';
  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static String? incompatibility(DriveSession drive) {
    final error = _metadataError(drive);
    if (error != null) return error;
    if (drive.route.length < 2) return 'Kayıtlı GPS rotası yetersiz.';
    return null;
  }

  static String? _metadataError(DriveSession drive) {
    if (drive.id.isEmpty ||
        drive.durationSeconds < 0 ||
        !drive.distance.isFinite ||
        drive.distance < 0 ||
        !drive.averageSpeed.isFinite ||
        drive.averageSpeed < 0 ||
        !drive.maxSpeed.isFinite ||
        drive.maxSpeed < 0) {
      return 'Tarih, süre, mesafe veya hız bilgisi geçersiz.';
    }
    if ([
          drive.maxAccelerationG,
          drive.maxBrakingG,
          drive.maxCorneringSpeed,
          drive.maxAltitude,
          drive.altitudeGain,
        ].any((v) => !v.isFinite) ||
        [
          drive.altitudeLoss,
          drive.bestZeroToHundredSeconds,
          drive.bestSixtyToHundredSeconds,
        ].any((v) => v != null && !v.isFinite)) {
      return 'Kayıtlı ölçüm alanları geçersiz; değerler uydurulmadan dönüştürülemiyor.';
    }
    if (drive.route.any(
      (p) =>
          !p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 90 ||
          p.longitude.abs() > 180,
    )) {
      return 'GPS rotasında geçersiz koordinat var.';
    }
    return null;
  }

  void _guard() {
    requireCurrent();
    if (target.owner.kind != GpsOwnerKind.account ||
        guest.owner.kind != GpsOwnerKind.guest ||
        target.scope == guest.scope) {
      throw StateError('transfer_owner_invalid');
    }
  }

  String _key(String kind, String id) =>
      '$_prefix${_hash('$kind:${guest.scope}:$id')}';
  Map? _claim(String kind, String id) =>
      guest.read<Map>(guest.owner, 'profile', _key(kind, id));

  List<String> guestIds() {
    _guard();
    final result = <String>{};
    for (final id in guest.keys(guest.owner, 'drives').whereType<String>()) {
      if (guest.read(guest.owner, 'local_lifecycle_v1', 'history:$id') !=
          null) {
        continue;
      }
      final claim = _claim('guest', id);
      if (claim == null) {
        try {
          final bundle = _guestSource(id);
          if (_metadataError(bundle.drive) == null) result.add(id);
        } catch (_) {
          /* Incomplete/conflicting source stays in Guest. */
        }
      } else if (claim['targetScope'] == target.scope &&
          claim['state'] != 'completed') {
        result.add(id);
      }
    }
    for (final key
        in guest
            .keys(guest.owner, 'profile')
            .whereType<String>()
            .where((k) => k.startsWith(_prefix))) {
      final claim = guest.read<Map>(guest.owner, 'profile', key)!;
      if (claim['kind'] == 'guest' &&
          claim['targetScope'] == target.scope &&
          claim['state'] != 'completed') {
        result.add(claim['sourceId'] as String);
      }
    }
    return result.toList()..sort();
  }

  String guestPromptFingerprint() => _hash(jsonEncode(guestIds()));

  String _guestFingerprint(LocalSourceBundle source) => _hash(
    jsonEncode({
      'bundle': source.toMap(),
      'driveBytes': base64Encode(guest.encode(source.drive)),
      'name': guest.read<String>(guest.owner, 'drive_names', source.drive.id),
    }),
  );

  LocalSourceBundle _guestSource(String id) {
    final state = guest.read<Map>(
      guest.owner,
      OwnedDriveFinalization.group,
      id,
    );
    if (state != null && state['state'] != 'completed') {
      throw StateError('transfer_source_pending');
    }
    final drive = guest.read<DriveSession>(guest.owner, 'drives', id);
    final raw = guest.read<Map>(guest.owner, 'drive_source_provenance_v1', id);
    final proof = raw == null ? null : DriveSourceProvenance.fromMap(raw);
    if (drive == null ||
        proof?.status == DriveProvenanceStatus.conflict ||
        (proof != null && proof.ownerScope != guest.scope)) {
      throw StateError('transfer_source_unverified');
    }
    final storedScore = guest.read<DriveScoreRecord>(
      guest.owner,
      'drive_scores',
      DriveScoreStorageService.keyFor(
        id,
        DriveScoreRecord.currentAlgorithmVersion,
      ),
    );
    final score =
        storedScore != null &&
            storedScore.totalScore.isFinite &&
            storedScore.totalScore >= 0 &&
            storedScore.totalScore <= 100 &&
            storedScore.overallConfidence.isFinite &&
            storedScore.overallConfidence >= 0 &&
            storedScore.overallConfidence <= 1
        ? storedScore
        : null;
    return LocalSourceBundle(
      drive: drive,
      ownerScope: guest.scope,
      sourceProvenance: proof,
      telemetry: guest.read<DriveTelemetryRecord>(
        guest.owner,
        'drive_telemetry',
        id,
      ),
      score: score,
    )..validate();
  }

  Future<AccountTransferResult> transferGuest() async {
    _guard();
    var transferred = 0, localOnly = 0;
    final ids = guestIds();
    var rejected = guest
        .keys(guest.owner, 'drives')
        .whereType<String>()
        .where(
          (id) =>
              !ids.contains(id) &&
              _claim('guest', id) == null &&
              guest.read(guest.owner, 'local_lifecycle_v1', 'history:$id') ==
                  null,
        )
        .length;
    for (final id in ids) {
      _guard();
      final prior = _claim('guest', id);
      final drive = guest.read<DriveSession>(guest.owner, 'drives', id);
      if (prior == null && (drive == null || _metadataError(drive) != null)) {
        rejected++;
        continue;
      }
      LocalSourceBundle? source;
      if (drive != null) {
        try {
          source = _guestSource(id);
        } catch (_) {
          rejected++;
          continue;
        }
        if (prior != null &&
            prior['sourceFingerprint'] != _guestFingerprint(source)) {
          throw StateError('transfer_source_changed');
        }
      }
      final local = await _transfer('guest', id, source, prior: prior);
      _guard();
      // A removed source with an unfinished claim is a valid crash-retry.
      if (drive != null) {
        if (_claim('guest', id)?['sourceFingerprint'] !=
            _guestFingerprint(_guestSource(id))) {
          throw StateError('transfer_source_changed');
        }
        await guest.put(guest.owner, 'local_lifecycle_v1', 'history:$id', {
          'version': 1,
          'state': 'transferred',
          'targetScope': target.scope,
        });
        _guard();
        await guest.remove(guest.owner, 'drives', id);
      }
      _guard();
      await _finish('guest', id);
      transferred++;
      if (local) localOnly++;
    }
    return AccountTransferResult(transferred, rejected, localOnly);
  }

  Future<AccountTransferResult> transferLegacy(
    LegacyTransferSource source,
  ) async {
    _guard();
    var transferred = 0, rejected = 0;
    for (final row in await source.read()) {
      _guard();
      if (row.incompatibility != null || row.fingerprint == null) {
        rejected++;
        continue;
      }
      final prior = _claim('legacy', row.key);
      if (prior != null && prior['targetScope'] != target.scope) {
        rejected++;
        continue;
      }
      if (prior != null && prior['sourceFingerprint'] != row.fingerprint) {
        throw StateError('transfer_source_changed');
      }
      await _transfer(
        'legacy',
        row.key,
        LocalSourceBundle(
          drive: row.drive!,
          ownerScope: 'legacy-device-archive',
        ),
        prior: prior,
        sourceFingerprint: row.fingerprint,
      );
      _guard();
      await source.remove(row);
      _guard();
      await _finish('legacy', row.key);
      transferred++;
    }
    return AccountTransferResult(transferred, rejected, transferred);
  }

  Future<int> cleanIncompatible(
    LegacyTransferSource source,
    List<LegacyTransferRow> selected, {
    required bool confirmed,
  }) async {
    _guard();
    if (!confirmed) throw StateError('transfer_cleanup_consent_required');
    var removed = 0;
    final current = {for (final row in await source.read()) row.key: row};
    final verified = <LegacyTransferRow>[];
    for (final requested in selected) {
      _guard();
      final row = current[requested.key];
      if (row == null ||
          row.incompatibility == null ||
          row.fingerprint == null ||
          row.fingerprint != requested.fingerprint) {
        throw StateError('transfer_cleanup_source_changed');
      }
      // A partially transferred source is not an incompatible-record cleanup target.
      if (_claim('legacy', row.key) != null) {
        throw StateError('transfer_cleanup_claimed');
      }
      verified.add(row);
    }
    for (final row in verified) {
      _guard();
      await source.remove(row);
      _guard();
      removed++;
    }
    return removed;
  }

  Future<bool> _transfer(
    String kind,
    String id,
    LocalSourceBundle? source, {
    Map? prior,
    String? sourceFingerprint,
  }) async {
    _guard();
    Map claim;
    if (prior != null) {
      if (prior['version'] != 1 ||
          prior['kind'] != kind ||
          prior['sourceId'] != id ||
          prior['targetScope'] != target.scope) {
        throw StateError('transfer_claimed_by_other_account');
      }
      claim = prior;
      // Failed flushes can leave a claim in memory. Persist it before target writes.
      await guest.put(guest.owner, 'profile', _key(kind, id), claim);
      _guard();
    } else {
      final original = source!;
      final fingerprint = sourceFingerprint ?? _guestFingerprint(original);
      final proven = original.sourceProvenance?.isProven == true;
      final identity = proven
          ? original.sourceProvenance!.sourceIdentity!
          : '$kind:${guest.scope}:$id:$fingerprint';
      final targetId = 'transfer_${_hash(identity)}';
      if (proven &&
          target
              .keys(target.owner, 'drive_source_provenance_v1')
              .any(
                (key) =>
                    key != targetId &&
                    target.read<Map>(
                          target.owner,
                          'drive_source_provenance_v1',
                          key,
                        )?['sourceIdentity'] ==
                        identity,
              )) {
        throw StateError('transfer_source_already_present_under_other_id');
      }
      final proof = proven
          ? DriveSourceProvenance.proven(
              sourceIdentity: identity,
              ownerScope: target.scope,
            )
          : DriveSourceProvenance.unproven(
              ownerScope: target.scope,
              archiveNamespace: kind,
              archiveFingerprint: fingerprint,
            );
      final raw = original.toMap();
      (raw['drive'] as Map)['id'] = targetId;
      if (raw['telemetry'] != null) {
        (raw['telemetry'] as Map)['driveId'] = targetId;
      }
      if (raw['score'] != null) (raw['score'] as Map)['driveId'] = targetId;
      raw['ownerScope'] = target.scope;
      raw['sourceProvenance'] = proof.toMap();
      // Unproven values remain local. Never invent evidence for old routes.
      raw['roads'] = <dynamic>[];
      final bundle = LocalSourceBundle.fromMap(raw)..validate();
      final payload = jsonEncode(bundle.toMap());
      final preservedDrive =
          guest.decode(guest.encode(original.drive)) as DriveSession;
      preservedDrive.id = targetId;
      final driveSnapshot = base64Encode(guest.encode(preservedDrive));
      claim = {
        'version': 1,
        'kind': kind,
        'sourceId': id,
        'sourceFingerprint': fingerprint,
        'targetScope': target.scope,
        'targetId': targetId,
        'state': 'prepared',
        'payload': payload,
        'payloadFingerprint': _hash(payload),
        'driveSnapshot': driveSnapshot,
        'driveSnapshotFingerprint': _hash(driveSnapshot),
        if (kind == 'guest')
          'sourceName': guest.read<String>(guest.owner, 'drive_names', id),
      };
      await guest.put(guest.owner, 'profile', _key(kind, id), claim);
      _guard();
    }
    if (claim['payload'] is! String ||
        claim['payloadFingerprint'] != _hash(claim['payload'] as String)) {
      throw StateError('transfer_claim_checksum');
    }
    final bundle = LocalSourceBundle.fromMap(
      Map<String, dynamic>.from(jsonDecode(claim['payload'] as String)),
    )..validate();
    if (claim['driveSnapshot'] is! String ||
        claim['driveSnapshotFingerprint'] !=
            _hash(claim['driveSnapshot'] as String)) {
      throw StateError('transfer_drive_snapshot_checksum');
    }
    final preservedDrive =
        target.decode(base64Decode(claim['driveSnapshot'] as String))
            as DriveSession;
    if (bundle.ownerScope != target.scope ||
        bundle.drive.id != claim['targetId'] ||
        preservedDrive.id != bundle.drive.id) {
      throw StateError('transfer_payload_owner_mismatch');
    }
    final targetId = bundle.drive.id;
    final proof = bundle.sourceProvenance!;
    final localOnly = !_cloudCompatible(bundle);
    final finalization = target.read<Map>(
      target.owner,
      OwnedDriveFinalization.group,
      targetId,
    );
    final existing = target.read<DriveSession>(
      target.owner,
      'drives',
      targetId,
    );
    if (target.read(target.owner, 'local_lifecycle_v1', 'history:$targetId') !=
            null ||
        (proof.sourceIdentity != null &&
            target.read(
                  target.owner,
                  OwnerDriveSyncClient.deletionBox,
                  'source:${proof.sourceIdentity}',
                ) !=
                null)) {
      throw StateError('transfer_target_deleted');
    }
    if (existing != null && finalization?['transferClaim'] != _key(kind, id)) {
      throw StateError('transfer_destination_conflict');
    }
    if (finalization?['state'] != 'completed') {
      await target.put(target.owner, OwnedDriveFinalization.group, targetId, {
        'version': 1,
        'state': 'pending',
        'derivedReady': false,
        'transferClaim': _key(kind, id),
        'sourceIdentity': proof.sourceIdentity,
        'ownerScope': target.scope,
        'localOnlyImport': localOnly,
      });
      _guard();
      await target.put(target.owner, 'drives', targetId, preservedDrive);
      if (claim['sourceName'] is String) {
        await target.put(
          target.owner,
          'drive_names',
          targetId,
          claim['sourceName'],
        );
      }
      await target
          .put(target.owner, 'drive_details_v1', 'gpsTransferDate:$targetId', {
            'dateMicros': bundle.drive.date.microsecondsSinceEpoch,
            'dateIsUtc': bundle.drive.date.isUtc,
          });
      await target.put(target.owner, 'drive_details_v1', targetId, {
        'accountTransfer': kind,
        'localOnly': localOnly,
        'reason': localOnly
            ? 'Eski kayıtta doğrulanmış telemetri yok; yalnız bu hesapta yerel saklanır.'
            : null,
      });
      if (bundle.telemetry != null) {
        await target.put(
          target.owner,
          'drive_telemetry',
          targetId,
          bundle.telemetry,
        );
      }
      if (bundle.score != null) {
        await target.put(
          target.owner,
          'drive_scores',
          DriveScoreStorageService.keyFor(
            targetId,
            bundle.score!.algorithmVersion,
          ),
          bundle.score,
        );
      }
      await target.put(
        target.owner,
        'drive_source_provenance_v1',
        targetId,
        proof.toMap(),
      );
      _guard();
      final repositories = target.repositories(target.owner);
      await repositories.prepareSource(bundle);
      if (proof.isProven &&
          bundle.telemetry != null &&
          bundle.telemetry!.points.isNotEmpty) {
        await repositories.contribute(bundle);
        repositories.careerStatistics();
        if (bundle.score != null &&
            bundle.drive.distance >= MyWorldRules.minimumValidDistanceMeters) {
          await target
              .worldSources(target.owner)
              .enqueueIfAbsent(
                WorldPendingJob.pending(
                  driveSessionId: targetId,
                  type: WorldJobType.validateRoad,
                  now: DateTime.now().toUtc(),
                ),
              );
        }
      }
      _guard();
      await target.flush(target.owner);
      _verify(bundle, preservedDrive);
      await target.put(target.owner, OwnedDriveFinalization.group, targetId, {
        ...target.read<Map>(
          target.owner,
          OwnedDriveFinalization.group,
          targetId,
        )!,
        'state': 'completed',
        'derivedReady': true,
        'automaticSyncEligible': !localOnly,
      });
    }
    _guard();
    await target.put(
      target.owner,
      OwnedDriveFinalization.group,
      targetId,
      target.read<Map>(target.owner, OwnedDriveFinalization.group, targetId)!,
    );
    _verify(bundle, preservedDrive);
    if (claim['sourceName'] is String &&
        target.read<String>(target.owner, 'drive_names', targetId) !=
            claim['sourceName']) {
      throw StateError('transfer_name_readback_mismatch');
    }
    if (!localOnly) {
      // This operation only persists the outbox. It never invokes a transport.
      final client = OwnerDriveSyncClient(
        store: target,
        requireCurrent: requireCurrent,
      );
      final key = await client.enqueueDrive(
        targetId,
        automaticSyncEligible: true,
      );
      // Verify durability even for a row left in memory by an earlier failed flush.
      await target.put(
        target.owner,
        OwnerDriveSyncClient.boxName,
        key,
        client.readRecord(key)!,
      );
      if (!target.writeDurable(OwnerDriveSyncClient.boxName, key)) {
        throw StateError('transfer_outbox_not_durable');
      }
      _guard();
    }
    await guest.put(guest.owner, 'profile', _key(kind, id), {
      ...claim,
      'state': 'destination_verified',
    });
    _guard();
    return localOnly;
  }

  void _verify(LocalSourceBundle expected, DriveSession preservedDrive) {
    _guard();
    final id = expected.drive.id;
    final proof = target.read<Map>(
      target.owner,
      'drive_source_provenance_v1',
      id,
    );
    if (proof == null) throw StateError('transfer_readback_missing');
    final actual = LocalSourceBundle(
      drive: target.read<DriveSession>(target.owner, 'drives', id)!,
      ownerScope: target.scope,
      telemetry: target.read<DriveTelemetryRecord>(
        target.owner,
        'drive_telemetry',
        id,
      ),
      score: expected.score == null
          ? null
          : target.read<DriveScoreRecord>(
              target.owner,
              'drive_scores',
              DriveScoreStorageService.keyFor(
                id,
                expected.score!.algorithmVersion,
              ),
            ),
      sourceProvenance: DriveSourceProvenance.fromMap(proof),
    )..validate();
    if (jsonEncode(actual.toMap()) != jsonEncode(expected.toMap()) ||
        base64Encode(target.encode(actual.drive)) !=
            base64Encode(target.encode(preservedDrive)) ||
        !target.writeDurable('drives', id) ||
        !target.writeDurable(OwnedDriveFinalization.group, id)) {
      throw StateError('transfer_readback_mismatch');
    }
  }

  bool _cloudCompatible(LocalSourceBundle source) {
    final proof = source.sourceProvenance;
    final telemetry = source.telemetry;
    if (proof?.isProven != true ||
        telemetry == null ||
        telemetry.points.isEmpty ||
        telemetry.dataVersion != 1) {
      return false;
    }
    final metadata = telemetry.acquisitionMetadata;
    if (metadata['provenanceStatus'] != 'proven' ||
        metadata['sourceIdentity'] != proof!.sourceIdentity ||
        metadata['sourceIdentityVersion'] != 1 ||
        metadata['sourceNamespace'] != 'drive_source_v1') {
      return false;
    }
    final drive = source.drive;
    if ([
          drive.stopCount,
          drive.stoppedSeconds,
          drive.hardBrakeCount,
          drive.hardAccelerationCount,
          drive.sharpTurnCount,
          drive.cornerCount,
        ].any((v) => v < 0) ||
        [
          drive.maxAccelerationG,
          drive.maxBrakingG,
          drive.maxCorneringSpeed,
          drive.maxAltitude,
          drive.altitudeGain,
        ].any((v) => !v.isFinite) ||
        [
          drive.altitudeLoss,
          drive.bestZeroToHundredSeconds,
          drive.bestSixtyToHundredSeconds,
        ].any((v) => v != null && !v.isFinite)) {
      return false;
    }
    final score = source.score;
    if (score != null &&
        (score.algorithmVersion != 1 ||
            score.telemetryDataVersion != telemetry.dataVersion ||
            !score.totalScore.isFinite ||
            score.totalScore < 0 ||
            score.totalScore > 100 ||
            !score.overallConfidence.isFinite ||
            score.overallConfidence < 0 ||
            score.overallConfidence > 1)) {
      return false;
    }
    return telemetry.points.every(
      (p) =>
          p.hasValidCoordinate &&
          p.speedMps.isFinite &&
          p.speedMps >= 0 &&
          p.accuracyMeters.isFinite &&
          p.accuracyMeters >= 0 &&
          p.headingDegrees.isFinite &&
          p.altitudeMeters.isFinite &&
          p.distanceFromPreviousMeters.isFinite &&
          p.distanceFromPreviousMeters >= 0 &&
          p.accelerationMps2.isFinite,
    );
  }

  Future<void> _finish(String kind, String id) async {
    final claim = _claim(kind, id)!;
    await guest.put(guest.owner, 'profile', _key(kind, id), {
      ...claim,
      'state': 'completed',
    });
    _guard();
  }
}
