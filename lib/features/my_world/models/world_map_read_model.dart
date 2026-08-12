import 'active_world_trace.dart';
import 'matched_road_point.dart';

/// One active World index trace resolved to its read-only drawing geometry.
class ResolvedWorldTrace {
  const ResolvedWorldTrace({
    required this.trace,
    required this.geometry,
    required this.visualVariant,
  });

  final ActiveWorldTrace trace;
  final List<MatchedRoadPoint> geometry;
  final int visualVariant;

  ResolvedWorldTrace withVisualVariant(int value) => ResolvedWorldTrace(
    trace: trace,
    geometry: geometry,
    visualVariant: value,
  );
}

class WorldMapViewport {
  const WorldMapViewport({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
    required this.source,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
  final String source;

  double get centerLatitude => (minLatitude + maxLatitude) / 2;
  double get centerLongitude => (minLongitude + maxLongitude) / 2;
}

/// Immutable screen-lifetime projection of the active World snapshot.
class MyWorldMapData {
  const MyWorldMapData({
    required this.snapshotGeneration,
    required this.traces,
    required this.totalActiveDistanceMeters,
    required this.processedDriveCount,
    required this.skippedBrokenTraceCount,
    required this.viewport,
  });

  final int snapshotGeneration;
  final List<ResolvedWorldTrace> traces;
  final double totalActiveDistanceMeters;
  final int processedDriveCount;
  final int skippedBrokenTraceCount;
  final WorldMapViewport? viewport;

  bool get isEmpty => traces.isEmpty && skippedBrokenTraceCount == 0;
  bool get hasOnlyBrokenReferences =>
      traces.isEmpty && skippedBrokenTraceCount > 0;
}
