// Keep the existing Hive binary registry seam; do not project old adapter fields
// into a lossy replacement DriveSession/RoutePoint JSON model.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import '../models/drive_session.dart';
import '../models/canonical_telemetry_point.dart';
import '../models/drive_score_record.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/models/world_index_snapshot.dart';
import '../features/my_world/models/world_pending_job.dart';
import '../features/my_world/models/world_processing.dart';
import 'local_source_bundle.dart';
import 'owner_scoped_local_store.dart';
import 'legacy_asset_transfer.dart';

class ImportRecord {
  const ImportRecord(this.group, this.key, this.hash, this.bytes);
  final String group;
  final Object key;
  final String hash;
  final int bytes;
  String get identity => jsonEncode([group, key]);
}

class LegacyImportInventory {
  LegacyImportInventory(
    this.namespace,
    this.fingerprint,
    this.records,
    this.assets,
    this.counts,
  );
  final String namespace;
  final String fingerprint;
  final List<ImportRecord> records; // Descriptors only, never record payloads.
  final List<ImportAsset> assets;
  final Map<String, int> counts;
  int get requiredBytes {
    final data =
        records.fold<int>(0, (n, r) => n + r.bytes) * 3 +
        assets.fold<int>(0, (n, f) => n + f.bytes);
    return data + (data ~/ 10 > 8 * 1024 * 1024 ? data ~/ 10 : 8 * 1024 * 1024);
  }
}

/// Explicit read-only source. No global Hive/Auth, implicit box opening,
/// migration, source flush or source deletion. Complete known boxes are required;
/// unknown on-disk boxes and unrecognized file references fail closed.
class LegacyImportSource {
  LegacyImportSource({
    required this.hive,
    required this.hiveRoot,
    required this.documents,
    required this.allowedFileRoots,
    required this.groups,
    this.maxRecordBytes = 64 * 1024 * 1024,
  });
  final HiveImpl hive;
  final Directory hiveRoot;
  final Directory documents;
  final List<Directory> allowedFileRoots;
  final List<String> groups;
  final int maxRecordBytes;
  int largestRecord = 0;

  Uint8List encode(Object? value) =>
      (BinaryWriterImpl(hive)..write(value)).toBytes();
  Object? read(String group, Object key) =>
      OwnerScopedLocalStore.registeredBox(hive, group).get(key);
  Object? detached(ImportRecord record) {
    final bytes = encode(read(record.group, record.key));
    if (sha256.convert(bytes).toString() != record.hash) {
      throw const ImportFailure('source_record_changed');
    }
    return BinaryReaderImpl(bytes, hive).read();
  }

