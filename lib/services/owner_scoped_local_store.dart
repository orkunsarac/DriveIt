// Hive 2.x has no public independent-registry/binary-clone factory. Confine the
// compatibility seam here; upgrades must pass binary and namespace tests.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'local_source_writer_fence.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import '../models/drive_session.dart';
import '../models/route_point.dart';
import '../models/canonical_telemetry_point.dart';
import '../models/drive_score_record.dart';
import '../features/my_world/persistence/my_world_hive.dart';
import 'drive_telemetry_storage_service.dart';
import 'drive_score_storage_service.dart';
import 'gps_session_ownership.dart';
import 'career_contribution_repository.dart';
import 'local_source_bundle.dart';
import '../features/my_world/repositories/world_source_snapshot_repository.dart';
import '../features/world_publish/segments/planet_segment_outbox.dart';
import '../features/world_publish/segments/planet_segment.dart';
import '../features/my_world/repositories/hive_my_world_index_repository.dart';
import '../features/my_world/repositories/hive_my_world_repository.dart';
import '../features/my_world/models/world_index_snapshot.dart';
import '../features/my_world/models/active_world_trace.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/models/world_pending_job.dart';
import '../features/my_world/models/world_processing.dart';
import 'local_lifecycle_journal.dart';
import 'career_statistics_service.dart';
import '../features/drive_poster/poster_store.dart';

/// Explicit opt-in only. No global Hive, Auth, bootstrap or task subscriptions.
/// A separate Hive instance prevents asynchronous work from following a mutable
/// global directory. Existing adapter IDs and wire representations are reused.
class OwnerScopedLocalStore {
  OwnerScopedLocalStore._(this.owner, this._hive, this.path, this.beforeFlush);
  final GpsOwner owner;
  final HiveImpl _hive;
  final String path;

  /// Controlled durability fault seam. Never installed by production bootstrap.
  final Future<void> Function(String group)? beforeFlush;
  String get scope => owner.targetStore;
  static const groups = <String>[
    'drives',
    'drive_telemetry',
    'drive_scores',
    'drive_names',
    'drive_details_v1',
    'drive_posters',
    'career_totals',
    'career_contributions_v1',
    'symbolic_routes',
    'profile',
    'my_world_validated_roads',
    'my_world_processing',
    'my_world_pending_jobs',
    'my_world_index_snapshots',
    'my_world_index_metadata',
    'my_world_source_snapshots_v1',
    'local_lifecycle_v1',
    'my_world_settings',
    'planet_segment_outbox_v1',
    'local_publish_state_v1',
    'derived_cache_v1',
  ];
  static const _manifestBox = 'owner_manifest_v1';

  static void register(HiveImpl hive) {
    hive.registerAdapter(DriveSessionAdapter());
    hive.registerAdapter(RoutePointAdapter());
    DriveTelemetryHive.registerAdapters(hive);
    DriveScoreHive.registerAdapters(hive);
    MyWorldHive.registerAdapters(hive);
  }

  static Future<OwnerScopedLocalStore> open({
    required String root,
    required GpsOwner owner,
    Future<void> Function(String group)? beforeFlush,
  }) async {
    final name = sha256.convert(utf8.encode(owner.targetStore)).toString();
    final directory = Directory(
      '$root${Platform.pathSeparator}owner_stores_v1'
      '${Platform.pathSeparator}$name',
    );
    await directory.create(recursive: true);
    final hadData = directory.listSync().any(
      (f) => f.path.endsWith('.hive') && !f.path.endsWith('$_manifestBox.hive'),
    );
    final hive = HiveImpl()..init(directory.path);
    register(hive);
    try {
      final marker = await hive.openBox<dynamic>(_manifestBox);
      final saved = marker.get('identity');
      final expected = {'version': 1, 'scope': owner.targetStore};
      if ((saved == null && hadData) ||
          (saved != null && jsonEncode(saved) != jsonEncode(expected))) {
        throw StateError('Local namespace identity conflict');
      }
      if (saved == null) await marker.put('identity', expected);
      await marker.flush();
      await hive.openBox<DriveSession>('drives');
      await DriveTelemetryHive.openBox(hive);
      await DriveScoreHive.openBox(hive);
      await MyWorldHive.openBoxes(hive);
      for (final group in groups) {
        if (!hive.isBoxOpen(group)) await hive.openBox<dynamic>(group);
      }
      return OwnerScopedLocalStore._(owner, hive, directory.path, beforeFlush);
    } catch (_) {
      await hive.close();
      rethrow;
    }
  }

  void requireOwner(GpsOwner context) {
    if (context.targetStore != scope) {
      throw StateError('Owner context mismatch');
    }
  }

