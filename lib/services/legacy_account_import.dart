import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../config/local_ownership_gate.dart';
import '../models/drive_session.dart';
import '../features/drive_poster/poster_store.dart';
import 'gps_session_ownership.dart';
import 'owner_scoped_local_store.dart';
import 'local_owner_lifecycle.dart';
import 'legacy_owner_consent.dart';
import 'legacy_asset_transfer.dart';
import 'legacy_claim_ledger.dart';
import 'legacy_import_inventory.dart';

/// Import partitions are physically separate from live owner stores. There is
/// no production caller and no promotion of partial Hive writes into live boxes.
/// The single atomic visibility decision is the WAL/FULL completed ledger row.
class LegacyAccountImporter {
  LegacyAccountImporter({
    required this.gate,
    required this.ledger,
    required this.root,
    required this.disk,
    this.boundary,
    this.beforeFlush,
    this.onFileChunk,
  });
  final LocalOwnershipGate gate;
  final LegacyClaimLedger ledger;
  final Directory root;
  final ImportDisk disk;
  final Future<void> Function(String stage)? boundary;
  final Future<void> Function(String group)? beforeFlush;
  final Future<void> Function(int bytes)? onFileChunk;

  Future<Directory> _workspace(LegacyClaim claim) async {
    await OwnerAssetTransfer.noLinks(root.absolute.path);
    await root.create(recursive: true);
    final base = await root.resolveSymbolicLinks();
    final directory = Directory(
      '$base${Platform.pathSeparator}legacy_imports_v1'
      '${Platform.pathSeparator}${claim.operationId}',
    );
    await OwnerAssetTransfer.noLinks(directory.path);
    await directory.create(recursive: true);
    await disk.syncDirectory(root.parent);
    await disk.syncDirectory(root);
    await disk.syncDirectory(directory.parent);
    return directory;
  }

  void _enabled() {
    if (!gate.enabled) throw const ImportFailure('ownership_disabled');
  }

  static void _ownerEvidence(Object? existing, GpsOwner target) {
    if (existing == null ||
        existing == 'unassigned' ||
        existing == 'guest' ||
        existing == 'legacy_unassigned' ||
        existing == const GpsOwner.legacy().targetStore ||
        existing == const GpsOwner.guest().targetStore ||
        existing == target.userId ||
        existing == target.targetStore) {
      return;
    }
    throw const ImportFailure('embedded_owner_conflict');
  }

  Future<(Object, Object?)> _transform(
    LegacyImportSource source,
    ImportRecord record,
    LegacyImportInventory inventory,
    GpsOwner owner,
    Directory workspace,
  ) async {
    var key = record.key;
    var value = source.detached(record);
    final refs = LegacyImportSource.references(record.group, value);
    final paths = <String, String>{};
    final base = record.group == 'drive_posters'
        ? Directory('${source.documents.path}/posters')
        : source.documents;
    for (final field in refs.entries) {
      final original = await OwnerAssetTransfer.resolveSource(
        field.value,
        base,
        source.allowedFileRoots,
      );
      final found = inventory.assets.where((a) => a.sourcePath == original);
      if (found.length != 1) {
        throw const ImportFailure('asset_manifest_missing');
      }
      paths[field.key] = '${workspace.path}/${found.single.relativePath}';
    }
    if (value is DriveSession && paths.containsKey('mapImagePath')) {
      value.mapImagePath = paths['mapImagePath']!;
    } else if (record.group == 'drive_posters' && value is Map) {
      for (final pair in [
        ['fileName', 'exportedPosterPath'],
        ['backgroundFileName', 'backgroundReference'],
      ]) {
        if (pair.every(paths.containsKey) &&
            paths[pair.first] != paths[pair.last]) {
          throw const ImportFailure('poster_alias_conflict');
        }
      }
      for (final field in paths.entries) {
        value[field.key] = field.value;
      }
    } else if (record.group == 'my_world_source_snapshots_v1' && value is Map) {
      final bundle = Map<String, dynamic>.from(jsonDecode(value['payload']));
      _ownerEvidence(bundle['ownerScope'], owner);
      bundle['ownerScope'] = owner.targetStore;
      if (paths.containsKey('payload.mapImagePath')) {
        (bundle['drive'] as Map)['mapImagePath'] =
            paths['payload.mapImagePath'];
      }
      value['payload'] = jsonEncode(bundle);
    } else if (record.group == 'career_contributions_v1' && value is String) {
      final contribution = jsonDecode(value) as Map;
      final bundle = contribution['bundle'];
      if (bundle is Map) {
        _ownerEvidence(bundle['ownerScope'], owner);
        bundle['ownerScope'] = owner.targetStore;
        if (paths.containsKey('bundle.mapImagePath')) {
          (bundle['drive'] as Map)['mapImagePath'] =
              paths['bundle.mapImagePath'];
        }
        value = jsonEncode(contribution);
      }
    } else if (record.group == 'planet_segment_outbox_v1' && value is String) {
      final row = jsonDecode(value) as Map;
      final priorOwner = row['owner'];
      _ownerEvidence(priorOwner, owner);
      if (row['state'] == 'accepted' &&
          priorOwner != owner.userId &&
          priorOwner != owner.targetStore) {
        throw const ImportFailure('accepted_publish_owner_unproven');
      }
      row['owner'] = owner.targetStore;
      key = jsonEncode([owner.targetStore, (row['payload'] as Map)['id']]);
      value = jsonEncode(
        row,
      ); // Payload/segment ID/remote receipt are unchanged.
    } else if (record.group == 'local_publish_state_v1' && value is Map) {
      for (final field in ['owner', 'ownerScope', 'user_id']) {
        if (value.containsKey(field)) _ownerEvidence(value[field], owner);
      }
      // Preserve authoritative server IDs/status verbatim. This is a private
      // read-only evidence copy, not a request to relabel any remote publication.
    }
    return (key, value);
  }

