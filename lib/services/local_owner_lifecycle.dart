import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/local_ownership_gate.dart';
import '../models/drive_session.dart';
import 'gps_session_ownership.dart';
import 'owner_scoped_local_store.dart';
import 'gps_session_store.dart';
import 'owned_gps_session_coordinator.dart';
import 'scoped_gps_transfer_sink.dart';
import '../models/drive_score_record.dart';
import '../models/canonical_telemetry_point.dart';
import 'drive_score_storage_service.dart';
import 'drive_time_analysis.dart';
import 'career_statistics_service.dart';
import '../features/world_publish/segments/planet_segment.dart';
import '../features/my_world/models/world_index_snapshot.dart';
import '../features/my_world/models/world_rebuild_result.dart';
import '../features/my_world/models/world_pending_job.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/services/my_world_rebuild_service.dart';
import '../features/my_world/services/world_record_processing_service.dart';
import '../features/drive_score/models/drive_score_algorithm_version.dart';
import '../features/drive_poster/poster_store.dart';
import '../features/my_world/services/my_world_read_service.dart';
import '../features/my_world/services/world_trace_detail_service.dart';
import '../features/my_world/models/world_map_read_model.dart';
import '../features/my_world/services/my_world_validation_service.dart';
import '../features/my_world/services/road_matching_service.dart';
import '../features/my_world/services/world_pending_job_processor.dart';
import '../features/my_world/services/world_index_mutation_planner.dart';
import '../features/my_world/config/my_world_rules.dart';
import '../features/my_world/models/world_trace_detail.dart';

/// Auth boundary exposes only a stable UUID; never a Session/token/profile.
abstract interface class LocalOwnerAuth {
  String? get userId;
  Stream<String?> get changes;
}

enum LocalOwnerState { disabled, preparing, ready, blocked, failed, closed }

class _OwnerOperationTicket {
  bool active = true;
}

/// A revoked context cannot be used even when its old store is still flushing.
/// No raw Hive box or scoped store is returned to a screen.
class LocalOwnerLease implements PosterOperationBoundary {
  LocalOwnerLease._(this._runtime, this._store, this.epoch);
  final LocalOwnerLifecycle _runtime;
  final OwnerScopedLocalStore _store;
  final int epoch;
  GpsOwner get owner => _store.owner;
  Listenable get changes => _runtime;
  int get worldRevision => _runtime._worldRevision;
  void _worldChanged() {
    _runtime._notifyWorldChange(this);
  }

  bool get isCurrent =>
      _runtime._lease == this &&
      _runtime.state == LocalOwnerState.ready &&
      _runtime.epoch == epoch;
  void requireCurrent() {
    if (!isCurrent) throw StateError('Owner view revoked');
  }

  @override
  Future<T> run<T>(Future<T> Function() action) =>
      _runtime.withOwnerOperation((current) async {
        requireCurrent();
        if (!identical(current, this)) throw StateError('Owner view revoked');
        return action();
      });

  T? read<T>(String group, Object key) {
    requireCurrent();
    return _store.read<T>(owner, group, key);
  }

  List<Object> keys(String group) {
    requireCurrent();
    return _store.keys(owner, group);
  }

  List<DriveSession> drives() => keys(
    'drives',
  ).map((id) => read<DriveSession>('drives', id)!).toList(growable: false);

  /// A caller-provided DriveSession is not ownership evidence.
  DriveSession requireDrive(String id) {
    final drive = read<DriveSession>('drives', id);
    if (drive == null || drive.id != id) {
      throw StateError('Owner drive unavailable');
    }
    return drive;
  }

  DriveTelemetryRecord? telemetry(String id) {
    requireDrive(id);
    final record = read<DriveTelemetryRecord>('drive_telemetry', id);
    if (record != null && record.driveSessionId != id) {
      throw StateError('Owner telemetry identity mismatch');
    }
    return record;
  }

  List<Map<String, dynamic>> publicationEntries(String id) {
    requireDrive(id);
    return _store.repositories(owner).segments(id);
  }

