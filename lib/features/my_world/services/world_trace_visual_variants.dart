import '../models/active_world_trace.dart';

/// Stable presentation-only graph colouring for adjacent active traces.
class WorldTraceVisualVariants {
  const WorldTraceVisualVariants({this.variantCount = 4});

  final int variantCount;

  Map<String, int> assign(Iterable<ActiveWorldTrace> input) {
    final traces = input.toList(growable: false);
    final sources = traces.map((trace) => trace.sourceDriveSessionId).toSet()
      ..removeWhere((value) => value.isEmpty);
    final orderedSources = sources.toList()..sort();
    final neighbours = <String, Set<String>>{
      for (final source in orderedSources) source: <String>{},
    };
    final orderedTraces = [...traces]
      ..sort((a, b) {
        final road = a.validatedRoadId.compareTo(b.validatedRoadId);
        if (road != 0) return road;
        final section = a.matchedSectionId.compareTo(b.matchedSectionId);
        if (section != 0) return section;
        return a.startOffsetMeters.compareTo(b.startOffsetMeters);
      });
    final geographicTraces = [...traces]
      ..sort((a, b) {
        final latitudeA = (a.minLatitude + a.maxLatitude) / 2;
        final latitudeB = (b.minLatitude + b.maxLatitude) / 2;
        final latitude = latitudeA.compareTo(latitudeB);
        if (latitude != 0) return latitude;
        final longitudeA = (a.minLongitude + a.maxLongitude) / 2;
        final longitudeB = (b.minLongitude + b.maxLongitude) / 2;
        return longitudeA.compareTo(longitudeB);
      });
    for (final sequence in [orderedTraces, geographicTraces]) {
      for (var i = 1; i < sequence.length; i++) {
        final first = sequence[i - 1];
        final second = sequence[i];
        final sameRoadBoundary =
            first.validatedRoadId == second.validatedRoadId &&
            first.matchedSectionId == second.matchedSectionId &&
            first.directionKey == second.directionKey &&
            (first.endOffsetMeters - second.startOffsetMeters).abs() <= 5;
        const coordinateTolerance = .0003;
        final nearbyBounds =
            first.minLatitude <= second.maxLatitude + coordinateTolerance &&
            first.maxLatitude + coordinateTolerance >= second.minLatitude &&
            first.minLongitude <= second.maxLongitude + coordinateTolerance &&
            first.maxLongitude + coordinateTolerance >= second.minLongitude;
        final adjacent = sameRoadBoundary || nearbyBounds;
        if (adjacent &&
            first.sourceDriveSessionId != second.sourceDriveSessionId) {
          neighbours[first.sourceDriveSessionId]?.add(
            second.sourceDriveSessionId,
          );
          neighbours[second.sourceDriveSessionId]?.add(
            first.sourceDriveSessionId,
          );
        }
      }
    }

    final result = <String, int>{};
    for (final source in orderedSources) {
      final unavailable = neighbours[source]!
          .map((neighbour) => result[neighbour])
          .whereType<int>()
          .toSet();
      final preferred = _stableHash(source) % variantCount;
      var selected = preferred;
      for (var attempt = 0; attempt < variantCount; attempt++) {
        final candidate = (preferred + attempt) % variantCount;
        if (!unavailable.contains(candidate)) {
          selected = candidate;
          break;
        }
      }
      result[source] = selected;
    }
    return Map.unmodifiable(result);
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
