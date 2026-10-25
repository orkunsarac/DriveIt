import 'dart:math' as math;

import '../../models/drive_session.dart';
import 'replay_telemetry_adapter.dart';

enum ReplayFrameSpeedKind {
  nativeCanonical,
  geometryEstimate,
  interpolatedNative,
  interpolatedGeometryEstimate,
  legacyEstimate,
  unavailable,
}

class ReplayPoint {
  final double latitude;
  final double longitude;
  final Duration elapsed;
  final double distanceMeters;
  final double speedKmh;
  final double heading;
  final int routeSegmentId;

  const ReplayPoint({
    required this.latitude,
    required this.longitude,
    required this.elapsed,
    required this.distanceMeters,
    required this.speedKmh,
    required this.heading,
    this.routeSegmentId = 0,
  });
}

class ReplayFrame {
  final double? latitude;
  final double? longitude;
  final Duration elapsed;
  final double distanceMeters;
  final double? speedKmh;
  final double heading;
  final int segmentIndex;
  final int routeSegmentId;
  final bool isGap;
  final ReplayFrameSpeedKind speedKind;

  const ReplayFrame({
    required this.latitude,
    required this.longitude,
    required this.elapsed,
    required this.distanceMeters,
    required this.speedKmh,
    required this.heading,
    required this.segmentIndex,
    this.routeSegmentId = 0,
    this.isGap = false,
    this.speedKind = ReplayFrameSpeedKind.legacyEstimate,
  });
}

class ReplayInterpolator {
  const ReplayInterpolator._();