  Future<void> preparePublication(String id, Iterable<PlanetSegment> segments) {
    final frozen = List<PlanetSegment>.unmodifiable(segments);
    return _runtime.withOwnerOperation((current) async {
      requireCurrent();
      if (!identical(current, this)) throw StateError('Owner view revoked');
      requireDrive(id);
      final candidates = const PlanetSegmentBuilder()
          .build(id, telemetry(id))
          .eligible;
      final allowed = {
        for (final segment in candidates)
          segment.id: jsonEncode(segment.toMap()),
      };
      if (frozen.any(
        (s) => s.sourceDriveId != id || allowed[s.id] != jsonEncode(s.toMap()),
      )) {
        throw StateError('Publication source mismatch');
      }
      await _store.repositories(owner).prepareSegments(frozen);
    });
  }

  DriveScoreRecord? score(String driveId) {
    final record = read<DriveScoreRecord>(
      'drive_scores',
      DriveScoreStorageService.keyFor(
        driveId,
        DriveScoreRecord.currentAlgorithmVersion,
      ),
    );
    if (record != null && record.driveId != driveId) {
      throw StateError('Owner score identity mismatch');
    }
    return record;
  }

  DriveTimeAnalysis? timing(String driveId) {
    final telemetry = read<DriveTelemetryRecord>('drive_telemetry', driveId);
    return telemetry == null ? null : DriveTimeAnalysis.fromRecord(telemetry);
  }

  CareerStatistics career() {
    requireCurrent();
    final result = _store.repositories(owner).careerStatistics();
    if (result == null) throw StateError('Owner Career baseline not prepared');
    return result;
  }

  Future<WorldIndexSnapshot?> worldSnapshot() =>
      load((_) => _store.worldIndex(owner).getActiveSnapshot());
  Future<PosterStore> posters() {
    requireCurrent();
    return _store.posters(
      owner,
      requireCurrent: requireCurrent,
      requireDrive: requireDrive,
      epoch: epoch,
      operations: this,
    );
  }

  Future<List<ValidatedRoad>?> worldRoads() =>
      load((_) => _store.worldSources(owner).getAllValidatedRoads());

  Future<List<WorldPendingJob>?> worldPendingJobs() =>
      load((_) => _store.worldSources(owner).getPendingJobs());

  Future<ResolvedWorldTrace?> resolveWorldTrace(String id) async {
    final data = await worldMap();
    return data.traces.where((t) => t.trace.id == id).firstOrNull;
  }

  Future<WorldTraceDetail?> worldTraceDetail(String id) async {
    final trace = await resolveWorldTrace(id);
    if (trace == null) return null;
    final detail = await worldDetails().loadTrace(
      trace: trace.trace,
      geometry: trace.geometry,
    );
    requireCurrent();
    return detail;
  }

  List<DriveSession> worldDrives() {
    requireCurrent();
    return _store
        .repositories(owner)
        .rebuildSources()
        .map((s) => s.drive)
        .toList();
  }

  Future<MyWorldMapData> worldMap() async {
    requireCurrent();
    final value = await MyWorldReadService(
      repository: _store.worldSources(owner),
      indexRepository: _store.worldIndex(owner),
      traceFilter: ScopedLifecycle(_store).filterTraces,
      telemetryLoader: (id) async =>
          _store.repositories(owner).source(id)?.telemetry?.points ?? const [],
    ).load();
    requireCurrent();
    return value;
  }

  WorldTraceDetailService worldDetails() {
    requireCurrent();
    final repositories = _store.repositories(owner);
    return WorldTraceDetailService(
      driveLoader: (id) {
        requireCurrent();
        return repositories.source(id)?.drive;
      },
      scoreLoader: (id) {
        requireCurrent();
        return repositories.source(id)?.score;
      },
      telemetryLoader: (id) async {
        requireCurrent();
        return repositories.source(id)?.telemetry?.points ?? const [];
      },
      activeDistanceLoader: (id) async {
        requireCurrent();
        final value = await _store.worldIndex(owner).activeDistanceForDrive(id);
        requireCurrent();
        return value;
      },
    );
  }