  Box<dynamic> _box(String group) {
    if (!groups.contains(group)) throw ArgumentError('Unknown personal group');
    return SourceWriterBoundary.box('scoped', registeredBox(_hive, group));
  }

  /// Hive requires the exact generic type used when opening a box.
  static Box<dynamic> registeredBox(HiveImpl hive, String group) =>
      switch (group) {
        'drives' => hive.box<DriveSession>(group),
        'drive_telemetry' => hive.box<DriveTelemetryRecord>(group),
        'drive_scores' => hive.box<DriveScoreRecord>(group),
        'my_world_validated_roads' => hive.box<ValidatedRoad>(group),
        'my_world_processing' => hive.box<WorldDriveProcessingRecord>(group),
        'my_world_pending_jobs' => hive.box<WorldPendingJob>(group),
        'my_world_index_snapshots' => hive.box<WorldIndexSnapshot>(group),
        'my_world_index_metadata' => hive.box<WorldIndexPointer>(group),
        _ => hive.box<dynamic>(group),
      };

  Uint8List encode(Object? value) =>
      (BinaryWriterImpl(_hive)..write(value)).toBytes();
  Object? decode(Uint8List bytes) => BinaryReaderImpl(bytes, _hive).read();

  /// Always return detached data: callers cannot mutate an attached HiveObject
  /// through a reference or write an object belonging to another Hive instance.
  T? read<T>(GpsOwner context, String group, Object key) {
    requireOwner(context);
    final value = _box(group).get(key);
    return value == null ? null : decode(encode(value)) as T;
  }

  List<Object> keys(GpsOwner context, String group) {
    requireOwner(context);
    return _box(group).keys.cast<Object>().toList(growable: false);
  }

  Future<void> put(GpsOwner context, String group, Object key, Object? value) =>
      SourceWriterBoundary.run(
        'scoped',
        () => _put(context, group, key, value),
        path: path,
      );
  Future<void> _put(
    GpsOwner context,
    String group,
    Object key,
    Object? value,
  ) async {
    requireOwner(context);
    final detached = decode(encode(value));
    await _box(group).put(key, detached);
    await beforeFlush?.call(group);
    await _box(group).flush();
    if (base64Encode(encode(_box(group).get(key))) !=
        base64Encode(encode(value))) {
      throw StateError('Local write verification failed');
    }
  }

  Future<void> remove(GpsOwner context, String group, Object key) =>
      SourceWriterBoundary.run(
        'scoped',
        () => _remove(context, group, key),
        path: path,
      );
  Future<void> _remove(GpsOwner context, String group, Object key) async {
    requireOwner(context);
    await _box(group).delete(key);
    await beforeFlush?.call(group);
    await _box(group).flush();
  }

  Future<void> flush(GpsOwner context) async {
    requireOwner(context);
    for (final group in groups) {
      await beforeFlush?.call(group);
      await _box(group).flush();
    }
  }

  Future<void> manifest(String key, Map<String, Object?> value) =>
      SourceWriterBoundary.run(
        'scoped',
        () => _manifest(key, value),
        path: path,
      );
  Future<void> _manifest(String key, Map<String, Object?> value) async {
    if (!key.startsWith('legacy_prepare_v1:')) {
      throw ArgumentError('Reserved namespace manifest key');
    }
    final box = _hive.box<dynamic>(_manifestBox);
    await box.put(key, value);
    await beforeFlush?.call(_manifestBox);
    await box.flush();
    if (jsonEncode(box.get(key)) != jsonEncode(value)) {
      throw StateError('Preparation manifest verification failed');
    }
  }

  Map? preparation(String key) =>
      _hive.box<dynamic>(_manifestBox).get(key) as Map?;
  Future<void> close() => _hive.close();

  ScopedLocalRepositories repositories(GpsOwner context) {
    requireOwner(context);
    return ScopedLocalRepositories._(this);
  }

  HiveMyWorldIndexRepository worldIndex(GpsOwner context) {
    requireOwner(context);
    return HiveMyWorldIndexRepository(
      _hive.box<WorldIndexSnapshot>(MyWorldHive.indexSnapshotsBoxName),
      _hive.box<WorldIndexPointer>(MyWorldHive.indexMetadataBoxName),
      lifecycle: ScopedLifecycle(this),
    );
  }

  HiveMyWorldRepository worldSources(GpsOwner context) {
    requireOwner(context);
    // Validate embedded owner evidence before exposing independent sources.
    repositories(context).rebuildSources();
    final lifecycle = ScopedLifecycle(this);
    return HiveMyWorldRepository.scoped(
      _hive.box<ValidatedRoad>('my_world_validated_roads'),
      _hive.box<WorldDriveProcessingRecord>('my_world_processing'),
      _hive.box<WorldPendingJob>('my_world_pending_jobs'),
      sources: WorldSourceSnapshotRepository(
        _box('my_world_source_snapshots_v1'),
      ),
      deleted: lifecycle.worldDeleted,
      hasDeletion: lifecycle.worldHasDeletion,
      serialized: lifecycle.serialized,
    );
  }

