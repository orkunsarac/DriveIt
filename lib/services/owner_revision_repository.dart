import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../config/local_ownership_gate.dart';
import 'gps_session_ownership.dart';
import 'legacy_asset_transfer.dart';
import 'legacy_account_import.dart';
import 'legacy_claim_ledger.dart';
import 'legacy_source_writer_fence.dart';
import 'local_owner_lifecycle.dart';
import 'owner_scoped_local_store.dart';
import 'owner_revision_models.dart';

abstract interface class OwnerRevisionDomainVerifier {
  /// Must validate domain relationships (including World rebuild evidence,
  /// Career contribution basis, tombstones, poster references and outbox
  /// immutability). Returning evidence is required before durable verification.
  Future<Map<String, Object?>> verify(
    OwnerRevisionSnapshot snapshot,
    List<OwnerRevisionRecord> plannedRecords,
  );
}

class OwnerRevisionConflict implements Exception {
  OwnerRevisionConflict(Iterable<String> codes)
    : codes = List.unmodifiable(codes.toSet().toList()..sort());
  final List<String> codes;
  @override
  String toString() => 'Owner revision conflicts: ${codes.join(', ')}';
}

class OwnerRevisionPublication {
  const OwnerRevisionPublication({
    required this.revisionId,
    required this.generation,
    required this.recordCount,
    required this.assetCount,
    required this.idempotent,
  });
  final String revisionId;
  final int generation;
  final int recordCount;
  final int assetCount;
  final bool idempotent;
}

/// Repository-level, dormant owner revision staging and durable publication.
/// It stores opaque canonical Hive payloads in the same WAL/FULL SQLite file as
/// claim receipts. It does not replace live Hive stores or screen read paths.
class OwnerRevisionRepository {
  OwnerRevisionRepository({
    required this.ledger,
    required this.gate,
    required this.domainVerifier,
    this.verifyAsset,
    this.boundary,
  });

  final LegacyClaimLedger ledger;
  final LocalOwnershipGate gate;
  final OwnerRevisionDomainVerifier domainVerifier;
  final Future<bool> Function(OwnerRevisionAsset asset)? verifyAsset;
  final Future<void> Function(String stage)? boundary;

  /// Captures every opened personal group using the owner's frozen lease.
  /// The provenance resolver must return evidence-backed source identities;
  /// unresolved rows are represented with an empty identity and fail closed.
  OwnerRevisionSnapshot captureOwnerSnapshot({
    required LocalOwnerLease lease,
    required String? expectedBaseRevisionId,
    required String sourceRevision,
    required String importNamespace,
    required String importFingerprint,
    required OwnerRevisionProvenanceResolver provenance,
    List<OwnerRevisionAsset> ownerAssets = const [],
  }) {
    lease.requireCurrent();
    final ownerUuid = lease.owner.userId;
    if (ownerUuid == null || lease.owner.kind != GpsOwnerKind.account) {
      throw const ImportFailure('revision_owner_mismatch');
    }
    final records = lease.revisionRecords(provenance: provenance);
    return OwnerRevisionSnapshot(
      ownerUuid: ownerUuid,
      expectedBaseRevisionId: expectedBaseRevisionId,
      sourceRevision: sourceRevision,
      sourceFingerprint: fingerprintSourceSnapshot(records, ownerAssets),
      importNamespace: importNamespace,
      importFingerprint: importFingerprint,
      coveredGroups: OwnerScopedLocalStore.groups.toSet(),
      records: records,
      assets: ownerAssets,
    );
  }