  /// The write is pinned to this store until completion. External Auth revokes
  /// the view immediately, but the runtime drains this operation before close.
  Future<WorldRebuildResult> rebuildWorld() => run(() async {
    final result = await _rebuildWorld();
    if (result.success) _worldChanged();
    return result;
  });

  Future<WorldRebuildResult> _rebuildWorld({
    String reason = 'manualRebuild',
  }) async {
    final repositories = _store.repositories(owner);
    final sources = repositories.rebuildSources();
    final byId = {for (final source in sources) source.drive.id: source};
    final lifecycle = ScopedLifecycle(_store);
    final repository = _store.worldSources(owner);
    final index = _store.worldIndex(owner);
    Future<List<CanonicalTelemetryPoint>> telemetry(String id) async =>
        byId[id]?.telemetry?.points ?? const [];
    final processor = WorldRecordProcessingService(
      repository: repository,
      indexRepository: index,
      telemetryLoader: telemetry,
      worldDeleted: lifecycle.worldDeleted,
      traceFilter: lifecycle.filterTraces,
    );
    return MyWorldRebuildService(
      repository: repository,
      indexRepository: index,
      driveLoader: () async => sources.map((s) => s.drive).toList(),
      telemetryLoader: telemetry,
      processingService: processor,
      driveEligibility: (id) => byId[id]?.score != null,
      worldDeleted: lifecycle.worldDeleted,
      traceFilter: lifecycle.filterTraces,
    ).rebuild(targetVersion: DriveScoreAlgorithmVersion.v1, reason: reason);
  }

  Future<void> deleteWorldTrace(String id) => run(() async {
    try {
      await _deleteWorldTrace(id);
    } finally {
      _worldChanged();
    }
  });

  Future<void> _deleteWorldTrace(String id) async {
    final index = _store.worldIndex(owner);
    final repository = _store.worldSources(owner);
    final lifecycle = ScopedLifecycle(_store);
    final before = await index.getActiveSnapshot();
    final selected = before.traces.where((t) => t.id == id).firstOrNull;
    final key = 'worldTrace:$id';
    final prior = _store.read<Map>(owner, 'local_lifecycle_v1', key);
    if (selected == null && prior == null) {
      throw StateError('Owner World trace unavailable');
    }
    for (final trace in before.traces) {
      if (_store.repositories(owner).source(trace.sourceDriveSessionId) ==
              null ||
          await repository.getValidatedRoad(trace.validatedRoadId) == null) {
        throw StateError('World source incomplete; deletion blocked');
      }
    }
    // Reflush before every retry. An in-memory failed write is not durability.
    await lifecycle.serialized(
      () => _store.put(
        owner,
        'local_lifecycle_v1',
        key,
        prior ??
            {
              'version': 1,
              'state': 'prepared',
              'sourceId': selected!.sourceDriveSessionId,
              'roadId': selected.validatedRoadId,
              'sectionId': selected.matchedSectionId,
              'start': selected.startOffsetMeters,
              'end': selected.endOffsetMeters,
            },
      ),
    );
    final filtered = lifecycle.filterTraces(before.traces);
    if (filtered.length != before.traces.length ||
        List.generate(
          filtered.length,
          (i) => filtered[i].id != before.traces[i].id,
        ).any((v) => v)) {
      final result = await _rebuildWorld(
        reason: 'independentWorldDeletion:$id',
      );
      if (!result.success) throw StateError('World deletion needs recovery');
    }
    final intent = _store.read<Map>(owner, 'local_lifecycle_v1', key)!;
    await _purgeDeletedWorldSource(intent['sourceId'] as String);
    await _store.put(owner, 'local_lifecycle_v1', key, {
      ...intent,
      'state': 'completed',
    });
  }

