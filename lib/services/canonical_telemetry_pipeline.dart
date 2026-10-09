import 'dart:math' as math;

import '../models/canonical_telemetry_point.dart';
import 'gps_gap_policy.dart';

/// Central calibration values for location validation and normalization.
/// These values define data quality only; they are not Drive Score rules.
class CanonicalTelemetryRules {
  static const double maximumAccuracyMeters = 30;
  static const double minimumSampleIntervalSeconds = .2;
  static const double maximumPlausibleSpeedMps = 70;
  static const double maximumPlausiblePositionSpeedMps = 80;
  static const double maximumPlausibleAccelerationMps2 = 8;
  static const double stationarySpeedMps = 1.5;
  static const double minimumDistanceMeters = 3;
  static const double stationaryDriftRadiusMeters = 10;
  static const double maximumNativeGeometryDifferenceMps = 8;
  static const double minimumHeadingSpeedMps = 1.5;
  static const int speedMedianWindowSize = 5;
  static const double maximumNativeSpeedAccuracyMps = 2;
  static const double motionEvidenceSeconds = 15;
  static const int maximumMotionEvidenceSamples = 80;
  static const double headingSmoothingFactor = .35;
  static const double minimumAltitudeMeters = -500;
  static const double maximumAltitudeMeters = 9000;
}

class RawTelemetryInput {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double speedMps;
  final double headingDegrees;
  final double altitudeMeters;
  final double accuracyMeters;
  final double? speedAccuracyMps;

  const RawTelemetryInput({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speedMps,
    required this.headingDegrees,
    required this.altitudeMeters,
    required this.accuracyMeters,
    this.speedAccuracyMps,
  });
}

/// Stateful canonicalizer for one drive.
///
/// A single instance must receive one drive's samples in arrival order. It
/// rejects invalid/out-of-order points, resolves native speed against geometry,
/// suppresses one-sample speed spikes, derives acceleration from canonical
/// speed and calculates the only distance delta used by route persistence.
class CanonicalTelemetryPipeline {
  final List<double> _speedWindow = <double>[];
  final List<RawTelemetryInput> _motionWindow = <RawTelemetryInput>[];
  CanonicalTelemetryPoint? _previous;
  CanonicalTelemetryPoint? _distanceAnchor;

  void reset() {
    _speedWindow.clear();
    _motionWindow.clear();
    _previous = null;
    _distanceAnchor = null;
  }

  /// Restores filter continuity from committed data; never reprocesses or
  /// rewrites historical telemetry, including across a GPS signal gap.
  void restoreCommitted(List<CanonicalTelemetryPoint> points) {
    reset();
    if (points.isEmpty) return;
    _previous = points.last;
    _motionWindow.add(_rawFromPoint(points.last));
    _speedWindow.addAll(
      points
          .skip(
            math.max(
              0,
              points.length - CanonicalTelemetryRules.speedMedianWindowSize,
            ),
          )
          .map((p) => p.speedMps),
    );
    _distanceAnchor = points.first;
    for (final point in points) {
      if (point.breakBefore || point.distanceFromPreviousMeters > 0) {
        _distanceAnchor = point;
      }
    }
  }

  Map<String, dynamic> checkpoint() {
    Map<String, dynamic>? encode(CanonicalTelemetryPoint? point) =>
        point == null
        ? null
        : {
            ...point.toMap(),
            'timeMicros': point.timestamp.microsecondsSinceEpoch,
            'timeIsUtc': point.timestamp.isUtc,
          };
    return {
      'version': 2,
      'speedWindow': List<double>.of(_speedWindow),
      'previous': encode(_previous),
      'distanceAnchor': encode(_distanceAnchor),
      'motionWindow': _motionWindow
          .map(
            (p) => {
              'latitude': p.latitude,
              'longitude': p.longitude,
              'timeMicros': p.timestamp!.microsecondsSinceEpoch,
              'timeIsUtc': p.timestamp!.isUtc,
              'speed': p.speedMps.isFinite ? p.speedMps : null,
              'accuracy': p.accuracyMeters,
              'speedAccuracy': p.speedAccuracyMps?.isFinite == true
                  ? p.speedAccuracyMps
                  : null,
            },
          )
          .toList(),
    };
  }

