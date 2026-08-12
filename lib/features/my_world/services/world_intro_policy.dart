import '../models/world_map_read_model.dart';

class WorldIntroPolicy {
  const WorldIntroPolicy._();

  static const duration = Duration(seconds: 3);

  static bool shouldPlay({
    required MyWorldMapData data,
    required bool skipIntroAnimation,
  }) => data.traces.isNotEmpty && !skipIntroAnimation;

  /// Stable, trace-count-independent reveal start in the first 35%.
  static double revealStart(int traceIndex, int traceCount) {
    if (traceCount <= 1) return 0;
    return (traceIndex / (traceCount - 1)) * .35;
  }

  static double revealProgress({
    required double animationProgress,
    required int traceIndex,
    required int traceCount,
  }) {
    final start = revealStart(traceIndex, traceCount);
    return ((animationProgress - start) / .62).clamp(0.0, 1.0);
  }
}