  static List<ReplayPoint> buildTimeline(DriveSession drive) {
    final coordinates = <({double latitude, double longitude, int segment})>[];
    var segment = 0;
    for (final point in drive.route) {
      if (point.breakBefore && coordinates.isNotEmpty) segment++;
      if (!_validCoordinate(point.latitude, point.longitude)) continue;
      if (coordinates.isNotEmpty && coordinates.last.segment == segment) {
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
      coordinates.add((
        latitude: point.latitude,
        longitude: point.longitude,
        segment: segment,
      ));
    }
    if (coordinates.isEmpty) return const [];

    final cumulative = <double>[0];
    for (var index = 1; index < coordinates.length; index++) {
      cumulative.add(
        cumulative.last +
            (coordinates[index - 1].segment == coordinates[index].segment
                ? _distanceMeters(
                    coordinates[index - 1].latitude,
                    coordinates[index - 1].longitude,
                    coordinates[index].latitude,
                    coordinates[index].longitude,
                  )
                : 0),
      );
    }
    final routeDistance = cumulative.last;
    final totalMilliseconds = math.max(0, drive.durationSeconds) * 1000;
    final edgeProgress = <int>[0];
    for (var index = 1; index < coordinates.length; index++) {
      edgeProgress.add(
        edgeProgress.last +
            (coordinates[index - 1].segment == coordinates[index].segment
                ? 1
                : 0),
      );
    }
    final fallbackStep = edgeProgress.last == 0
        ? 0.0
        : totalMilliseconds / edgeProgress.last;
    final safeAverage = drive.averageSpeed.isFinite
        ? math.max(0.0, drive.averageSpeed)
        : 0.0;
    final safeMaximum = drive.maxSpeed.isFinite
        ? math.max(safeAverage, drive.maxSpeed)
        : safeAverage;

    return List.generate(coordinates.length, (index) {
      final ratio = routeDistance > 0
          ? cumulative[index] / routeDistance
          : (fallbackStep == 0 ? 0.0 : edgeProgress[index] / edgeProgress.last);
      final heading =
          index + 1 < coordinates.length &&
              coordinates[index + 1].segment == coordinates[index].segment
          ? bearing(
              coordinates[index].latitude,
              coordinates[index].longitude,
              coordinates[index + 1].latitude,
              coordinates[index + 1].longitude,
            )
          : index > 0 &&
                coordinates[index - 1].segment == coordinates[index].segment
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
        routeSegmentId: coordinates[index].segment,
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
      routeSegmentId: start.routeSegmentId,
    );
  }

  /// Evaluate canonical samples on recorded GPS elapsed time. Segment changes
  /// are temporal gaps: no location, speed, or distance interpolation crosses
  /// them, while the elapsed GPS clock continues.
  static ReplayFrame frameAtTelemetry(
    ReplayTelemetryData data,
    Duration elapsed,
  ) {
    final samples = data.samples;
    if (samples.isEmpty) {
      return ReplayFrame(
        latitude: null,
        longitude: null,
        elapsed: Duration.zero,
        distanceMeters: 0,
        speedKmh: null,
        heading: 0,
        segmentIndex: 0,
        isGap: true,
        speedKind: ReplayFrameSpeedKind.unavailable,
      );
    }
    Duration timeAt(int index) => samples[index].elapsed ?? Duration.zero;
    ReplayFrame atSample(int index) {
      final sample = samples[index];
      final kind = switch (sample.speedSource) {
        ReplaySpeedSource.nativeCanonical =>
          ReplayFrameSpeedKind.nativeCanonical,
        ReplaySpeedSource.geometryEstimate =>
          ReplayFrameSpeedKind.geometryEstimate,
        ReplaySpeedSource.unavailable => ReplayFrameSpeedKind.unavailable,
      };
      final heading =
          index + 1 < samples.length &&
              samples[index + 1].segmentId == sample.segmentId
          ? bearing(
              sample.latitude,
              sample.longitude,
              samples[index + 1].latitude,
              samples[index + 1].longitude,
            )
          : index > 0 && samples[index - 1].segmentId == sample.segmentId
          ? bearing(
              samples[index - 1].latitude,
              samples[index - 1].longitude,
              sample.latitude,
              sample.longitude,
            )
          : 0.0;
      return ReplayFrame(
        latitude: sample.latitude,
        longitude: sample.longitude,
        elapsed: timeAt(index),
        distanceMeters: sample.cumulativeDistanceMeters,
        speedKmh: sample.speedKmh,
        heading: heading,
        segmentIndex: sample.sourceIndex,
        routeSegmentId: sample.segmentId,
        speedKind: kind,
      );
    }

    final target = elapsed < Duration.zero ? Duration.zero : elapsed;
    if (target <= timeAt(0)) return atSample(0);
    if (target >= timeAt(samples.length - 1)) {
      return atSample(samples.length - 1);
    }
    var low = 0;
    var high = samples.length - 1;
    while (low + 1 < high) {
      final middle = (low + high) >> 1;
      if (timeAt(middle) <= target) {
        low = middle;
      } else {
        high = middle;
      }
    }
    if (target == timeAt(low)) return atSample(low);
    if (target == timeAt(high)) return atSample(high);
    final start = samples[low];
    final finish = samples[high];
    if (start.segmentId != finish.segmentId || finish.breakBefore) {
      return ReplayFrame(
        latitude: null,
        longitude: null,
        elapsed: target,
        distanceMeters: start.cumulativeDistanceMeters,
        speedKmh: null,
        heading: 0,
        segmentIndex: start.sourceIndex,
        routeSegmentId: start.segmentId,
        isGap: true,
        speedKind: ReplayFrameSpeedKind.unavailable,
      );
    }
    final span = timeAt(high).inMicroseconds - timeAt(low).inMicroseconds;
    if (span <= 0) return atSample(low);
    final fraction =
        ((target.inMicroseconds - timeAt(low).inMicroseconds) / span).clamp(
          0.0,
          1.0,
        );
    final sameSpeedSource = start.speedSource == finish.speedSource;
    final speed =
        start.speedKmh != null && finish.speedKmh != null && sameSpeedSource
        ? _lerp(start.speedKmh!, finish.speedKmh!, fraction)
        : null;
    final speedKind = speed == null
        ? ReplayFrameSpeedKind.unavailable
        : switch (start.speedSource) {
            ReplaySpeedSource.nativeCanonical =>
              ReplayFrameSpeedKind.interpolatedNative,
            ReplaySpeedSource.geometryEstimate =>
              ReplayFrameSpeedKind.interpolatedGeometryEstimate,
            ReplaySpeedSource.unavailable => ReplayFrameSpeedKind.unavailable,
          };
    final distance = finish.distanceIncrementMeters != null
        ? _lerp(
            start.cumulativeDistanceMeters,
            finish.cumulativeDistanceMeters,
            fraction,
          )
        : start.cumulativeDistanceMeters;
    return ReplayFrame(
      latitude: _lerp(start.latitude, finish.latitude, fraction),
      longitude: _lerp(start.longitude, finish.longitude, fraction),
      elapsed: target,
      distanceMeters: distance,
      speedKmh: speed,
      heading: bearing(
        start.latitude,
        start.longitude,
        finish.latitude,
        finish.longitude,
      ),
      segmentIndex: start.sourceIndex,
      routeSegmentId: start.segmentId,
      speedKind: speedKind,
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
    routeSegmentId: point.routeSegmentId,
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
