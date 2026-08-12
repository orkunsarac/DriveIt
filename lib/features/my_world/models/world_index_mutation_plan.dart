import 'active_world_trace.dart';
import 'world_index_snapshot.dart';

/// An entirely in-memory ownership change. Repositories persist only the
/// [resultingSnapshot] after it passes invariant checks.
class WorldIndexMutationPlan {
  const WorldIndexMutationPlan({
    required this.operationId,
    required this.sourceDriveSessionId,
    required this.baseGeneration,
    required this.tracesToRemove,
    required this.tracesToCreate,
    required this.resultingSnapshot,
  });

  final String operationId;
  final String sourceDriveSessionId;
  final int baseGeneration;
  final List<ActiveWorldTrace> tracesToRemove;
  final List<ActiveWorldTrace> tracesToCreate;
  final WorldIndexSnapshot resultingSnapshot;
}