  static const _fileFields = {
    'mapImagePath',
    'fileName',
    'exportedPosterPath',
    'backgroundFileName',
    'backgroundReference',
  };
  static void _unknownFileFields(Object? value) {
    if (value is TypedData) return;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if ((key.endsWith('Path') || key.endsWith('FileName')) &&
            !_fileFields.contains(key) &&
            entry.value is String &&
            (entry.value as String).isNotEmpty) {
          throw const ImportFailure('unrecognized_file_reference');
        }
        if (entry.value is Map || entry.value is List) {
          _unknownFileFields(entry.value);
        }
      }
    } else if (value is List) {
      for (final item in value) {
        if (item is Map || item is List) _unknownFileFields(item);
      }
    }
  }

  /// Only the actual file-bearing schemas are accepted. Similar-looking fields
  /// in unknown metadata are not silently considered copied.
  static Map<String, String> references(String group, Object? value) {
    if (value is DriveSession) {
      return value.mapImagePath.isEmpty
          ? {}
          : {'mapImagePath': value.mapImagePath};
    }
    if (group == 'drive_posters') {
      if (value is! Map ||
          value['id'] is! String ||
          value['driveId'] is! String ||
          ![
            'fileName',
            'exportedPosterPath',
          ].any((k) => value[k] is String && (value[k] as String).isNotEmpty)) {
        throw const ImportFailure('invalid_poster_metadata');
      }
      _unknownFileFields(value);
      final result = <String, String>{};
      for (final field in _fileFields.where((f) => f != 'mapImagePath')) {
        final reference = value[field];
        if (reference is String && reference.isNotEmpty) {
          result[field] = reference;
        }
      }
      // Saved backgrounds, whatever their source, are user data. The PNG alone
      // is not proof the editable user-selected background survived.
      if (value['backgroundSourceType'] != null &&
          !result.keys.any((k) => k.startsWith('background'))) {
        throw const ImportFailure('poster_background_reference_missing');
      }
      return result;
    }
    if (group == 'my_world_source_snapshots_v1' &&
        value is Map &&
        value['payload'] is String) {
      final payload = jsonDecode(value['payload'] as String) as Map;
      _unknownFileFields(payload);
      final path = (payload['drive'] as Map)['mapImagePath'];
      return path is String && path.isNotEmpty
          ? {'payload.mapImagePath': path}
          : {};
    }
    if (group == 'career_contributions_v1' && value is String) {
      final payload = jsonDecode(value) as Map;
      _unknownFileFields(payload);
      final bundle = payload['bundle'];
      final path = bundle is Map
          ? (bundle['drive'] as Map)['mapImagePath']
          : null;
      return path is String && path.isNotEmpty
          ? {'bundle.mapImagePath': path}
          : {};
    }
    _unknownFileFields(value);
    if (value is Map && value.keys.any((k) => _fileFields.contains(k))) {
      throw const ImportFailure('unrecognized_file_schema');
    }
    return {};
  }

  Future<LegacyImportInventory> survey() async {
    await OwnerAssetTransfer.noLinks(hiveRoot.absolute.path);
    final canonical = await hiveRoot.resolveSymbolicLinks();
    if (groups.toSet().length != groups.length ||
        groups.any(
          (g) =>
              !OwnerScopedLocalStore.groups.contains(g) || !hive.isBoxOpen(g),
        )) {
      throw const ImportFailure('incomplete_box_inventory');
    }
    for (final name in OwnerScopedLocalStore.groups) {
      if (hive.isBoxOpen(name) && !groups.contains(name)) {
        throw const ImportFailure('incomplete_box_inventory');
      }
    }
    await for (final entry in hiveRoot.list(followLinks: false)) {
      if (entry.path.endsWith('.hive')) {
        final name = entry.path
            .split(Platform.pathSeparator)
            .last
            .replaceFirst('.hive', '');
        if (name == 'owner_manifest_v1') {
          // 5B quarantine lacks authenticated original-directory provenance.
          // Claiming its path as a second source could bypass the original
          // namespace reservation. Only the original legacy source is allowed.
          throw const ImportFailure('source_origin_unproven');
        } else if (!groups.contains(name)) {
          throw const ImportFailure('unreviewed_box_on_disk');
        }
      }
    }
    final records = <ImportRecord>[];
    final counts = <String, int>{};
    final byPath = <String, ImportAsset>{};
    Future<void> asset(String reference, Directory base) async {
      final path = await OwnerAssetTransfer.resolveSource(
        reference,
        base,
        allowedFileRoots,
      );
      if (byPath.containsKey(path)) return;
      final content = await OwnerAssetTransfer.hashFile(File(path));
      if (content.$2 <= 0) throw const ImportFailure('source_file_empty');
      final extension = path.split('.').last.toLowerCase();
      byPath[path] = ImportAsset(
        id: sha256
            .convert(utf8.encode(jsonEncode(['legacy_asset_v1', path])))
            .toString(),
        sourcePath: path,
        hash: content.$1,
        bytes: content.$2,
        extension: RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)
            ? extension
            : 'bin',
      );
    }

    final orderedGroups = [...groups]..sort();
    for (final group in orderedGroups) {
      final box = OwnerScopedLocalStore.registeredBox(hive, group);
      counts[group] = box.length;
      // Retain the source Hive iterator order, without imposing a new ordering.
      for (final key in box.keys.toList()) {
        final value = box.get(key);
        final bytes = encode(value);
        largestRecord = bytes.length > largestRecord
            ? bytes.length
            : largestRecord;
        if (bytes.length > maxRecordBytes) {
          throw const ImportFailure('record_too_large');
        }
        records.add(
          ImportRecord(
            group,
            key as Object,
            sha256.convert(bytes).toString(),
            bytes.length,
          ),
        );
        final base = group == 'drive_posters'
            ? Directory('${documents.path}/posters')
            : documents;
        for (final reference in references(group, value).values) {
          await asset(reference, base);
        }
      }
    }
    // Unreferenced files in the known durable poster directory are retained as
    // private orphan assets, not silently discarded or reattached to a drive.
    final posterDirectory = Directory('${documents.path}/posters');
    if (await posterDirectory.exists()) {
      await OwnerAssetTransfer.noLinks(posterDirectory.path);
      await for (final entry in posterDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is Link) throw const ImportFailure('unsafe_symlink');
        if (entry is File &&
            !entry.path.endsWith('.tmp') &&
            !entry.path.endsWith('.part')) {
          await asset(entry.absolute.path, documents);
        }
      }
    }
    final assets = byPath.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final sink = ImportDigestSink();
    final hash = sha256.startChunkedConversion(sink);
    hash.add(utf8.encode(jsonEncode(['legacy_inventory_v1', counts])));
    for (final r in records) {
      hash.add(utf8.encode(jsonEncode([r.group, r.key, r.hash, r.bytes])));
    }
    for (final a in assets) {
      hash.add(utf8.encode(jsonEncode(a.evidence)));
    }
    hash.close();
    return LegacyImportInventory(
      'legacy_namespace_v1:${sha256.convert(utf8.encode(canonical))}',
      sink.digest.toString(),
      List.unmodifiable(records),
      List.unmodifiable(assets),
      Map.unmodifiable(counts),
    );
  }
}

