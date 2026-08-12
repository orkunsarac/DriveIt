import '../../../models/route_point.dart';
import '../config/my_world_rules.dart';
import '../models/map_matching_input.dart';
import 'geo_distance.dart';

class GpsPreprocessingResult {
  final List<MapMatchingTrace> traces;
  final int inputPointCount;
  final int acceptedPointCount;
  final int invalidPointCount;
  final int tooClosePointCount;
  final int jumpSplitCount;

  const GpsPreprocessingResult({
    required this.traces,
    required this.inputPointCount,
    required this.acceptedPointCount,
    required this.invalidPointCount,
    required this.tooClosePointCount,
    required this.jumpSplitCount,
  });
}

class GpsRoutePreprocessor {
  const GpsRoutePreprocessor();

  GpsPreprocessingResult clean(List<RoutePoint> route) {
    final traces = <MapMatchingTrace>[];
    var current = <MapMatchingInputPoint>[];
    var invalid = 0;
    var tooClose = 0;
    var jumpSplits = 0;
    var accepted = 0;

    void closeCurrentTrace() {
      if (current.length >= 2) {
        traces.add(
          MapMatchingTrace(
            index: traces.length,
            points: List.unmodifiable(current),
          ),
        );
      }
      current = <MapMatchingInputPoint>[];
    }

    for (final point in route) {
      if (!_isValid(point.latitude, point.longitude)) {
        invalid++;
        closeCurrentTrace();
        continue;
      }

      final candidate = MapMatchingInputPoint(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (current.isEmpty) {
        current.add(candidate);
        accepted++;
        continue;
      }

      final previous = current.last;
      final distance = GeoDistance.between(
        previous.latitude,
        previous.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      if (distance < MyWorldRules.minimumUsefulPointDistanceMeters) {
        tooClose++;
        continue;
      }
      if (distance > MyWorldRules.maximumPlausiblePointJumpMeters) {
        jumpSplits++;
        closeCurrentTrace();
      }
      current.add(candidate);
      accepted++;
    }
    closeCurrentTrace();

    return GpsPreprocessingResult(
      traces: List.unmodifiable(traces),
      inputPointCount: route.length,
      acceptedPointCount: accepted,
      invalidPointCount: invalid,
      tooClosePointCount: tooClose,
      jumpSplitCount: jumpSplits,
    );
  }

  bool _isValid(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