  void restoreCheckpoint(Map<String, dynamic> value) {
    if (value['version'] != 1 && value['version'] != 2) {
      throw StateError('Unsupported GPS filter checkpoint');
    }
    final window = (value['speedWindow'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    if (window.length > CanonicalTelemetryRules.speedMedianWindowSize ||
        window.any((v) => !v.isFinite || v < 0)) {
      throw StateError('Invalid GPS filter checkpoint');
    }
    CanonicalTelemetryPoint? decode(dynamic item) => item == null
        ? null
        : CanonicalTelemetryPoint.fromMap(
            Map<String, dynamic>.from(item as Map),
          );
    final previous = decode(value['previous']);
    final anchor = decode(value['distanceAnchor']);
    if (previous == null || anchor == null) {
      throw StateError('Incomplete GPS filter checkpoint');
    }
    reset();
    _speedWindow.addAll(window);
    _previous = previous;
    _distanceAnchor = anchor;
    if (value['version'] == 2) {
      for (final item in value['motionWindow'] as List) {
        final p = Map<String, dynamic>.from(item as Map);
        final raw = RawTelemetryInput(
          latitude: (p['latitude'] as num).toDouble(),
          longitude: (p['longitude'] as num).toDouble(),
          timestamp: DateTime.fromMicrosecondsSinceEpoch(
            p['timeMicros'] as int,
            isUtc: p['timeIsUtc'] == true,
          ),
          speedMps: (p['speed'] as num?)?.toDouble() ?? double.nan,
          headingDegrees: 0,
          altitudeMeters: 0,
          accuracyMeters: (p['accuracy'] as num).toDouble(),
          speedAccuracyMps: (p['speedAccuracy'] as num?)?.toDouble(),
        );
        if (!_isBasicInputValid(raw) ||
            (raw.timestamp!.isAfter(previous.timestamp)) ||
            (_motionWindow.isNotEmpty &&
                !raw.timestamp!.isAfter(_motionWindow.last.timestamp!))) {
          throw StateError('Invalid GPS motion checkpoint');
        }
        _motionWindow.add(raw);
      }
      if (_motionWindow.isEmpty ||
          _motionWindow.length >
              CanonicalTelemetryRules.maximumMotionEvidenceSamples) {
        throw StateError('Invalid GPS motion checkpoint');
      }
    } else {
      // Old checkpoint stays readable; new evidence accumulates prospectively.
      _motionWindow.add(_rawFromPoint(previous));
    }
  }

  CanonicalTelemetryPoint? add(RawTelemetryInput raw) {
    if (!_isBasicInputValid(raw)) return null;
    final timestamp = raw.timestamp!;
    final gapMicros = _previous == null
        ? 0
        : timestamp.difference(_previous!.timestamp).inMicroseconds;
    final discontinuity =
        _previous != null &&
        GpsGapPolicy.breaks(_previous!.timestamp, timestamp);
    if (discontinuity) {
      // Never infer motion/distance across an unobserved interval or carry the
      // acquisition window across a segment boundary.
      reset();
    }
    final previous = _previous;

    var dt = 0.0;
    var segmentDistance = 0.0;
    var geometrySpeed = 0.0;
    if (previous != null) {
      dt = timestamp.difference(previous.timestamp).inMicroseconds / 1000000;
      if (!dt.isFinite ||
          dt < CanonicalTelemetryRules.minimumSampleIntervalSeconds) {
        return null;
      }
      segmentDistance = _distanceMeters(
        previous.latitude,
        previous.longitude,
        raw.latitude,
        raw.longitude,
      );
      geometrySpeed = segmentDistance / dt;
      if (!geometrySpeed.isFinite ||
          geometrySpeed >
              CanonicalTelemetryRules.maximumPlausiblePositionSpeedMps) {
        return null;
      }
    }

    _motionWindow.add(raw);
    while (_motionWindow.length >
            CanonicalTelemetryRules.maximumMotionEvidenceSamples ||
        (_motionWindow.length > 1 &&
            timestamp
                        .difference(_motionWindow.first.timestamp!)
                        .inMicroseconds /
                    1000000 >
                CanonicalTelemetryRules.motionEvidenceSeconds)) {
      _motionWindow.removeAt(0);
    }
    final evidenceSpeed = _motionEvidenceSpeed();
    final nativeSpeed =
        _validNativeSpeed(raw.speedMps) &&
            (raw.speedAccuracyMps == null ||
                (raw.speedAccuracyMps!.isFinite &&
                    raw.speedAccuracyMps! >= 0 &&
                    raw.speedAccuracyMps! <=
                        CanonicalTelemetryRules.maximumNativeSpeedAccuracyMps))
        ? raw.speedMps
        : null;
    var speedSource = nativeSpeed == null ? 'unavailable' : 'native';
    var candidateSpeed = nativeSpeed ?? evidenceSpeed ?? 0;
    if ((nativeSpeed == null ||
            nativeSpeed <= CanonicalTelemetryRules.stationarySpeedMps) &&
        evidenceSpeed != null) {
      candidateSpeed = evidenceSpeed;
      speedSource = 'geometry_estimate';
    }
    if (nativeSpeed != null &&
        nativeSpeed <= CanonicalTelemetryRules.stationarySpeedMps &&
        evidenceSpeed == null &&
        !_stationaryEvidence()) {
      speedSource = 'unavailable';
    }
    if (previous != null && nativeSpeed != null) {
      final tolerance = math.max(
        CanonicalTelemetryRules.maximumNativeGeometryDifferenceMps,
        geometrySpeed * .75,
      );
      if ((nativeSpeed - geometrySpeed).abs() > tolerance) {
        candidateSpeed = evidenceSpeed ?? 0;
        speedSource = evidenceSpeed == null
            ? 'unavailable'
            : 'geometry_estimate';
      }
    }
    if (nativeSpeed != null &&
        nativeSpeed > CanonicalTelemetryRules.stationarySpeedMps &&
        geometrySpeed < .3 &&
        _stationaryEvidence()) {
      candidateSpeed = 0;
      speedSource = 'unavailable';
    }
    if ((previous == null &&
            !(nativeSpeed != null &&
                raw.speedAccuracyMps != null &&
                raw.speedAccuracyMps! > 0 &&
                raw.accuracyMeters <= 10)) ||
        (segmentDistance < CanonicalTelemetryRules.minimumDistanceMeters &&
            candidateSpeed <= CanonicalTelemetryRules.stationarySpeedMps)) {
      candidateSpeed = 0;
      if (previous == null) speedSource = 'unavailable';
    }

    if (speedSource == 'geometry_estimate' &&
        previous != null &&
        previous.speedMps <= CanonicalTelemetryRules.stationarySpeedMps &&
        previous.speedSource == 'unavailable') {
      // Bootstrap measured motion, not a fictitious ramp out of unknown zero.
      _speedWindow.clear();
    }
    _speedWindow.add(
      candidateSpeed.clamp(0, CanonicalTelemetryRules.maximumPlausibleSpeedMps),
    );
    if (_speedWindow.length > CanonicalTelemetryRules.speedMedianWindowSize) {
      _speedWindow.removeAt(0);
    }
    var canonicalSpeed = _median(_speedWindow);

    var acceleration = 0.0;
    var accelerationReliable =
        previous != null &&
        previous.speedSource != 'unavailable' &&
        previous.speedSource != 'held_estimate' &&
        speedSource != 'unavailable' &&
        speedSource != 'held_estimate';
    if (previous != null) {
      acceleration = (canonicalSpeed - previous.speedMps) / dt;
      if (!acceleration.isFinite ||
          acceleration.abs() >
              CanonicalTelemetryRules.maximumPlausibleAccelerationMps2) {
        // Keep independent measurements in the median window. Replacing them
        // with the previous output is a self-reinforcing zero-speed lock.
        final supporting = _speedWindow
            .where((v) => (v - canonicalSpeed).abs() <= 2)
            .length;
        if ((evidenceSpeed == null && !_stationaryEvidence()) ||
            supporting < 3) {
          canonicalSpeed = previous.speedMps;
          speedSource = 'held_estimate';
        }
        // A corroborated rebaseline recovers speed, not a measured acceleration.
        acceleration = 0;
        accelerationReliable = false;
      }
    }

    if (!accelerationReliable) acceleration = 0;
    final distance = _canonicalDistance(raw, canonicalSpeed, timestamp);
    final heading = _canonicalHeading(
      raw,
      canonicalSpeed,
      segmentDistance,
      previous,
    );
    final altitude =
        raw.altitudeMeters.isFinite &&
            raw.altitudeMeters >=
                CanonicalTelemetryRules.minimumAltitudeMeters &&
            raw.altitudeMeters <= CanonicalTelemetryRules.maximumAltitudeMeters
        ? raw.altitudeMeters
        : previous?.altitudeMeters ?? 0;

    final point = CanonicalTelemetryPoint(
      latitude: raw.latitude,
      longitude: raw.longitude,
      timestamp: timestamp,
      speedMps: canonicalSpeed,
      headingDegrees: heading,
      altitudeMeters: altitude,
      accuracyMeters: raw.accuracyMeters,
      distanceFromPreviousMeters: distance,
      accelerationMps2: acceleration,
      speedSource: speedSource,
      accelerationReliable: accelerationReliable,
      breakBefore: discontinuity,
      gapDurationMicros: gapMicros > GpsGapPolicy.shortGap.inMicroseconds
          ? gapMicros
          : 0,
    );
    _previous = point;
    _distanceAnchor ??= point;
    if (distance > 0) _distanceAnchor = point;
    return point;
  }

  bool _isBasicInputValid(RawTelemetryInput raw) =>
      raw.timestamp != null &&
      raw.latitude.isFinite &&
      raw.longitude.isFinite &&
      raw.latitude.abs() <= 90 &&
      raw.longitude.abs() <= 180 &&
      raw.accuracyMeters.isFinite &&
      raw.accuracyMeters >= 0 &&
      raw.accuracyMeters <= CanonicalTelemetryRules.maximumAccuracyMeters;

  bool _validNativeSpeed(double speed) =>
      speed.isFinite &&
      speed >= 0 &&
      speed <= CanonicalTelemetryRules.maximumPlausibleSpeedMps;

  double _canonicalDistance(
    RawTelemetryInput raw,
    double canonicalSpeed,
    DateTime timestamp,
  ) {
    final anchor = _distanceAnchor;
    if (anchor == null) return 0;
    final distance = _distanceMeters(
      anchor.latitude,
      anchor.longitude,
      raw.latitude,
      raw.longitude,
    );
    if (distance < CanonicalTelemetryRules.minimumDistanceMeters) return 0;
    if (canonicalSpeed <= CanonicalTelemetryRules.stationarySpeedMps &&
        distance <=
            math.max(
              CanonicalTelemetryRules.stationaryDriftRadiusMeters,
              anchor.accuracyMeters + raw.accuracyMeters,
            )) {
      return 0;
    }
    final dt = timestamp.difference(anchor.timestamp).inMicroseconds / 1000000;
    if (dt <= 0 ||
        distance / dt >
            CanonicalTelemetryRules.maximumPlausiblePositionSpeedMps) {
      return 0;
    }
    return distance;
  }

  double _canonicalHeading(
    RawTelemetryInput raw,
    double speed,
    double segmentDistance,
    CanonicalTelemetryPoint? previous,
  ) {
    final moving =
        speed >= CanonicalTelemetryRules.minimumHeadingSpeedMps ||
        segmentDistance >= CanonicalTelemetryRules.minimumDistanceMeters;
    if (!moving) return previous?.headingDegrees ?? 0;

    double candidate;
    if (_validHeading(raw.headingDegrees)) {
      candidate = raw.headingDegrees;
    } else if (previous != null && segmentDistance > 0) {
      candidate = _bearingDegrees(
        previous.latitude,
        previous.longitude,
        raw.latitude,
        raw.longitude,
      );
    } else {
      return previous?.headingDegrees ?? 0;
    }

    final old = previous?.headingDegrees;
    if (old == null || !_validHeading(old)) return candidate;
    final delta = ((candidate - old + 540) % 360) - 180;
    return (old +
            delta * CanonicalTelemetryRules.headingSmoothingFactor +
            360) %
        360;
  }

  bool _validHeading(double heading) =>
      heading.isFinite && heading >= 0 && heading < 360;

  RawTelemetryInput _rawFromPoint(CanonicalTelemetryPoint p) =>
      RawTelemetryInput(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        speedMps: p.speedMps,
        headingDegrees: p.headingDegrees,
        altitudeMeters: p.altitudeMeters,
        accuracyMeters: p.accuracyMeters,
      );

  double? _motionEvidenceSpeed() {
    if (_motionWindow.length < 3) return null;
    final first = _motionWindow.first, last = _motionWindow.last;
    final penultimate = _motionWindow[_motionWindow.length - 2];
    final latestDistance = _distanceMeters(
      penultimate.latitude,
      penultimate.longitude,
      last.latitude,
      last.longitude,
    );
    final latestDt =
        last.timestamp!.difference(penultimate.timestamp!).inMicroseconds /
        1000000;
    if (latestDistance / latestDt <=
        CanonicalTelemetryRules.stationarySpeedMps) {
      return null;
    }
    final dt =
        last.timestamp!.difference(first.timestamp!).inMicroseconds / 1000000;
    if (dt < 1) return null;
    final net = _distanceMeters(
      first.latitude,
      first.longitude,
      last.latitude,
      last.longitude,
    );
    if (net <=
        math.max(
          CanonicalTelemetryRules.stationaryDriftRadiusMeters,
          first.accuracyMeters + last.accuracyMeters,
        )) {
      return null;
    }
    var path = 0.0;
    for (var i = 1; i < _motionWindow.length; i++) {
      final a = _motionWindow[i - 1], b = _motionWindow[i];
      path += _distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    if (path <= 0 ||
        net / path < .8 ||
        net / dt > CanonicalTelemetryRules.maximumPlausibleSpeedMps) {
      return null;
    }
    return net / dt;
  }

  bool _stationaryEvidence() {
    if (_motionWindow.length < 3) return false;
    final cutoff = _motionWindow.last.timestamp!.subtract(
      const Duration(seconds: 3),
    );
    final points = _motionWindow
        .where((p) => !p.timestamp!.isBefore(cutoff))
        .toList();
    if (points.last.timestamp!
            .difference(points.first.timestamp!)
            .inMicroseconds <
        1000000) {
      return false;
    }
    return points.every(
      (p) =>
          (!_validNativeSpeed(p.speedMps) ||
              p.speedMps <= CanonicalTelemetryRules.stationarySpeedMps ||
              _distanceMeters(
                    points.first.latitude,
                    points.first.longitude,
                    p.latitude,
                    p.longitude,
                  ) <
                  CanonicalTelemetryRules.minimumDistanceMeters) &&
          _distanceMeters(
                points.first.latitude,
                points.first.longitude,
                p.latitude,
                p.longitude,
              ) <=
              CanonicalTelemetryRules.stationaryDriftRadiusMeters,
    );
  }

  double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _distanceMeters(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadius = 6371000.0;
    final lat1 = firstLatitude * math.pi / 180;
    final lat2 = secondLatitude * math.pi / 180;
    final deltaLat = (secondLatitude - firstLatitude) * math.pi / 180;
    final deltaLng = (secondLongitude - firstLongitude) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _bearingDegrees(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    final lat1 = firstLatitude * math.pi / 180;
    final lat2 = secondLatitude * math.pi / 180;
    final deltaLng = (secondLongitude - firstLongitude) * math.pi / 180;
    final y = math.sin(deltaLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