  Future<OwnerRevisionPublication> prepareVerifyPublish({
    required LocalOwnerLease lease,
    required OwnerRevisionSnapshot snapshot,
    required VerifiedLegacyImport imported,
    required RegisteredSourceWriterFence writerFence,
    required Future<bool> Function() sourceIsCurrent,
  }) async {
    _requireEnabled(lease, snapshot);
    if (snapshot.sourceFingerprint !=
        fingerprintSourceSnapshot(snapshot.records, snapshot.assets)) {
      throw const ImportFailure('revision_source_fingerprint_mismatch');
    }
    writerFence.requireRegistered();
    await writerFence.pauseAndDrain();
    try {
      _requireEnabled(lease, snapshot);
      if (!imported.isForLease(lease) ||
          imported.sourceNamespace != snapshot.importNamespace ||
          imported.fingerprint != snapshot.importFingerprint) {
        throw const ImportFailure('revision_verified_import_mismatch');
      }
      final effective = _withVerifiedImport(snapshot, imported);
      final plan = _plan(effective);
      final claim = await ledger.get(effective.importNamespace);
      if (claim == null ||
          !claim.completed ||
          claim.fingerprint != effective.importFingerprint ||
          claim.owner.userId != effective.ownerUuid) {
        throw const ImportFailure('revision_import_claim_unverified');
      }
      final revisionId = _revisionId(effective, plan.records);
      final alreadyVisible = await _publishedRetry(
        effective,
        revisionId,
        claim.operationId,
        plan,
      );
      if (alreadyVisible != null) return alreadyVisible;
      if (!await sourceIsCurrent()) {
        throw const ImportFailure('revision_source_changed');
      }
      await _checkSource(effective, sourceIsCurrent);
      final active = await _pointer(effective.ownerUuid);
      if (active?.revisionId != effective.expectedBaseRevisionId) {
        throw const ImportFailure('revision_base_stale');
      }
      await boundary?.call('prepare_before');
      await _prepare(effective, plan, revisionId, claim.operationId);
      await boundary?.call('prepare_after');
      _requireEnabled(lease, effective);
      await _checkSource(effective, sourceIsCurrent);
      await _verify(effective, plan, revisionId, imported);
      await boundary?.call('verify_after');
      _requireEnabled(lease, effective);
      await _checkSource(effective, sourceIsCurrent);
      return await _publish(
        effective,
        plan,
        revisionId,
        claim.operationId,
        lease,
      );
    } finally {
      await writerFence.resume();
    }
  }

  OwnerRevisionSnapshot _withVerifiedImport(
    OwnerRevisionSnapshot snapshot,
    VerifiedLegacyImport imported,
  ) {
    if (snapshot.records.any(
      (record) => record.origin != OwnerRevisionOrigin.owner,
    )) {
      throw const ImportFailure('revision_owner_snapshot_origin_invalid');
    }
    final legacyRecords = imported.revisionRecords().map(
      (record) => OwnerRevisionRecord(
        group: record.group,
        logicalKey: jsonEncode(record.key),
        sourceIdentity: record.sourceIdentity,
        origin: OwnerRevisionOrigin.legacy,
        payload: record.payload,
        sourceNamespace: record.sourceNamespace,
        sourceFingerprint: record.sourceFingerprint,
      ),
    );
    final legacyAssets = imported.revisionAssets().map(
      (asset) => OwnerRevisionAsset(
        sourceNamespace: imported.sourceNamespace,
        id: asset.id,
        sha256: asset.sha256,
        bytes: asset.bytes,
        relativePath: asset.relativePath,
        origin: OwnerRevisionAssetOrigin.legacyImport,
      ),
    );
    return OwnerRevisionSnapshot(
      ownerUuid: snapshot.ownerUuid,
      expectedBaseRevisionId: snapshot.expectedBaseRevisionId,
      sourceRevision: snapshot.sourceRevision,
      sourceFingerprint: snapshot.sourceFingerprint,
      importNamespace: snapshot.importNamespace,
      importFingerprint: snapshot.importFingerprint,
      coveredGroups: snapshot.coveredGroups,
      records: [...snapshot.records, ...legacyRecords],
      assets: [...snapshot.assets, ...legacyAssets],
    );
  }

  void _requireEnabled(LocalOwnerLease lease, OwnerRevisionSnapshot snapshot) {
    if (!gate.enabled || !LocalOwnershipGate.debugBuild) {
      throw const ImportFailure('owner_revision_gate_closed');
    }
    lease.requireCurrent();
    if (lease.owner.kind != GpsOwnerKind.account ||
        lease.owner.userId != snapshot.ownerUuid ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(snapshot.ownerUuid)) {
      throw const ImportFailure('revision_owner_mismatch');
    }
    if (snapshot.sourceRevision.isEmpty ||
        snapshot.sourceFingerprint.isEmpty ||
        snapshot.importNamespace.isEmpty ||
        snapshot.importFingerprint.isEmpty) {
      throw const ImportFailure('revision_source_identity_missing');
    }
    if (!snapshot.coveredGroups.containsAll(OwnerScopedLocalStore.groups)) {
      throw const ImportFailure('revision_inventory_incomplete');
    }
  }

