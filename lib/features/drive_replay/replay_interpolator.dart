import 'dart:math' as math;

import '../../models/drive_session.dart';

class ReplayPoint {
  final double latitude;
  final double longitude;
  final Duration elapsed;
  final double distanceMeters;
  final double speedKmh;
  final double heading;

  const ReplayPoint({
    required this.latitude,
    required this.longitude,
    required this.elapsed,
    required this.distanceMeters,
    required this.speedKmh,
    required this.heading,
  });
}

class ReplayFrame {
  final double latitude;
  final double longitude;
  final Duration elapsed;
  final double distanceMeters;
  final double speedKmh;
  final double heading;
  final int segmentIndex;

  const ReplayFrame({
    required this.latitude,
    required this.longitude,
    required this.elapsed,
    required this.distanceMeters,
    required this.speedKmh,
    required this.heading,
    required this.segmentIndex,
  });
}

class ReplayInterpolator {
  const ReplayInterpolator._();

  static List<ReplayPoint> buildTimeline(DriveSession drive) {
    final coordinates = <({double latitude, double longitude})>[];
    for (final point in drive.route) {
      if (!_validCoordinate(point.latitude, point.longitude)) continue;
      if (coordinates.isNotEmpty) {
        final previous = coordinates.last;
        if (_distanceMeters(
              previous.latitude,
              previous.longitude,
              point.latitude,
              point.longitude,
            ) <
            0.5) {
          continue;
        }
      }
      coordinates.add((latitude: point.latitude, longitude: point.longitude));
    }
    if (coordinates.isEmpty) return const [];

    final cumulative = <double>[0];
    for (var index = 1; index < coordinates.length; index++) {
      cumulative.add(
        cumulative.last +
            _distanceMeters(
              coordinates[index - 1].latitude,
              coordinates[index - 1].longitude,
              coordinates[index].latitude,
              coordinates[index].longitude,
            ),
      );
    }
    final routeDistance = cumulative.last;
    final totalMilliseconds = math.max(0, drive.durationSeconds) * 1000;
    final fallbackStep = coordinates.length <= 1
        ? 0.0
        : totalMilliseconds / (coordinates.length - 1);
    final safeAverage = drive.averageSpeed.isFinite
        ? math.max(0.0, drive.averageSpeed)
        : 0.0;
    final safeMaximum = drive.maxSpeed.isFinite
        ? math.max(safeAverage, drive.maxSpeed)
        : safeAverage;

    return List.generate(coordinates.length, (index) {
      final ratio = routeDistance > 0
          ? cumulative[index] / routeDistance
          : (coordinates.length <= 1 ? 0.0 : index / (coordinates.length - 1));
      final heading = index + 1 < coordinates.length
          ? bearing(
              coordinates[index].latitude,
              coordinates[index].longitude,
              coordinates[index + 1].latitude,
              coordinates[index + 1].longitude,
            )
          : index > 0
          ? bearing(
              coordinates[index - 1].latitude,
              coordinates[index - 1].longitude,
              coordinates[index].latitude,
              coordinates[index].longitude,
            )
          : 0.0;
      // RoutePoint currently persists coordinates only. Keep the estimate
      // bounded by recorded session-level telemetry instead of inventing peaks.
      final edgeFactor = coordinates.length <= 2
          ? 1.0
          : math.min(1.0, math.min(ratio * 8, (1 - ratio) * 8));
      final estimatedSpeed = (safeAverage * edgeFactor).clamp(0.0, safeMaximum);
      return ReplayPoint(
        latitude: coordinates[index].latitude,
        longitude: coordinates[index].longitude,
        elapsed: Duration(
          milliseconds: routeDistance > 0
              ? (totalMilliseconds * ratio).round()
              : (fallbackStep * index).round(),
        ),
        distanceMeters: cumulative[index],
        speedKmh: estimatedSpeed,
        heading: heading,
      );
    });
  }

  static ReplayFrame frameAt(List<ReplayPoint> points, Duration elapsed) {
    if (points.isEmpty) {
      return ReplayFrame(
        latitude: 0,
        longitude: 0,
        elapsed: Duration.zero,
        distanceMeters: 0,
        speedKmh: 0,
        heading: 0,
        segmentIndex: 0,
      );
    }
    if (points.length == 1 || elapsed <= points.first.elapsed) {
      final point = points.first;
      return _pointFrame(point, elapsed, 0);
    }
    if (elapsed >= points.last.elapsed) {
      return _pointFrame(points.last, points.last.elapsed, points.length - 1);
    }

    var low = 0;
    var high = points.length - 1;
    while (low + 1 < high) {
      final middle = (low + high) >> 1;
      if (points[middle].elapsed <= elapsed) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final start = points[low];
    final finish = points[high];
    final span = finish.elapsed.inMicroseconds - start.elapsed.inMicroseconds;
    final offset = elapsed.inMicroseconds - start.elapsed.inMicroseconds;
    final fraction = span <= 0 ? 0.0 : (offset / span).clamp(0.0, 1.0);
    return ReplayFrame(
      latitude: _lerp(start.latitude, finish.latitude, fraction),
      longitude: _lerp(start.longitude, finish.longitude, fraction),
      elapsed: elapsed,
      distanceMeters: _lerp(
        start.distanceMeters,
        finish.distanceMeters,
        fraction,
      ),
      speedKmh: _lerp(start.speedKmh, finish.speedKmh, fraction),
      heading: interpolateHeading(start.heading, finish.heading, fraction),
      segmentIndex: low,
    );
  }

  static double interpolateHeading(double start, double end, double fraction) {
    final normalizedStart = _normalizeHeading(start);
    final normalizedEnd = _normalizeHeading(end);
    final delta = ((normalizedEnd - normalizedStart + 540) % 360) - 180;
    return _normalizeHeading(normalizedStart + delta * fraction);
  }

  static double bearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final startLat = _radians(startLatitude);
    final endLat = _radians(endLatitude);
    final longitudeDelta = _radians(endLongitude - startLongitude);
    final y = math.sin(longitudeDelta) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(longitudeDelta);
    return _normalizeHeading(math.atan2(y, x) * 180 / math.pi);
  }

  static ReplayFrame _pointFrame(
    ReplayPoint point,
    Duration elapsed,
    int index,
  ) => ReplayFrame(
    latitude: point.latitude,
    longitude: point.longitude,
    elapsed: elapsed,
    distanceMeters: point.distanceMeters,
    speedKmh: point.speedKmh,
    heading: point.heading,
    segmentIndex: index,
  );

  static bool _validCoordinate(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static double _distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadius = 6371000.0;
    final latitudeDelta = _radians(endLatitude - startLatitude);
    final longitudeDelta = _radians(endLongitude - startLongitude);
    final startLat = _radians(startLatitude);
    final endLat = _radians(endLatitude);
    final value =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(startLat) *
            math.cos(endLat) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  static double _radians(double value) => value * math.pi / 180;
  static double _normalizeHeading(double value) => (value % 360 + 360) % 360;
  static double _lerp(double start, double end, double fraction) =>
      start + (end - start) * fraction;
}
