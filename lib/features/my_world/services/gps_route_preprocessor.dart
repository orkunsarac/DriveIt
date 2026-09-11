import '../../../models/route_point.dart';
import '../../../models/canonical_telemetry_point.dart';
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
  final int plausibleGapContinuationCount;

  const GpsPreprocessingResult({
    required this.traces,
    required this.inputPointCount,
    required this.acceptedPointCount,
    required this.invalidPointCount,
    required this.tooClosePointCount,
    required this.jumpSplitCount,
    this.plausibleGapContinuationCount = 0,
  });
}

class GpsRoutePreprocessor {
  const GpsRoutePreprocessor();

  GpsPreprocessingResult clean(
    List<RoutePoint> route, {
    List<CanonicalTelemetryPoint> canonicalTelemetry = const [],
  }) {
    final traces = <MapMatchingTrace>[];
    var current = <MapMatchingInputPoint>[];
    var invalid = 0;
    var tooClose = 0;
    var jumpSplits = 0;
    var accepted = 0;
    var plausibleGapContinuations = 0;
    int? previousAcceptedRouteIndex;
    final alignedTelemetry = _alignTelemetry(route, canonicalTelemetry);

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

    for (var routeIndex = 0; routeIndex < route.length; routeIndex++) {
      final point = route[routeIndex];
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
        previousAcceptedRouteIndex = routeIndex;
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
        final previousTelemetry = previousAcceptedRouteIndex == null
            ? null
            : alignedTelemetry[previousAcceptedRouteIndex];
        final currentTelemetry = alignedTelemetry[routeIndex];
        if (_isPlausibleSignalGap(
          distanceMeters: distance,
          previous: previousTelemetry,
          current: currentTelemetry,
        )) {
          plausibleGapContinuations++;
        } else {
          jumpSplits++;
          closeCurrentTrace();
        }
      }
      current.add(candidate);
      accepted++;
      previousAcceptedRouteIndex = routeIndex;
    }
    closeCurrentTrace();

    return GpsPreprocessingResult(
      traces: List.unmodifiable(traces),
      inputPointCount: route.length,
      acceptedPointCount: accepted,
      invalidPointCount: invalid,
      tooClosePointCount: tooClose,
      jumpSplitCount: jumpSplits,
      plausibleGapContinuationCount: plausibleGapContinuations,
    );
  }

  List<CanonicalTelemetryPoint?> _alignTelemetry(
    List<RoutePoint> route,
    List<CanonicalTelemetryPoint> telemetry,
  ) {
    if (telemetry.isEmpty) {
      return List<CanonicalTelemetryPoint?>.filled(route.length, null);
    }
    final output = List<CanonicalTelemetryPoint?>.filled(route.length, null);
    var telemetryIndex = 0;
    for (var routeIndex = 0; routeIndex < route.length; routeIndex++) {
      final routePoint = route[routeIndex];
      while (telemetryIndex < telemetry.length) {
        final candidate = telemetry[telemetryIndex++];
        if (GeoDistance.between(
              routePoint.latitude,
              routePoint.longitude,
              candidate.latitude,
              candidate.longitude,
            ) <=
            MyWorldRules.canonicalRouteAlignmentToleranceMeters) {
          output[routeIndex] = candidate;
          break;
        }
      }
    }
    return output;
  }

  bool _isPlausibleSignalGap({
    required double distanceMeters,
    required CanonicalTelemetryPoint? previous,
    required CanonicalTelemetryPoint? current,
  }) {
    if (previous == null || current == null) return false;
    final elapsedSeconds =
        current.timestamp.difference(previous.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (!elapsedSeconds.isFinite || elapsedSeconds <= 0) return false;
    final requiredAverageSpeed = distanceMeters / elapsedSeconds;
    return requiredAverageSpeed.isFinite &&
        requiredAverageSpeed <= MyWorldRules.maximumPlausibleGapAverageSpeedMps;
  }

  bool _isValid(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