  Future<void> _checkSource(
    OwnerRevisionSnapshot snapshot,
    Future<bool> Function() sourceIsCurrent,
  ) async {
    if (!await sourceIsCurrent() || !gate.enabled) {
      throw const ImportFailure('revision_source_changed');
    }
    final pointer = await _pointer(snapshot.ownerUuid);
    if (pointer?.revisionId != snapshot.expectedBaseRevisionId) {
      throw const ImportFailure('revision_base_stale');
    }
  }

  _RevisionPlan _plan(OwnerRevisionSnapshot snapshot) {
    final conflicts = <String>{};
    final exact = <String, OwnerRevisionRecord>{};
    for (final record in snapshot.records) {
      if (!OwnerScopedLocalStore.groups.contains(record.group) ||
          record.logicalKey.isEmpty ||
          record.sourceIdentity.isEmpty) {
        conflicts.add('source_identity_ambiguous');
        continue;
      }
      if (record.unresolvedCode != null) {
        conflicts.add(record.unresolvedCode!);
      }
      if (record.origin == OwnerRevisionOrigin.legacy &&
          (record.sourceNamespace != snapshot.importNamespace ||
              record.sourceFingerprint != snapshot.importFingerprint)) {
        conflicts.add('legacy_record_source_mismatch');
      }
      final prior = exact[record.id];
      if (prior != null) {
        if (prior.sha256 != record.sha256) {
          conflicts.add('same_provenance_content_conflict');
        }
      } else {
        exact[record.id] = record;
      }
    }

    // Fields whose semantics are singleton-by-key cannot be silently resolved
    // by input order. Different keys from different provenance remain distinct
    // for History and source snapshots.
    for (final singletonGroup in [
      'profile',
      'career_totals',
      'local_publish_state_v1',
      'planet_segment_outbox_v1',
    ]) {
      final byKey = <String, Set<String>>{};
      for (final record in exact.values.where(
        (r) => r.group == singletonGroup,
      )) {
        byKey
            .putIfAbsent(record.logicalKey, () => <String>{})
            .add(record.sha256);
      }
      if (byKey.values.any((hashes) => hashes.length > 1)) {
        conflicts.add('${singletonGroup}_conflict');
      }
    }

    // Tombstones suppress only the exact proven source identity they name.
    final tombstoned = exact.values
        .where((r) => r.tombstoneTargetIdentity != null)
        .map((r) => r.tombstoneTargetIdentity!)
        .toSet();
    final planned =
        exact.values
            .where(
              (r) =>
                  r.tombstoneTargetIdentity != null ||
                  !tombstoned.contains(r.sourceIdentity),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    final assetIds = <String>{};
    for (final asset in snapshot.assets) {
      final validNamespace =
          asset.origin == OwnerRevisionAssetOrigin.legacyImport
          ? asset.sourceNamespace == snapshot.importNamespace
          : asset.sourceNamespace ==
                GpsOwner.account(snapshot.ownerUuid).targetStore;
      if (!validNamespace ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256) ||
          asset.bytes < 0 ||
          asset.relativePath.isEmpty ||
          asset.relativePath.startsWith('/') ||
          asset.relativePath.split(RegExp(r'[/\\]')).contains('..') ||
          !assetIds.add(asset.id)) {
        conflicts.add('asset_evidence_invalid');
      }
    }
    if (snapshot.assets.any(
          (asset) => asset.origin == OwnerRevisionAssetOrigin.owner,
        ) &&
        verifyAsset == null) {
      conflicts.add('asset_verifier_unavailable');
    }
    if (conflicts.isNotEmpty) throw OwnerRevisionConflict(conflicts);
    return _RevisionPlan(planned, snapshot.assets);
  }

