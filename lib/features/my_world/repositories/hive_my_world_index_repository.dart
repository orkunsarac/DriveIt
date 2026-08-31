import 'package:hive/hive.dart';

import '../models/active_world_trace.dart';
import '../models/world_index_mutation_plan.dart';
import '../models/world_index_snapshot.dart';
import '../config/my_world_rules.dart';
import 'my_world_index_repository.dart';

/// Hive copy-on-write index storage. A failed snapshot write can leave an
/// orphaned generation, but can never change the active pointer.
class HiveMyWorldIndexRepository
    implements MyWorldIndexRepository, WorldIndexRecoveryRepository {
  HiveMyWorldIndexRepository(this._snapshots, this._metadata);

  final Box<WorldIndexSnapshot> _snapshots;
  final Box<WorldIndexPointer> _metadata;
  static const String _activePointerKey = 'active_generation';

  @override
  Future<WorldIndexSnapshot> getActiveSnapshot() async {
    final pointer = _metadata.get(_activePointerKey);
    if (pointer == null) return _emptySnapshot();
    final snapshot = _snapshots.get(pointer.activeGeneration);
    if (snapshot == null) {
      throw StateError('World index pointer references a missing snapshot.');
    }
    _validateSnapshot(snapshot);
    return snapshot;
  }

  @override
  Future<void> commit(WorldIndexMutationPlan plan) async {
    final active = await getActiveSnapshot();
    if (active.generation != plan.baseGeneration) {
      throw StateError('World index changed before this operation could commit.');
    }
    if (plan.resultingSnapshot.generation != active.generation + 1) {
      throw ArgumentError.value(
        plan.resultingSnapshot.generation,
        'generation',
        'must advance exactly once',
      );
    }
    _validateSnapshot(plan.resultingSnapshot);

    // The pointer stays untouched until the whole immutable next generation
    // has been written successfully.
    await _snapshots.put(
      plan.resultingSnapshot.generation,
      plan.resultingSnapshot,
    );
    await _metadata.put(
      _activePointerKey,
      WorldIndexPointer(
        activeGeneration: plan.resultingSnapshot.generation,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> activateRecoverySnapshot(WorldIndexSnapshot snapshot) async {
    _validateSnapshot(snapshot);
    await _snapshots.put(snapshot.generation, snapshot);
    await _metadata.put(
      _activePointerKey,
      WorldIndexPointer(
        activeGeneration: snapshot.generation,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<List<ActiveWorldTrace>> getActiveTraces() async =>
      (await getActiveSnapshot()).traces;

  @override
  Future<List<ActiveWorldTrace>> getActiveTracesForDrive(
    String driveSessionId,
  ) async => (await getActiveSnapshot()).traces
      .where((trace) => trace.sourceDriveSessionId == driveSessionId)
      .toList(growable: false);

  @override
  Future<List<ActiveWorldTrace>> getActiveTracesInBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async => (await getActiveSnapshot()).traces
      .where(
        (trace) => trace.intersectsBounds(
          minLatitude: minLatitude,
          maxLatitude: maxLatitude,
          minLongitude: minLongitude,
          maxLongitude: maxLongitude,
        ),
      )
      .toList(growable: false);

  @override
  Future<bool> hasActiveTraceForDrive(String driveSessionId) async =>
      (await getActiveTracesForDrive(driveSessionId)).isNotEmpty;

  @override
  Future<double> activeDistanceForDrive(String driveSessionId) async =>
      (await getActiveTracesForDrive(driveSessionId))
          .fold<double>(0, (sum, trace) => sum + trace.distanceMeters);

  @override
  Future<double> totalWorldDistance() async => (await getActiveSnapshot())
      .traces
      .fold<double>(0, (sum, trace) => sum + trace.distanceMeters);


  WorldIndexSnapshot _emptySnapshot() => WorldIndexSnapshot.empty(
    driveScoreAlgorithmVersion: 1,
    // Version 2 intentionally marks a missing pointer as requiring the first
    // rules-v3 rebuild; an empty index must not hide stored validated roads.
    validatedRoadProcessingVersion: 2,
  );

  void _validateSnapshot(WorldIndexSnapshot snapshot) {
    final ids = <String>{};
    for (final trace in snapshot.traces) {
      if (!ids.add(trace.id)) throw StateError('Duplicate active World trace id.');
      if (!trace.startOffsetMeters.isFinite ||
          !trace.endOffsetMeters.isFinite ||
          trace.startOffsetMeters < 0 ||
          trace.endOffsetMeters <= trace.startOffsetMeters ||
          trace.distanceMeters < MyWorldRules.minimumActiveTraceMeters) {
        throw StateError('World index cannot contain an empty trace.');
      }
    }
  }
}
