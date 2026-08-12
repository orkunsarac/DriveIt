import 'active_world_trace.dart';
import 'common_road_match.dart';
import 'local_winning_road_region.dart';

/// Transient Phase 3-5 result for one active trace versus a challenger.
class WorldTraceOverlapAnalysis {
  const WorldTraceOverlapAnalysis({
    required this.existingTrace,
    required this.matches,
    required this.winningRegions,
  });

  final ActiveWorldTrace existingTrace;
  final List<CommonRoadMatch> matches;
  final List<LocalWinningRoadRegion> winningRegions;
}