  Future<VerifiedLegacyImport> import({
    required LegacyImportSource source,
    required LegacyOwnerConsent consent,
  }) async {
    _enabled();
    consent.verify(consent.fingerprint);
    final inventory = await source.survey();
    consent.verify(inventory.fingerprint);
    validateImportRelations(inventory.records, source.read);
    final claim = await ledger.reserve(
      inventory.namespace,
      inventory.fingerprint,
      consent.target,
    );
    await boundary?.call('reserved');
    if (claim.completed) {
      return openVerified(namespace: claim.namespace, lease: consent.lease);
    }
    await ledger.attempt(claim);
    await ledger.commit(
      claim,
      (tx) async {
        consent.verify(inventory.fingerprint);
        final workspace = await _workspace(claim);
        final assets = OwnerAssetTransfer(
          root: workspace,
          disk: disk,
          onChunk: (bytes) async {
            consent.verify(inventory.fingerprint);
            await onFileChunk?.call(bytes);
          },
        );
        await assets.capacity(inventory.requiredBytes);
        await boundary?.call('capacity_verified');
        OwnerScopedLocalStore? store;
        final targets = <ImportRecord>[];
        try {
          store = await OwnerScopedLocalStore.open(
            root: workspace.path,
            owner: claim.owner,
            beforeFlush: beforeFlush,
          );
          for (final r in inventory.records) {
            consent.verify(inventory.fingerprint);
            final transformed = await _transform(
              source,
              r,
              inventory,
              claim.owner,
              workspace,
            );
            final bytes = store.encode(transformed.$2);
            final hash = sha256.convert(bytes).toString();
            final existing = store.read(claim.owner, r.group, transformed.$1);
            if (existing != null &&
                sha256.convert(store.encode(existing)).toString() != hash) {
              throw const ImportFailure('target_record_conflict');
            }
            await store.put(
              claim.owner,
              r.group,
              transformed.$1,
              transformed.$2,
            );
            targets.add(
              ImportRecord(r.group, transformed.$1, hash, bytes.length),
            );
            await tx.insert('record_receipts', {
              'operation_id': claim.operationId,
              'source_group': r.group,
              'source_key': jsonEncode(r.key),
              'target_key': jsonEncode(transformed.$1),
              'source_sha': r.hash,
              'target_sha': hash,
            });
            await boundary?.call('record_flushed');
          }
          for (final asset in inventory.assets) {
            consent.verify(inventory.fingerprint);
            await assets.copy(asset);
            await tx.insert('asset_receipts', {
              'operation_id': claim.operationId,
              'asset_id': asset.id,
              'sha256': asset.hash,
              'bytes': asset.bytes,
              'relative_path': asset.relativePath,
            });
            await boundary?.call('file_flushed');
          }
          await store.flush(claim.owner);
          await store.close();
          store = null;
          // Disk-backed reopen, not just the cache of the just-written Hive boxes.
          store = await OwnerScopedLocalStore.open(
            root: workspace.path,
            owner: claim.owner,
          );
          _verifyRecords(store, claim.owner, targets, inventory.counts);
          validateImportRelations(
            targets,
            (g, k) => store!.read(claim.owner, g, k),
          );
          for (final asset in inventory.assets) {
            await assets.verify(asset);
          }
          if ((await source.survey()).fingerprint != inventory.fingerprint) {
            throw const ImportFailure('source_changed_during_import');
          }
          consent.verify(inventory.fingerprint);
          await disk.syncDirectory(Directory(store.path));
          await disk.syncDirectory(Directory(store.path).parent);
          await disk.syncDirectory(workspace);
          await boundary?.call('verified');
          return {
            'version': 1,
            'fingerprint': inventory.fingerprint,
            'recordCount': targets.length,
            'fileCount': inventory.assets.length,
            'counts': inventory.counts,
            'activation': 'completed_partition_only',
          };
        } finally {
          await store?.close();
        }
      },
      beforeCommit: () async {
        consent.verify(inventory.fingerprint);
        await boundary?.call('before_ledger_commit');
        consent.verify(inventory.fingerprint);
      },
    );
    await boundary?.call('ledger_committed');
    return openVerified(namespace: inventory.namespace, lease: consent.lease);
  }

