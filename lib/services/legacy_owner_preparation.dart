// Same Hive 2.x binary registry seam as OwnerScopedLocalStore. This avoids
// lossy JSON projections when preserving legacy model fields.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import '../models/drive_session.dart';
import '../models/canonical_telemetry_point.dart';
import '../models/drive_score_record.dart';
import '../features/my_world/models/world_index_snapshot.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/repositories/world_source_snapshot_repository.dart';
import 'local_source_bundle.dart';
import 'gps_session_ownership.dart';
import 'owner_scoped_local_store.dart';

/// Detached inventory. Capturing is read-only; it never opens, closes, flushes
/// or mutates source boxes. Caller must enumerate ALL existing personal boxes.
class LegacyLocalInventory {
  LegacyLocalInventory._(this.rows);
  final Map<String, Map<Object, Uint8List>> rows;
  factory LegacyLocalInventory.capture(HiveImpl hive, Iterable<String> names) {
    final included = names.toSet();
    if (OwnerScopedLocalStore.groups.any(
      (name) => hive.isBoxOpen(name) && !included.contains(name),
    )) {
      throw StateError(
        'Incomplete open-box inventory requires explicit review',
      );
    }
    final rows = <String, Map<Object, Uint8List>>{};
    for (final name in included) {
      if (!OwnerScopedLocalStore.groups.contains(name)) {
        throw StateError('Unrecognized source group requires explicit review');
      }
      final box = OwnerScopedLocalStore.registeredBox(hive, name);
      rows[name] = Map.unmodifiable({
        for (final key in box.keys)
          key as Object: (BinaryWriterImpl(
            hive,
          )..write(box.get(key))).toBytes().asUnmodifiableView(),
      });
    }
    return LegacyLocalInventory._(Map.unmodifiable(rows));
  }
  String get fingerprint {
    final records = <String>[];
    for (final group in rows.entries) {
      for (final row in group.value.entries) {
        records.add(jsonEncode([group.key, row.key, base64Encode(row.value)]));
      }
      records.add(jsonEncode([group.key, 'count', group.value.length]));
    }
    records.sort();
    return sha256.convert(utf8.encode(jsonEncode(records))).toString();
  }
}

/// Copy-only quarantine preparation. Does NOT activate repositories, relabel
/// embedded IDs/owners, authorize account adoption, or delete old records.
/// A new source fingerprint requires a separate explicit preparation decision.
class LegacyOwnerPreparation {
  LegacyOwnerPreparation(this.target, {this.boundary});
  final OwnerScopedLocalStore target;

  /// Synthetic fault seam after durability boundaries, not a power-loss test.
  final Future<void> Function(String stage)? boundary;
  static final Map<String, Future<void>> _queues = {};
  Future<void> prepare({
    required String sourceId,
    required Future<LegacyLocalInventory> Function() readSource,
  }) {
    final next = (_queues[target.path] ?? Future<void>.value()).then(
      (_) => _prepare(sourceId: sourceId, readSource: readSource),
    );
    _queues[target.path] = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _prepare({
    required String sourceId,
    required Future<LegacyLocalInventory> Function() readSource,
  }) async {
    if (sourceId.isEmpty ||
        target.owner.kind != GpsOwnerKind.legacyUnassigned) {
      throw StateError('Unproven ownership can only enter legacy quarantine');
    }
    final source = await readSource();
    final key = 'legacy_prepare_v1:${sha256.convert(utf8.encode(sourceId))}';
    final old = target.preparation(key);
    if (old != null && old['fingerprint'] != source.fingerprint) {
      throw StateError('Source changed; explicit review required');
    }
    final manifest = <String, Object?>{
      'version': 1,
      'sourceId': sourceId,
      'scope': target.scope,
      'fingerprint': source.fingerprint,
      'state': 'copying',
      'counts': {
        for (final group in source.rows.entries) group.key: group.value.length,
      },
      'activationAllowed': false,
      'records': {
        for (final group in source.rows.entries)
          group.key: [
            for (final row in group.value.entries)
              {'key': row.key, 'sha256': sha256.convert(row.value).toString()},
          ],
      },
    };
    await target.manifest(key, manifest);
    await boundary?.call('intent_flushed');
    for (final group in source.rows.entries) {
      for (final entry in group.value.entries) {
        final value = target.decode(entry.value);
        final existing = target.read(target.owner, group.key, entry.key);
        if (existing != null &&
            base64Encode(target.encode(existing)) !=
                base64Encode(entry.value)) {
          throw StateError('Legacy destination content conflict');
        }
        await target.put(target.owner, group.key, entry.key, value);
        await boundary?.call('record_flushed');
      }
    }
    await target.flush(target.owner);
    await boundary?.call('all_flushed');
    // Read-back compares every adapter field, including geometry, names,
    // scores, contribution basis, pending jobs, tombstones and pointer history.
    for (final group in source.rows.entries) {
      if (target.keys(target.owner, group.key).length != group.value.length) {
        throw StateError('Legacy count mismatch');
      }
      for (final row in group.value.entries) {
        final value = target.read(target.owner, group.key, row.key);
        if (base64Encode(target.encode(value)) != base64Encode(row.value)) {
          throw StateError('Legacy content mismatch');
        }
        if (value is DriveSession && value.id != row.key) {
          throw StateError('Drive identity mismatch');
        }
        if (value is DriveTelemetryRecord && value.driveSessionId != row.key) {
          throw StateError('Telemetry identity mismatch');
        }
        if (value is DriveScoreRecord &&
            row.key != '${value.driveId}:v${value.algorithmVersion}') {
          throw StateError('Score identity mismatch');
        }
        if (value is WorldIndexPointer &&
            target.read<WorldIndexSnapshot>(
                  target.owner,
                  'my_world_index_snapshots',
                  value.activeGeneration,
                ) ==
                null) {
          throw StateError('World pointer relation missing');
        }
      }
    }
    if ((await readSource()).fingerprint != source.fingerprint) {
      throw StateError('Source changed during preparation');
    }
    await boundary?.call('verified');
    final pointer = target.read<WorldIndexPointer>(
      target.owner,
      'my_world_index_metadata',
      'active_generation',
    );
    if (pointer != null) {
      final snapshot = target.read<WorldIndexSnapshot>(
        target.owner,
        'my_world_index_snapshots',
        pointer.activeGeneration,
      )!;
      final roads = target
          .keys(target.owner, 'my_world_validated_roads')
          .map(
            (key) => target.read<ValidatedRoad>(
              target.owner,
              'my_world_validated_roads',
              key,
            )!,
          )
          .toList();
      final sources = <LocalSourceBundle>[];
      for (final id in target.keys(
        target.owner,
        WorldSourceSnapshotRepository.boxName,
      )) {
        final raw = target.read<Map>(
          target.owner,
          WorldSourceSnapshotRepository.boxName,
          id,
        )!;
        if (raw['ready'] == true) {
          final source = LocalSourceBundle.fromMap(
            jsonDecode(raw['payload'] as String),
          );
          source.validate();
          sources.add(source);
        }
      }
      for (final trace in snapshot.traces) {
        final candidates = [...roads, ...sources.expand((s) => s.roads)].where(
          (r) =>
              r.id == trace.validatedRoadId &&
              r.driveSessionId == trace.sourceDriveSessionId,
        );
        if (!candidates.any(
          (r) => r.sections.any((s) => s.id == trace.matchedSectionId),
        )) {
          throw StateError('Active World source/road/section relation missing');
        }
      }
    }
    await target.manifest(key, {...manifest, 'state': 'verified_quarantine'});
  }
}
