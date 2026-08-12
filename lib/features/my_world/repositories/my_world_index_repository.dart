import '../models/active_world_trace.dart';
import '../models/world_index_mutation_plan.dart';
import '../models/world_index_snapshot.dart';

abstract interface class MyWorldIndexRepository {
  Future<WorldIndexSnapshot> getActiveSnapshot();

  /// Persists a complete next generation, then atomically activates it by
  /// switching its pointer. A stale plan must not overwrite a newer snapshot.
  Future<void> commit(WorldIndexMutationPlan plan);

  Future<List<ActiveWorldTrace>> getActiveTraces();
  Future<List<ActiveWorldTrace>> getActiveTracesForDrive(String driveSessionId);
  Future<List<ActiveWorldTrace>> getActiveTracesInBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  });
  Future<bool> hasActiveTraceForDrive(String driveSessionId);
  Future<double> activeDistanceForDrive(String driveSessionId);
  Future<double> totalWorldDistance();

}

/// Optional capability used only by an explicit rebuild when the active
/// pointer/snapshot itself is corrupt. Normal processing never uses it.
abstract interface class WorldIndexRecoveryRepository {
  Future<void> activateRecoverySnapshot(WorldIndexSnapshot snapshot);
}