  Future<void> _prepare(
    OwnerRevisionSnapshot snapshot,
    _RevisionPlan plan,
    String revisionId,
    String operationId,
  ) async {
    await ledger.db.transaction((tx) async {
      final existing = await tx.query(
        'owner_revisions',
        where: 'revision_id=?',
        whereArgs: [revisionId],
      );
      if (existing.isEmpty) {
        await tx.insert('owner_revisions', {
          'revision_id': revisionId,
          'version': 1,
          'owner_uuid': snapshot.ownerUuid,
          'base_revision_id': snapshot.expectedBaseRevisionId,
          'source_revision': snapshot.sourceRevision,
          'source_fingerprint': snapshot.sourceFingerprint,
          'source_namespace': snapshot.importNamespace,
          'import_fingerprint': snapshot.importFingerprint,
          'plan_fingerprint': _planFingerprint(plan),
          'state': 'preparing',
          'record_count': plan.records.length,
          'asset_count': plan.assets.length,
          'created_us': DateTime.now().microsecondsSinceEpoch,
          'updated_us': DateTime.now().microsecondsSinceEpoch,
        });
        for (final record in plan.records) {
          await tx.insert('owner_revision_records', {
            'revision_id': revisionId,
            'record_id': record.id,
            'group_name': record.group,
            'logical_key': record.logicalKey,
            'source_identity': record.sourceIdentity,
            'origin': record.origin.name,
            'content_sha256': record.sha256,
            'payload': record.payload,
          });
          await boundary?.call('record_staged');
        }
        for (final asset in plan.assets) {
          await tx.insert('owner_revision_assets', {
            'revision_id': revisionId,
            'source_namespace': asset.sourceNamespace,
            'asset_id': asset.id,
            'sha256': asset.sha256,
            'bytes': asset.bytes,
            'relative_path': asset.relativePath,
          });
          await boundary?.call('asset_staged');
        }
      } else {
        final row = existing.single;
        if (row['owner_uuid'] != snapshot.ownerUuid ||
            row['source_revision'] != snapshot.sourceRevision ||
            row['source_fingerprint'] != snapshot.sourceFingerprint ||
            row['source_namespace'] != snapshot.importNamespace ||
            row['import_fingerprint'] != snapshot.importFingerprint ||
            row['plan_fingerprint'] != _planFingerprint(plan) ||
            row['record_count'] != plan.records.length ||
            row['asset_count'] != plan.assets.length) {
          throw const ImportFailure('revision_identity_conflict');
        }
      }
    });
    await boundary?.call('prepared');
    final claim = await ledger.get(snapshot.importNamespace);
    if (claim == null ||
        claim.operationId != operationId ||
        claim.fingerprint != snapshot.importFingerprint ||
        claim.owner.userId != snapshot.ownerUuid ||
        !claim.completed) {
      throw const ImportFailure('revision_import_claim_changed');
    }
  }

  Future<void> _verify(
    OwnerRevisionSnapshot snapshot,
    _RevisionPlan plan,
    String revisionId,
    VerifiedLegacyImport imported,
  ) async {
    final rows = await ledger.db.query(
      'owner_revision_records',
      where: 'revision_id=?',
      whereArgs: [revisionId],
      orderBy: 'record_id',
    );
    if (rows.length != plan.records.length) {
      throw const ImportFailure('revision_record_count_mismatch');
    }
    for (var i = 0; i < rows.length; i++) {
      final payload = rows[i]['payload'] as Uint8List;
      if (rows[i]['record_id'] != plan.records[i].id ||
          rows[i]['content_sha256'] != _sha(payload) ||
          rows[i]['content_sha256'] != plan.records[i].sha256) {
        throw const ImportFailure('revision_record_hash_mismatch');
      }
    }
    for (final asset in plan.assets) {
      final valid = asset.origin == OwnerRevisionAssetOrigin.legacyImport
          ? await _verifyImportedAsset(imported, asset)
          : await verifyAsset!(asset);
      if (!valid) {
        throw const ImportFailure('revision_asset_verification_failed');
      }
      await boundary?.call('asset_verified');
    }
    final evidence = await domainVerifier.verify(snapshot, plan.records);
    if (evidence.isEmpty || evidence['verified'] != true) {
      throw const ImportFailure('revision_domain_verification_failed');
    }
    final legacyGroups = plan.records
        .where((record) => record.origin == OwnerRevisionOrigin.legacy)
        .map((record) => record.group)
        .toSet();
    final requiredEvidence = <String>{'relationshipsVerified'};
    if (legacyGroups.any(_worldGroup)) {
      requiredEvidence.add('worldGenerationVerified');
      if (evidence['worldRulesVersion'] != 6) {
        throw const ImportFailure('revision_world_version_mismatch');
      }
    }
    if (legacyGroups.any(_careerGroup)) {
      requiredEvidence.add('careerMergeVerified');
    }
    if (legacyGroups.contains('profile')) {
      requiredEvidence.add('profileMergeVerified');
    }
    if (legacyGroups.contains('planet_segment_outbox_v1') ||
        legacyGroups.contains('local_publish_state_v1')) {
      requiredEvidence.add('planetOutboxVerified');
    }
    if (plan.assets.isNotEmpty || legacyGroups.contains('drive_posters')) {
      requiredEvidence.add('posterAssetsVerified');
    }
    if (requiredEvidence.any((key) => evidence[key] != true)) {
      throw const ImportFailure('revision_domain_evidence_incomplete');
    }
    await ledger.db.transaction((tx) async {
      final current = await tx.query(
        'owner_revisions',
        where: 'revision_id=?',
        whereArgs: [revisionId],
      );
      if (current.length != 1) {
        throw const ImportFailure('revision_missing');
      }
      final state = current.single['state'];
      if (state == 'published') return;
      if (state == 'verified') return;
      await tx.update(
        'owner_revisions',
        {
          'state': 'verified',
          'evidence': jsonEncode(evidence),
          'updated_us': DateTime.now().microsecondsSinceEpoch,
        },
        where: 'revision_id=? AND state=?',
        whereArgs: [revisionId, 'preparing'],
      );
    });
  }

