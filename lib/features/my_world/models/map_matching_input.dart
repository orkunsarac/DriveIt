class MapMatchingInputPoint {
  final double latitude;
  final double longitude;

  const MapMatchingInputPoint({
    required this.latitude,
    required this.longitude,
  });
}

class MapMatchingTrace {
  final int index;
  final List<MapMatchingInputPoint> points;

  const MapMatchingTrace({required this.index, required this.points});
}

class MapMatchingChunk {
  final int traceIndex;
  final int chunkIndex;
  final List<MapMatchingInputPoint> points;

  const MapMatchingChunk({
    required this.traceIndex,
    required this.chunkIndex,
    required this.points,
  });
}