  static void _verifyRecords(
    OwnerScopedLocalStore store,
    GpsOwner owner,
    List<ImportRecord> targets,
    Map<String, int> counts,
  ) {
    for (final group in OwnerScopedLocalStore.groups) {
      final expected = targets
          .where((r) => r.group == group)
          .map((r) => r.key)
          .toList();
      if (jsonEncode(store.keys(owner, group)) != jsonEncode(expected) ||
          expected.length != (counts[group] ?? 0)) {
        throw const ImportFailure('target_record_count_or_order_mismatch');
      }
    }
    for (final r in targets) {
      if (sha256
              .convert(store.encode(store.read(owner, r.group, r.key)))
              .toString() !=
          r.hash) {
        throw const ImportFailure('target_record_hash_mismatch');
      }
    }
  }

  Future<VerifiedLegacyImport> openVerified({
    required String namespace,
    required LocalOwnerLease lease,
  }) async {
    _enabled();
    lease.requireCurrent();
    final claim = await ledger.get(namespace);
    if (claim == null ||
        !claim.completed ||
        claim.owner.targetStore != lease.owner.targetStore) {
      throw const ImportFailure('import_not_visible');
    }
    final workspace = await _workspace(claim);
    final stored = await ledger.db.query(
      'record_receipts',
      where: 'operation_id=?',
      whereArgs: [claim.operationId],
      orderBy: 'rowid',
    );
    final rows = stored
        .map(
          (r) => ImportRecord(
            r['source_group'] as String,
            jsonDecode(r['target_key'] as String) as Object,
            r['target_sha'] as String,
            0,
          ),
        )
        .toList();
    final savedAssets = await ledger.db.query(
      'asset_receipts',
      where: 'operation_id=?',
      whereArgs: [claim.operationId],
    );
    final files = savedAssets
        .map(
          (r) => ImportAsset(
            id: r['asset_id'] as String,
            sourcePath: '',
            hash: r['sha256'] as String,
            bytes: r['bytes'] as int,
            extension: (r['relative_path'] as String).split('.').last,
          ),
        )
        .toList();
    final evidence = jsonDecode(claim.row['evidence'] as String) as Map;
    if (evidence['version'] != 1 ||
        evidence['fingerprint'] != claim.fingerprint ||
        evidence['recordCount'] != rows.length ||
        evidence['fileCount'] != files.length) {
      throw const ImportFailure('completion_evidence_invalid');
    }
    for (var i = 0; i < files.length; i++) {
      if (files[i].relativePath != savedAssets[i]['relative_path'] ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(files[i].id) ||
          !RegExp(r'^[a-z0-9]{1,8}$').hasMatch(files[i].extension)) {
        throw const ImportFailure('asset_evidence_invalid');
      }
    }
    final counts = (evidence['counts'] as Map).map(
      (k, v) => MapEntry('$k', v as int),
    );
    final store = await OwnerScopedLocalStore.open(
      root: workspace.path,
      owner: claim.owner,
    );
    try {
      _verifyRecords(store, claim.owner, rows, counts);
      validateImportRelations(rows, (g, k) => store.read(claim.owner, g, k));
      final copier = OwnerAssetTransfer(root: workspace, disk: disk);
      for (final file in files) {
        await copier.verify(file);
      }
      lease.requireCurrent();
      return VerifiedLegacyImport._(store, lease, workspace, files, copier);
    } catch (_) {
      await store.close();
      rethrow;
    }
  }
}

/// Read-only scoped partition; no raw Hive boxes, partial data, network gateway
/// or mutation methods. Phase 5C.2 may integrate completed partitions as inputs.
class VerifiedLegacyImport {
  VerifiedLegacyImport._(
    this._store,
    this._lease,
    this._workspace,
    this._assets,
    this._copier,
  );
  final OwnerScopedLocalStore _store;
  final LocalOwnerLease _lease;
  final Directory _workspace;
  final List<ImportAsset> _assets;
  final OwnerAssetTransfer _copier;
  bool _closed = false;
  void _check() {
    if (_closed) throw const ImportFailure('import_reader_closed');
    _lease.requireCurrent();
  }

  T? read<T>(String group, Object key) {
    _check();
    return _store.read<T>(_lease.owner, group, key);
  }

  List<Object> keys(String group) {
    _check();
    return _store.keys(_lease.owner, group);
  }

  Future<File> file(String reference) async {
    _check();
    final known = _assets.where(
      (a) => '${_workspace.path}/${a.relativePath}' == reference,
    );
    if (known.length != 1) {
      throw const ImportFailure('file_not_in_verified_manifest');
    }
    await _copier.verify(known.single);
    _check();
    return _copier.fileFor(known.single);
  }

  Future<File> posterFile(String id) async {
    final row = read<Map>('drive_posters', id);
    if (row == null) throw const ImportFailure('poster_missing');
    return file(SavedDrivePoster.fromMap(row).fileName);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _store.close();
  }
}