  Future<void> _purgeDeletedWorldSource(String id) async {
    final lifecycle = ScopedLifecycle(_store);
    if (_store.read(owner, 'drives', id) != null ||
        !lifecycle.worldHasDeletion(id)) {
      return;
    }
    if ((await _store.worldIndex(owner).getActiveTracesForDrive(id))
        .isNotEmpty) {
      return;
    }
    final source = _store.repositories(owner).source(id);
    if (source == null) return;
    for (final road in source.roads.where(
      (r) =>
          r.processingVersion == MyWorldRules.validatedRoadProcessingVersion &&
          r.validDistanceMeters >= MyWorldRules.minimumValidDistanceMeters,
    )) {
      final footprint = const WorldIndexMutationPlanner()
          .plan(
            current: WorldIndexSnapshot.empty(
              driveScoreAlgorithmVersion: 1,
              validatedRoadProcessingVersion: MyWorldRules.worldRulesVersion,
            ),
            challengerRoad: road,
            overlaps: [],
            now: road.createdAt,
          )
          .resultingSnapshot
          .traces;
      if (lifecycle.filterTraces(footprint).isNotEmpty) return;
    }
    await _store.worldSources(owner).deleteWorldDataForDrive(id);
    await _store.remove(owner, 'my_world_source_snapshots_v1', id);
  }

  /// Explicit owner-pinned worker. A matching dependency is never invented and
  /// cannot silently fall back to global/real network configuration.
  Future<void> drainWorldJobs() => run(() async {
    for (final key
        in _store
            .keys(owner, 'local_lifecycle_v1')
            .whereType<String>()
            .toList()) {
      final record = _store.read<Map>(owner, 'local_lifecycle_v1', key)!;
      if (record['state'] == 'completed') continue;
      if (key.startsWith('worldTrace:')) {
        await _deleteWorldTrace(key.substring(11));
      }
      if (key.startsWith('history:')) {
        await _store.repositories(owner).deleteHistory(key.substring(8));
        await _purgeDeletedWorldSource(key.substring(8));
      }
    }
    final repository = _store.worldSources(owner);
    final jobs = await repository.getPendingJobs();
    if (jobs.isEmpty) {
      _worldChanged();
      return;
    }
    final matching = _runtime.worldRoadMatching;
    if (matching == null) {
      throw StateError('Owner World matching dependency unavailable');
    }
    final repositories = _store.repositories(owner);
    final lifecycle = ScopedLifecycle(_store);
    Future<List<CanonicalTelemetryPoint>> telemetry(String id) async =>
        repositories.source(id)?.telemetry?.points ?? const [];
    await WorldPendingJobProcessor(
      repository: repository,
      validation: MyWorldValidationService(
        repository: repository,
        roadMatching: matching,
        telemetryLoader: telemetry,
        hasDeletion: lifecycle.worldHasDeletion,
      ),
      recordProcessing: WorldRecordProcessingService(
        repository: repository,
        indexRepository: _store.worldIndex(owner),
        telemetryLoader: telemetry,
        worldDeleted: lifecycle.worldDeleted,
        traceFilter: lifecycle.filterTraces,
      ),
      driveLoader: (id) => repositories.source(id)?.drive,
      driveEligibility: (id) =>
          !lifecycle.worldHasDeletion(id) &&
          repositories.source(id)?.score != null,
      drainScope: _store.path,
    ).drain();
    _worldChanged();
  });

  Future<void> enqueueWorldDrive(String id) => run(() async {
    final source = _store.repositories(owner).source(id);
    if (source == null || source.score == null) {
      throw StateError('Owner World source unavailable');
    }
    await _store
        .worldSources(owner)
        .enqueueIfAbsent(
          WorldPendingJob.pending(
            driveSessionId: id,
            type: WorldJobType.validateRoad,
            now: DateTime.now().toUtc(),
          ),
        );
  });

  Future<void> deleteHistory(String id) =>
      _runtime.withOwnerOperation((current) async {
        requireCurrent();
        if (!identical(current, this)) throw StateError('Owner view revoked');
        await _store.repositories(owner).deleteHistory(id);
        await _purgeDeletedWorldSource(id);
      });