  Future<bool> _verifyImportedAsset(
    VerifiedLegacyImport imported,
    OwnerRevisionAsset asset,
  ) async {
    await imported.verifyRevisionAsset(asset.id, asset.relativePath);
    return true;
  }

  Future<OwnerRevisionPublication> _publish(
    OwnerRevisionSnapshot snapshot,
    _RevisionPlan plan,
    String revisionId,
    String operationId,
    LocalOwnerLease lease,
  ) async {
    await boundary?.call('before_publish_transaction');
    final publication = await ledger.db.transaction((tx) async {
      lease.requireCurrent();
      final existingVisibility = await tx.query(
        'import_visibility',
        where: 'source_namespace=?',
        whereArgs: [snapshot.importNamespace],
      );
      if (existingVisibility.isNotEmpty) {
        final row = existingVisibility.single;
        if (row['fingerprint'] != snapshot.importFingerprint ||
            row['owner_uuid'] != snapshot.ownerUuid ||
            row['revision_id'] != revisionId ||
            row['operation_id'] != operationId) {
          throw const ImportFailure('import_visibility_conflict');
        }
        final pointer = await _pointer(snapshot.ownerUuid, executor: tx);
        if (pointer == null ||
            pointer.generation < (row['generation'] as int) ||
            !await _isInActiveChain(
              snapshot.ownerUuid,
              pointer.revisionId,
              revisionId,
              executor: tx,
            )) {
          throw const ImportFailure('visible_revision_pointer_conflict');
        }
        return OwnerRevisionPublication(
          revisionId: revisionId,
          generation: row['generation'] as int,
          recordCount: plan.records.length,
          assetCount: plan.assets.length,
          idempotent: true,
        );
      }
      final claim = await ledger.get(snapshot.importNamespace, executor: tx);
      if (claim == null ||
          !claim.completed ||
          claim.operationId != operationId ||
          claim.fingerprint != snapshot.importFingerprint ||
          claim.owner.userId != snapshot.ownerUuid) {
        throw const ImportFailure('revision_import_claim_changed');
      }
      final revisions = await tx.query(
        'owner_revisions',
        where: 'revision_id=?',
        whereArgs: [revisionId],
      );
      if (revisions.length != 1 || revisions.single['state'] != 'verified') {
        throw const ImportFailure('revision_not_verified');
      }
      final pointer = await _pointer(snapshot.ownerUuid, executor: tx);
      if (pointer?.revisionId != snapshot.expectedBaseRevisionId) {
        throw const ImportFailure('revision_base_stale');
      }
      lease.requireCurrent();
      final now = DateTime.now().microsecondsSinceEpoch;
      final generation = (pointer?.generation ?? 0) + 1;
      await boundary?.call('pointer_write');
      await tx.update(
        'owner_revisions',
        {'state': 'published', 'updated_us': now},
        where: 'revision_id=? AND state=?',
        whereArgs: [revisionId, 'verified'],
      );
      if (pointer == null) {
        await tx.insert('owner_revision_pointer', {
          'owner_uuid': snapshot.ownerUuid,
          'revision_id': revisionId,
          'generation': generation,
          'updated_us': now,
        });
      } else {
        await tx.update(
          'owner_revision_pointer',
          {
            'revision_id': revisionId,
            'generation': generation,
            'updated_us': now,
          },
          where: 'owner_uuid=? AND generation=?',
          whereArgs: [snapshot.ownerUuid, pointer.generation],
        );
      }
      await tx.insert('import_visibility', {
        'source_namespace': snapshot.importNamespace,
        'fingerprint': snapshot.importFingerprint,
        'owner_uuid': snapshot.ownerUuid,
        'revision_id': revisionId,
        'operation_id': operationId,
        'generation': generation,
        'visible_us': now,
      });
      await boundary?.call('pointer_written');
      return OwnerRevisionPublication(
        revisionId: revisionId,
        generation: generation,
        recordCount: plan.records.length,
        assetCount: plan.assets.length,
        idempotent: false,
      );
    });
    await boundary?.call('published_response');
    return publication;
  }