  Future<PosterStore> posters(
    GpsOwner context, {
    required void Function() requireCurrent,
    required void Function(String) requireDrive,
    required int epoch,
    required PosterOperationBoundary operations,
  }) async {
    requireOwner(context);
    requireCurrent();
    final directory = Directory('$path${Platform.pathSeparator}posters');
    await directory.create(recursive: true);
    requireCurrent();
    return PosterStore(
      _box('drive_posters'),
      directory,
      temporaryDirectory: Directory(
        '$path${Platform.pathSeparator}poster_cache${Platform.pathSeparator}$epoch',
      ),
      requireAccess: requireCurrent,
      requireDrive: requireDrive,
      operations: operations,
    );
  }
}

class ScopedLifecycle implements WorldIndexLifecycle {
  ScopedLifecycle(this.store);
  final OwnerScopedLocalStore store;
  static final Map<String, Future<void>> _tails = {};
  bool worldDeleted(String id) =>
      store.read(store.owner, 'local_lifecycle_v1', 'world:$id') != null;
  bool worldHasDeletion(String id) =>
      worldDeleted(id) ||
      store
          .keys(store.owner, 'local_lifecycle_v1')
          .whereType<String>()
          .where((key) => key.startsWith('worldTrace:'))
          .any(
            (key) =>
                store.read<Map>(
                  store.owner,
                  'local_lifecycle_v1',
                  key,
                )?['sourceId'] ==
                id,
          );
  @override
  Future<void> serialized(Future<void> Function() operation) {
    return SourceWriterBoundary.run(
      'scoped',
      () => _serialized(operation),
      path: store.path,
    );
  }