/// Validate persisted relationships without keeping every geometry/telemetry
/// payload in RAM and without recomputing score, Career or World.
void validateImportRelations(
  List<ImportRecord> records,
  Object? Function(String, Object) read,
) {
  final ids = <String>{};
  final roads = <String, (String, Set<String>)>{};
  final rowIds = <String, Set<Object>>{};
  for (final r in records) {
    (rowIds[r.group] ??= {}).add(r.key);
  }
  void road(ValidatedRoad value) {
    final prior = roads[value.id];
    if (prior != null && prior.$1 != value.driveSessionId) {
      throw const ImportFailure('road_identity_conflict');
    }
    roads[value.id] = (
      value.driveSessionId,
      {...?prior?.$2, ...value.sections.map((s) => s.id)},
    );
  }

  for (final r in records) {
    final value = read(r.group, r.key);
    if (value is DriveSession) {
      if (value.id != r.key) {
        throw const ImportFailure('drive_identity_mismatch');
      }
      ids.add(value.id);
    }
    if (value is ValidatedRoad) {
      if (value.id != r.key) {
        throw const ImportFailure('road_identity_mismatch');
      }
      road(value);
    }
    Map? bundle;
    if (r.group == 'my_world_source_snapshots_v1' && value is Map) {
      if (value['version'] != 1 || value['payload'] is! String) {
        throw const ImportFailure('invalid_world_source');
      }
      bundle = jsonDecode(value['payload']);
    } else if (r.group == 'career_contributions_v1' &&
        r.key is String &&
        (r.key as String).startsWith('drive:') &&
        value is String) {
      final contribution = jsonDecode(value) as Map;
      if (contribution['version'] != 1) {
        throw const ImportFailure('invalid_career_contribution');
      }
      bundle = contribution['bundle'] as Map;
    }
    if (bundle != null) {
      final source = LocalSourceBundle.fromMap(
        Map<String, dynamic>.from(bundle),
      );
      source.validate();
      if (r.key != source.drive.id && r.key != 'drive:${source.drive.id}') {
        throw const ImportFailure('bundle_identity_mismatch');
      }
      ids.add(source.drive.id);
      for (final value in source.roads) {
        road(value);
      }
    }
  }
  for (final r in records) {
    final value = read(r.group, r.key);
    if (value is DriveTelemetryRecord &&
        (value.driveSessionId != r.key ||
            !ids.contains(value.driveSessionId))) {
      throw const ImportFailure('telemetry_relation_missing');
    }
    if (value is DriveScoreRecord &&
        (r.key != '${value.driveId}:v${value.algorithmVersion}' ||
            !ids.contains(value.driveId))) {
      throw const ImportFailure('score_relation_missing');
    }
    if (value is WorldIndexPointer &&
        !((rowIds['my_world_index_snapshots'] ?? {}).contains(
          value.activeGeneration,
        ))) {
      throw const ImportFailure('world_pointer_relation_missing');
    }
    if (value is WorldIndexSnapshot) {
      if (value.generation != r.key) {
        throw const ImportFailure('generation_identity_mismatch');
      }
      for (final t in value.traces) {
        final validated = roads[t.validatedRoadId];
        if (!ids.contains(t.sourceDriveSessionId) ||
            validated == null ||
            validated.$1 != t.sourceDriveSessionId ||
            !validated.$2.contains(t.matchedSectionId) ||
            !t.startOffsetMeters.isFinite ||
            !t.endOffsetMeters.isFinite ||
            t.startOffsetMeters >= t.endOffsetMeters) {
          throw const ImportFailure('world_trace_relation_missing');
        }
      }
    }
    if (value is WorldPendingJob &&
        (r.key != value.id || !ids.contains(value.driveSessionId))) {
      throw const ImportFailure('pending_job_relation_missing');
    }
    if (value is WorldDriveProcessingRecord &&
        (r.key != value.driveSessionId ||
            !ids.contains(value.driveSessionId) ||
            (value.validatedRoadId != null &&
                !roads.containsKey(value.validatedRoadId)))) {
      throw const ImportFailure('processing_relation_missing');
    }
    if (r.group == 'drive_posters' &&
        (value is! Map ||
            value['id'] != r.key ||
            !ids.contains(value['driveId']))) {
      throw const ImportFailure('poster_drive_relation_missing');
    }
    if (r.group == 'planet_segment_outbox_v1') {
      final entry = jsonDecode(value as String) as Map;
      final key = jsonDecode(r.key as String) as List;
      final payload = entry['payload'] as Map;
      if (entry['version'] != 1 ||
          key.length != 2 ||
          key[0] != entry['owner'] ||
          key[1] != payload['id'] ||
          !ids.contains(payload['sourceDriveId'])) {
        throw const ImportFailure('planet_outbox_relation_missing');
      }
    }
  }
}