  Future<OwnerRevisionPublication?> _publishedRetry(
    OwnerRevisionSnapshot snapshot,
    String revisionId,
    String operationId,
    _RevisionPlan plan,
  ) async {
    final rows = await ledger.db.query(
      'import_visibility',
      where: 'source_namespace=?',
      whereArgs: [snapshot.importNamespace],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row['fingerprint'] != snapshot.importFingerprint ||
        row['owner_uuid'] != snapshot.ownerUuid ||
        row['revision_id'] != revisionId ||
        row['operation_id'] != operationId) {
      throw const ImportFailure('import_visibility_conflict');
    }
    final revisionRows = await ledger.db.query(
      'owner_revisions',
      where: 'revision_id=? AND owner_uuid=? AND state=?',
      whereArgs: [revisionId, snapshot.ownerUuid, 'published'],
    );
    final pointer = await _pointer(snapshot.ownerUuid);
    final visibleGeneration = row['generation'] as int;
    if (revisionRows.length != 1 ||
        pointer == null ||
        pointer.generation < visibleGeneration ||
        !await _isInActiveChain(
          snapshot.ownerUuid,
          pointer.revisionId,
          revisionId,
        )) {
      throw const ImportFailure('visible_revision_pointer_conflict');
    }
    return OwnerRevisionPublication(
      revisionId: revisionId,
      generation: visibleGeneration,
      recordCount: plan.records.length,
      assetCount: plan.assets.length,
      idempotent: true,
    );
  }

  Future<OwnerRevisionPointer?> activePointer(String ownerUuid) async {
    GpsOwner.account(ownerUuid);
    return _pointer(ownerUuid);
  }

  /// Returns rows only through the durable pointer; prepared/verified rows are
  /// deliberately not queryable through this visible read API.
  Future<List<OwnerRevisionVisibleRecord>> visibleRecords(
    LocalOwnerLease lease, {
    int limit = 200,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 1000 || offset < 0) {
      throw ArgumentError('Invalid owner revision page');
    }
    lease.requireCurrent();
    final ownerUuid = lease.owner.userId;
    if (ownerUuid == null || lease.owner.kind != GpsOwnerKind.account) {
      throw const ImportFailure('revision_owner_mismatch');
    }
    final pointer = await _pointer(ownerUuid);
    lease.requireCurrent();
    if (pointer == null) return const [];
    final revision = await ledger.db.query(
      'owner_revisions',
      where: 'revision_id=? AND owner_uuid=? AND state=?',
      whereArgs: [pointer.revisionId, ownerUuid, 'published'],
    );
    if (revision.length != 1) {
      throw const ImportFailure('visible_revision_invalid');
    }
    final rows = await ledger.db.query(
      'owner_revision_records',
      where: 'revision_id=?',
      whereArgs: [pointer.revisionId],
      orderBy: 'record_id',
      limit: limit,
      offset: offset,
    );
    lease.requireCurrent();
    return rows
        .map(
          (row) => OwnerRevisionVisibleRecord(
            group: row['group_name'] as String,
            logicalKey: row['logical_key'] as String,
            sourceIdentity: row['source_identity'] as String,
            payload: Uint8List.fromList(row['payload'] as Uint8List),
            sha256: row['content_sha256'] as String,
          ),
        )
        .toList(growable: false);
  }