  Future<void> _serialized(Future<void> Function() operation) {
    final next = (_tails[store.path] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    _tails[store.path] = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  @override
  Future<void> flush() => store._box('local_lifecycle_v1').flush();
  @override
  List<ActiveWorldTrace> filterTraces(List<ActiveWorldTrace> traces) =>
      LocalLifecycleJournal.filterWithRecords(traces, {
        for (final key
            in store
                .keys(store.owner, 'local_lifecycle_v1')
                .whereType<String>())
          key: store.read<Map>(store.owner, 'local_lifecycle_v1', key)!,
      });
  Future<void> tombstone(String kind, String id) => serialized(() async {
    if (!['history', 'world', 'worldTrace'].contains(kind) || id.isEmpty) {
      throw ArgumentError('Unknown lifecycle intent');
    }
    if (kind == 'worldTrace') {
      throw StateError('Trace intent requires canonical span metadata');
    }
    final key = '$kind:$id';
    final existing = store.read<Map>(store.owner, 'local_lifecycle_v1', key);
    await store.put(
      store.owner,
      'local_lifecycle_v1',
      key,
      existing ?? {'version': 1, 'state': 'prepared'},
    );
  });
}

/// Frozen job context. The existing repository implementations only receive
/// boxes from this private Hive instance. No global LocalLifecycleJournal or
/// MyWorldRuntime is exposed through this facade.
class ScopedLocalRepositories {
  ScopedLocalRepositories._(this.store);
  final OwnerScopedLocalStore store;
  GpsOwner get owner => store.owner;
  CareerContributionRepository get _career => CareerContributionRepository(
    store._box(CareerContributionRepository.boxName),
  );
  WorldSourceSnapshotRepository get _world => WorldSourceSnapshotRepository(
    store._box(WorldSourceSnapshotRepository.boxName),
  );
  PlanetSegmentOutbox get _outbox => PlanetSegmentOutbox(
    store._box(PlanetSegmentOutbox.boxName),
  ); // Always disabled gateway.

  void _check(LocalSourceBundle source) {
    if (source.ownerScope != store.scope) {
      throw StateError('Source owner mismatch');
    }
  }

  Future<void> prepareSource(LocalSourceBundle source) async {
    _check(source);
    await _world.prepare(source);
  }

  Future<void> contribute(LocalSourceBundle source) async {
    _check(source);
    await _career.add(source);
  }

  Future<bool> prepareCareerBaseline(
    List<LocalSourceBundle> sources,
    Map<String, dynamic> totals,
  ) async {
    for (final source in sources) {
      _check(source);
    }
    return _career.prepareLegacy(sources: sources, totals: totals);
  }

  CareerStatistics? careerStatistics() {
    // Every persisted bundle must belong to this namespace before aggregation.
    for (final key
        in store
            .keys(owner, CareerContributionRepository.boxName)
            .whereType<String>()
            .where((k) => k.startsWith('drive:'))) {
      final raw = store.read<String>(
        owner,
        CareerContributionRepository.boxName,
        key,
      )!;
      _check(LocalSourceBundle.fromMap((jsonDecode(raw) as Map)['bundle']));
    }
    return _career.statistics();
  }

  /// Dormant deletion primitive; fails closed unless independent World source
  /// and Career basis have already been verified. Never purges World/Career.
  Future<void> deleteHistory(
    String id,
  ) => ScopedLifecycle(store).serialized(() async {
    final key = 'history:$id';
    final prior = store.read<Map>(owner, 'local_lifecycle_v1', key);
    if (prior == null) {
      if (source(id) == null ||
          careerStatistics() == null ||
          store.read(
                owner,
                CareerContributionRepository.boxName,
                'drive:$id',
              ) ==
              null) {
        throw StateError(
          'Independent source/Career not prepared; History retained',
        );
      }
      final snapshot = source(id)!;
      final active = await store.worldIndex(owner).getActiveTracesForDrive(id);
      if (active.isNotEmpty &&
          (snapshot.telemetry == null ||
              snapshot.telemetry!.points.isEmpty ||
              snapshot.score == null ||
              active.any(
                (trace) => !snapshot.roads.any(
                  (road) =>
                      road.id == trace.validatedRoadId &&
                      road.sections.any((s) => s.id == trace.matchedSectionId),
                ),
              ))) {
        throw StateError(
          'Active World source evidence incomplete; History retained',
        );
      }
    }
    // Reflush on retry: an in-memory intent after a failed flush is not proof.
    await store.put(
      owner,
      'local_lifecycle_v1',
      key,
      prior ?? {'version': 1, 'state': 'prepared'},
    );
    for (final group in [
      'drives',
      'drive_telemetry',
      'drive_names',
      'drive_details_v1',
    ]) {
      await store.remove(owner, group, id);
    }
    for (final key in store.keys(owner, 'drive_scores')) {
      if (store.read<DriveScoreRecord>(owner, 'drive_scores', key)!.driveId ==
          id) {
        await store.remove(owner, 'drive_scores', key);
      }
    }
    await store.put(owner, 'local_lifecycle_v1', key, {
      'version': 1,
      'state': 'completed',
    });
  });

  LocalSourceBundle? source(String id) {
    final result = _world.get(id);
    if (result != null) _check(result);
    return result;
  }

  List<LocalSourceBundle> rebuildSources() => _world
      .getAll()
      .map((source) {
        _check(source);
        return source;
      })
      .where(
        (s) =>
            store.read(owner, 'local_lifecycle_v1', 'world:${s.drive.id}') ==
            null,
      )
      .toList();
  Future<void> prepareSegments(Iterable<PlanetSegment> segments) =>
      _outbox.prepare(store.scope, segments);
  List<Map<String, dynamic>> segments(String driveId) =>
      _outbox.entries(store.scope, driveId);
  Future<void> deliverSegment(String id, GpsOwner sendingOwner) async {
    store.requireOwner(sendingOwner);
    return _outbox.deliver(store.scope, id);
  }

  double get acceptedDistance => _outbox.acceptedDistance(store.scope);
}

/// Captured view token; owner switching invalidates old futures without altering
/// their frozen repository or deleting disk data. No production auth listener.
class OwnerViewBarrier {
  OwnerViewBarrier(GpsOwner owner) : _owner = owner;
  GpsOwner _owner;
  GpsOwner get owner => _owner;
  int _epoch = 0;
  final Map<String, Object> _cache = {};
  void switchTo(GpsOwner next) {
    _owner = next;
    _epoch++;
  }

  Future<T?> load<T extends Object>(
    String key,
    Future<T> Function(GpsOwner) load,
  ) async {
    final epoch = _epoch;
    final captured = owner;
    final cacheKey = captured.recordKey(key);
    final T result;
    try {
      result = _cache[cacheKey] as T? ?? await load(captured);
    } catch (_) {
      // Discard only errors from an obsolete read view. Current-view errors
      // keep their original stack; durable writes must not use this UI fence.
      if (_epoch != epoch || owner.targetStore != captured.targetStore) {
        return null;
      }
      rethrow;
    }
    if (_epoch != epoch || owner.targetStore != captured.targetStore) {
      return null;
    }
    _cache[cacheKey] = result;
    return result;
  }

  void invalidate(String key) {
    _cache.remove(owner.recordKey(key));
    _epoch++;
  }
}