  Future<T?> load<T extends Object>(
    Future<T> Function(LocalOwnerLease) read,
  ) async {
    requireCurrent();
    try {
      final value = await read(this);
      return isCurrent ? value : null;
    } catch (_) {
      if (!isCurrent) return null;
      rethrow;
    }
  }

  /// An already-started write stays pinned to its old owner. A transition waits
  /// for it before closing the old store; it never redirects the write.
  Future<void> put(String group, Object key, Object? value) {
    requireCurrent();
    final write = _store.put(owner, group, key, value);
    _runtime._writes.add(write);
    return write.whenComplete(() => _runtime._writes.remove(write));
  }

  /// Reuse the already-open handle; never open the same Hive directory twice.
  Future<void> transferGps({
    required GpsSessionStore journal,
    required GpsOwnershipStore ownership,
    required GpsOwnershipManifest binding,
    required Map<String, dynamic> proposed,
  }) => _runtime.withOwnerOperation((current) async {
    requireCurrent();
    if (!identical(this, current)) throw StateError('Owner view revoked');
    _store.requireOwner(binding.owner);
    await OwnedGpsSessionCoordinator(
      journal: journal,
      ownership: ownership,
      journalId: binding.journalId,
      ownerAtStart: () => throw StateError('Transfer must not read Auth'),
    ).save(
      binding.sessionId!,
      proposed,
      ScopedGpsTransferSink(_store, binding),
    );
  });
}

/// Dormant, dependency-injected lifecycle. OFF does not touch Auth, open boxes,
/// inspect GPS or migrate legacy data. Failure invalidates the old view first.
class LocalOwnerLifecycle extends ChangeNotifier {
  LocalOwnerLifecycle({
    required this.gate,
    required this.auth,
    required this.openStore,
    required this.driveInProgress,
    this.activeSessionOwner,
    this.worldRoadMatching,
  });
  final LocalOwnershipGate gate;
  final LocalOwnerAuth auth;
  final RoadMatchingService? worldRoadMatching;
  final Future<OwnerScopedLocalStore> Function(GpsOwner) openStore;

  /// Must return true for unfinished/recoverable sessions too; errors block.
  final Future<bool> Function() driveInProgress;

  /// Only durable sidecar evidence may answer this. Null is unknown, not guest.
  final Future<GpsOwner?> Function()? activeSessionOwner;
  LocalOwnerState _state = LocalOwnerState.disabled;
  int _epoch = 0;
  int _worldRevision = 0;
  String? _errorCode;
  LocalOwnerState get state => _state;
  int get epoch => _epoch;
  String? get errorCode => _errorCode;
  LocalOwnerLease? _lease;
  OwnerScopedLocalStore? _store;
  StreamSubscription<String?>? _subscription;
  final Set<Future<void>> _writes = {};
  Future<void> _tail = Future<void>.value();
  Future<void> _operationTail = Future<void>.value();
  final Object _operationZoneKey = Object();
  bool _closed = false;
  GpsOwner? _requested;

  LocalOwnerLease get lease {
    final lease = _lease;
    if (lease == null) throw StateError('Owner context not ready');
    lease.requireCurrent();
    return lease;
  }

  Future<void> get settled => _tail;
  void _notifyWorldChange(LocalOwnerLease lease) {
    if (!lease.isCurrent) return;
    _worldRevision++;
    notifyListeners();
  }

  static GpsOwner ownerFor(String? id) =>
      id == null ? const GpsOwner.guest() : GpsOwner.account(id);

  Future<void> start() async {
    if (!gate.enabled || _closed || _subscription != null) return;
    _subscription = auth.changes.listen(
      _request,
      onError: (Object _) {
        _invalidate(LocalOwnerState.failed, 'auth_observation_failed');
      },
    );
    _request(auth.userId);
    await settled;
  }

  void _invalidate(LocalOwnerState next, [String? code]) {
    _epoch++;
    _lease = null;
    _state = next;
    _errorCode = code;
    notifyListeners();
  }