  Future<OwnerRevisionPointer?> _pointer(
    String ownerUuid, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? ledger.db).query(
      'owner_revision_pointer',
      where: 'owner_uuid=?',
      whereArgs: [ownerUuid],
    );
    return rows.isEmpty ? null : OwnerRevisionPointer.fromRow(rows.single);
  }

  Future<bool> _isInActiveChain(
    String ownerUuid,
    String activeRevisionId,
    String soughtRevisionId, {
    DatabaseExecutor? executor,
  }) async {
    var current = activeRevisionId;
    final visited = <String>{};
    final query = executor ?? ledger.db;
    while (visited.length < 100000 && visited.add(current)) {
      if (current == soughtRevisionId) return true;
      final rows = await query.query(
        'owner_revisions',
        columns: ['base_revision_id'],
        where: 'revision_id=? AND owner_uuid=? AND state=?',
        whereArgs: [current, ownerUuid, 'published'],
      );
      if (rows.length != 1) return false;
      final parent = rows.single['base_revision_id'] as String?;
      if (parent == null) return false;
      current = parent;
    }
    return false;
  }

  String _revisionId(
    OwnerRevisionSnapshot snapshot,
    List<OwnerRevisionRecord> records,
  ) => _sha(
    utf8.encode(
      jsonEncode([
        'owner_revision_v1',
        snapshot.ownerUuid,
        snapshot.expectedBaseRevisionId,
        snapshot.sourceRevision,
        snapshot.sourceFingerprint,
        snapshot.importNamespace,
        snapshot.importFingerprint,
        _planFingerprint(_RevisionPlan(records, snapshot.assets)),
      ]),
    ),
  );

  String _planFingerprint(_RevisionPlan plan) => _sha(
    utf8.encode(
      jsonEncode([
        ...plan.records.map((r) => [r.id, r.sha256, r.origin.name]),
        ...plan.assets.map(
          (a) => [
            a.origin.name,
            a.sourceNamespace,
            a.id,
            a.sha256,
            a.bytes,
            a.relativePath,
          ],
        ),
      ]),
    ),
  );

  static bool _worldGroup(String group) => group.startsWith('my_world_');
  static bool _careerGroup(String group) =>
      group == 'career_totals' || group == 'career_contributions_v1';

  static String fingerprintSourceSnapshot(
    List<OwnerRevisionRecord> records,
    List<OwnerRevisionAsset> assets,
  ) => _sha(
    utf8.encode(
      jsonEncode([
        for (final record in [...records]..sort((a, b) => a.id.compareTo(b.id)))
          [record.id, record.sha256],
        for (final asset in [...assets]..sort((a, b) => a.id.compareTo(b.id)))
          [asset.id, asset.sha256, asset.bytes, asset.relativePath],
      ]),
    ),
  );
}

class _RevisionPlan {
  const _RevisionPlan(this.records, this.assets);
  final List<OwnerRevisionRecord> records;
  final List<OwnerRevisionAsset> assets;
}

class OwnerRevisionPointer {
  const OwnerRevisionPointer(this.ownerUuid, this.revisionId, this.generation);
  factory OwnerRevisionPointer.fromRow(Map<String, Object?> row) =>
      OwnerRevisionPointer(
        row['owner_uuid'] as String,
        row['revision_id'] as String,
        row['generation'] as int,
      );
  final String ownerUuid;
  final String revisionId;
  final int generation;
}

class OwnerRevisionVisibleRecord {
  const OwnerRevisionVisibleRecord({
    required this.group,
    required this.logicalKey,
    required this.sourceIdentity,
    required this.payload,
    required this.sha256,
  });
  final String group;
  final String logicalKey;
  final String sourceIdentity;
  final Uint8List payload;
  final String sha256;
}

String _sha(List<int> value) => sha256.convert(value).toString();
