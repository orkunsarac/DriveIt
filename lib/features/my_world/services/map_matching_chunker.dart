import '../config/my_world_rules.dart';
import '../models/map_matching_input.dart';

class MapMatchingChunker {
  const MapMatchingChunker();

  List<MapMatchingChunk> build(List<MapMatchingTrace> traces) {
    final chunks = <MapMatchingChunk>[];
    for (final trace in traces) {
      var start = 0;
      var chunkIndex = 0;
      while (start < trace.points.length) {
        final end = (start + MyWorldRules.mapMatchingMaximumCoordinates).clamp(
          0,
          trace.points.length,
        );
        final points = trace.points.sublist(start, end);
        if (points.length >= 2) {
          chunks.add(
            MapMatchingChunk(
              traceIndex: trace.index,
              chunkIndex: chunkIndex++,
              points: List.unmodifiable(points),
            ),
          );
        }
        if (end == trace.points.length) break;
        start = end - MyWorldRules.mapMatchingChunkOverlap;
      }
    }
    return List.unmodifiable(chunks);
  }
}
