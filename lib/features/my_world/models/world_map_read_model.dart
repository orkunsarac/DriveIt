import 'active_world_trace.dart';
import 'matched_road_point.dart';
import 'world_trace_travel_direction.dart';

/// One active World index trace resolved to its read-only drawing geometry.
class ResolvedWorldTrace {
  const ResolvedWorldTrace({
    required this.trace,
    required this.geometry,
    required this.visualVariant,
    this.travelDirection = WorldTraceTravelDirection.unknown,
    this.directionConfidence = 0,
    this.firstProjectedOffset,
    this.lastProjectedOffset,
    this.projectedSampleCount = 0,
  });

  final ActiveWorldTrace trace;
  final List<MatchedRoadPoint> geometry;
  final int visualVariant;
  final WorldTraceTravelDirection travelDirection;
  final double directionConfidence;
  final double? firstProjectedOffset;
  final double? lastProjectedOffset;
  final int projectedSampleCount;

  ResolvedWorldTrace withVisualVariant(int value) => ResolvedWorldTrace(
    trace: trace,
    geometry: geometry,
    visualVariant: value,
    travelDirection: travelDirection,
    directionConfidence: directionConfidence,
    firstProjectedOffset: firstProjectedOffset,
    lastProjectedOffset: lastProjectedOffset,
    projectedSampleCount: projectedSampleCount,
  );

  ResolvedWorldTrace withTravelDirection(
    WorldTraceTravelDirection direction,
    double confidence,
  ) => ResolvedWorldTrace(
    trace: trace,
    geometry: geometry,
    visualVariant: visualVariant,
    travelDirection: direction,
    directionConfidence: confidence,
    firstProjectedOffset: firstProjectedOffset,
    lastProjectedOffset: lastProjectedOffset,
    projectedSampleCount: projectedSampleCount,
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
    required this.processedDriveSessionIds,
    required this.skippedBrokenTraceCount,
    required this.viewport,
  });

  final int snapshotGeneration;
  final List<ResolvedWorldTrace> traces;
  final double totalActiveDistanceMeters;
  final int processedDriveCount;
  final List<String> processedDriveSessionIds;
  final int skippedBrokenTraceCount;
  final WorldMapViewport? viewport;

  bool get isEmpty => traces.isEmpty && skippedBrokenTraceCount == 0;
  bool get hasOnlyBrokenReferences =>
      traces.isEmpty && skippedBrokenTraceCount > 0;
}