  void _request(String? id) {
    if (_closed || !gate.enabled) return;
    final GpsOwner next;
    try {
      next = ownerFor(id);
    } catch (_) {
      _requested = null;
      _invalidate(LocalOwnerState.failed, 'invalid_owner_identity');
      return;
    }
    // TOKEN_REFRESHED for the same UUID must not reset navigation/caches.
    if (_requested?.targetStore == next.targetStore &&
        (state == LocalOwnerState.ready ||
            state == LocalOwnerState.preparing)) {
      return;
    }
    _requested = next;
    _invalidate(LocalOwnerState.preparing);
    final requestEpoch = epoch;
    _tail = _tail.then(
      (_) => _exclusive(
        () => _transition(next, requestEpoch),
        fromAuthEvent: true,
      ),
    );
  }

  /// Shared fence for identity changes, GPS creation and import quiescence.
  /// A failed operation does not poison later recovery attempts. External Auth
  /// still revokes leases synchronously; a durable GPS owner never changes.
  Future<T> _exclusive<T>(
    Future<T> Function() action, {
    bool fromAuthEvent = false,
  }) {
    final parent = Zone.current[_operationZoneKey];
    if (!fromAuthEvent && parent is _OwnerOperationTicket && parent.active) {
      return Future.error(StateError('Nested owner operation would deadlock'));
    }
    final result = _operationTail.then((_) {
      final ticket = _OwnerOperationTicket();
      return runZoned(
        action,
        zoneValues: {_operationZoneKey: ticket},
      ).whenComplete(() => ticket.active = false);
    });
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<T> withOwnerOperation<T>(
    Future<T> Function(LocalOwnerLease lease) action,
  ) {
    if (!gate.enabled) throw StateError('Ownership disabled');
    final captured = lease;
    return _exclusive(() async {
      captured.requireCurrent();
      return action(captured);
    });
  }

  Future<void> _transition(GpsOwner next, int requestEpoch) async {
    if (_closed || epoch != requestEpoch) return;
    try {
      // External Auth changes cannot relabel an active/recoverable GPS session.
      // Hide personal views until it is safely completed under its fixed owner.
      if (await driveInProgress()) {
        final fixedOwner = await activeSessionOwner?.call();
        if (fixedOwner?.targetStore != next.targetStore) {
          if (!_closed && epoch == requestEpoch) {
            _invalidate(
              LocalOwnerState.blocked,
              'gps_owner_transition_blocked',
            );
          }
          return;
        }
      }
      await Future.wait(_writes.toList());
      final old = _store;
      _store = null;
      await old?.close();
      if (_closed || epoch != requestEpoch) return;
      final opened = await openStore(next);
      if (_closed || epoch != requestEpoch) {
        await opened.close();
        return;
      }
      try {
        opened.requireOwner(next);
      } catch (_) {
        await opened.close();
        rethrow;
      }
      _store = opened;
      _worldRevision = 0;
      _lease = LocalOwnerLease._(this, opened, requestEpoch);
      _state = LocalOwnerState.ready;
      _errorCode = null;
      notifyListeners();
    } catch (_) {
      if (!_closed && epoch == requestEpoch) {
        _invalidate(LocalOwnerState.failed, 'owner_context_unavailable');
      }
    }
  }

  /// Call before user-requested login/logout/switch, not after changing Auth.
  /// This is not installed into the existing production Auth service yet.
  Future<T> authorizeIdentityChange<T>(Future<T> Function() change) async {
    if (!gate.enabled) {
      return change();
    }
    return _exclusive(() async {
      if (_closed || await driveInProgress()) {
        throw StateError('GPS session must finish before account change');
      }
      return change();
    });
  }

  Future<void> retry() async {
    if (!gate.enabled || _closed) return;
    _requested = null;
    _request(auth.userId);
    await settled;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _invalidate(LocalOwnerState.closed);
    await _subscription?.cancel();
    await _tail;
    await _operationTail;
    await Future.wait(_writes.toList());
    await _store?.close();
    _store = null;
  }
}
