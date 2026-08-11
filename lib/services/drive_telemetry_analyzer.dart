import 'dart:math' as math;

import '../models/drive_metrics.dart';
import '../models/drive_telemetry_sample.dart';

/// Central, testable thresholds for the telemetry analysis pipeline.
class DriveAnalysisRules {
  static const double maximumAccuracyMeters = 30;
  static const double minimumSampleIntervalSeconds = .2;
  static const double maximumSampleIntervalSeconds = 5;
  static const double stationarySpeedMps = 1.5;
  static const double maximumPlausibleSpeedMps = 70;
  static const double maximumPlausiblePositionSpeedMps = 80;
  static const double maximumPlausibleAccelerationMps2 = 8;
  static const double hardAccelerationMps2 = 2.5;
  static const double hardBrakeMps2 = -3;
  static const double eventReleaseRatio = .5;
  static const double minimumCornerSpeedKmh = 15;
  static const double cornerHeadingDeltaDegrees = 15;
  static const double sharpTurnHeadingDeltaDegrees = 45;
  static const double minimumTurnSampleDegrees = 3;
  static const int sustainedCornerSamples = 2;
  static const int cornerEndQuietSamples = 2;
  static const double altitudeJumpMeters = 30;
  static const double minimumAltitudeDeltaMeters = 2;
  static const double sixtyKmhMps = 60 / 3.6;
  static const double hundredKmhMps = 100 / 3.6;
  static const double targetConfirmationToleranceMps = 2 / 3.6;
}

class DriveTelemetryAnalyzer {
  const DriveTelemetryAnalyzer();

  DriveMetrics analyze(Iterable<DriveTelemetrySample> input) {
    final samples = _filter(input);
    if (samples.length < 2) return const DriveMetrics();

    var hardBrakes = 0;
    var hardAccelerations = 0;
    var accelerationEvent = false;
    var brakeEvent = false;
    var maxAcceleration = 0.0;
    var maxBraking = 0.0;

    var cornerCount = 0;
    var sharpTurns = 0;
    var turnDegrees = 0.0;
    var turnSamples = 0;
    var quietTurnSamples = 0;
    var cornerCounted = false;
    var sharpCounted = false;
    var maxCornerSpeed = 0.0;

    var hasAltitude = false;
    var maxAltitude = 0.0;
    var altitudeGain = 0.0;
    var altitudeLoss = 0.0;
    double? previousAltitude;

    double? bestZeroToHundred;
    double? bestSixtyToHundred;
    DateTime? zeroStart;
    DateTime? sixtyStart;
    DateTime? pendingZeroFinish;
    DateTime? pendingSixtyFinish;

    final speedWindow = <double>[];
    double? previousSpeed;
    DateTime? previousTime;

    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      speedWindow.add(sample.speedMps);
      if (speedWindow.length > 3) speedWindow.removeAt(0);
      final speed = _median(speedWindow);

      if (_validAltitude(sample.altitudeMeters)) {
        hasAltitude = true;
        maxAltitude = previousAltitude == null
            ? sample.altitudeMeters
            : math.max(maxAltitude, sample.altitudeMeters);
        if (previousAltitude != null) {
          final delta = sample.altitudeMeters - previousAltitude;
          if (delta.abs() <= DriveAnalysisRules.altitudeJumpMeters &&
              delta.abs() >= DriveAnalysisRules.minimumAltitudeDeltaMeters) {
            if (delta > 0) {
              altitudeGain += delta;
            } else {
              altitudeLoss += delta.abs();
            }
          }
        }
        previousAltitude = sample.altitudeMeters;
      }

      if (previousSpeed != null && previousTime != null) {
        final dt = _secondsBetween(previousTime, sample.timestamp);
        final acceleration = (speed - previousSpeed) / dt;
        if (acceleration.abs() <=
            DriveAnalysisRules.maximumPlausibleAccelerationMps2) {
          maxAcceleration = math.max(maxAcceleration, acceleration);
          maxBraking = math.min(maxBraking, acceleration);

          if (acceleration >= DriveAnalysisRules.hardAccelerationMps2) {
            if (!accelerationEvent) hardAccelerations++;
            accelerationEvent = true;
          } else if (acceleration <
              DriveAnalysisRules.hardAccelerationMps2 *
                  DriveAnalysisRules.eventReleaseRatio) {
            accelerationEvent = false;
          }
          if (acceleration <= DriveAnalysisRules.hardBrakeMps2) {
            if (!brakeEvent) hardBrakes++;
            brakeEvent = true;
          } else if (acceleration >
              DriveAnalysisRules.hardBrakeMps2 *
                  DriveAnalysisRules.eventReleaseRatio) {
            brakeEvent = false;
          }
        }

        if (pendingZeroFinish != null) {
          if (speed >=
              DriveAnalysisRules.hundredKmhMps -
                  DriveAnalysisRules.targetConfirmationToleranceMps) {
            bestZeroToHundred = _shorter(
              bestZeroToHundred,
              _secondsBetween(zeroStart!, pendingZeroFinish),
            );
          }
          pendingZeroFinish = null;
          zeroStart = null;
        }
        if (pendingSixtyFinish != null) {
          if (speed >=
              DriveAnalysisRules.hundredKmhMps -
                  DriveAnalysisRules.targetConfirmationToleranceMps) {
            bestSixtyToHundred = _shorter(
              bestSixtyToHundred,
              _secondsBetween(sixtyStart!, pendingSixtyFinish),
            );
          }
          pendingSixtyFinish = null;
          sixtyStart = null;
        }

        if (previousSpeed <= DriveAnalysisRules.stationarySpeedMps &&
            speed > DriveAnalysisRules.stationarySpeedMps) {
          zeroStart = previousTime;
        }
        if (previousSpeed < DriveAnalysisRules.sixtyKmhMps &&
            speed >= DriveAnalysisRules.sixtyKmhMps) {
          sixtyStart = _crossingTime(
            previousTime,
            sample.timestamp,
            previousSpeed,
            speed,
            DriveAnalysisRules.sixtyKmhMps,
          );
        }
        if (previousSpeed < DriveAnalysisRules.hundredKmhMps &&
            speed >= DriveAnalysisRules.hundredKmhMps) {
          final crossing = _crossingTime(
            previousTime,
            sample.timestamp,
            previousSpeed,
            speed,
            DriveAnalysisRules.hundredKmhMps,
          );
          if (zeroStart != null) pendingZeroFinish = crossing;
          if (sixtyStart != null) pendingSixtyFinish = crossing;
        }
      } else if (speed <= DriveAnalysisRules.stationarySpeedMps) {
        zeroStart = sample.timestamp;
      }

      if (index > 0 &&
          speed >= DriveAnalysisRules.minimumCornerSpeedKmh / 3.6) {
        final delta = _headingDelta(samples[index - 1].heading, sample.heading);
        if (delta >= DriveAnalysisRules.minimumTurnSampleDegrees) {
          turnDegrees += delta;
          turnSamples++;
          quietTurnSamples = 0;
          maxCornerSpeed = math.max(maxCornerSpeed, speed * 3.6);
          if (!cornerCounted &&
              turnSamples >= DriveAnalysisRules.sustainedCornerSamples &&
              turnDegrees >= DriveAnalysisRules.cornerHeadingDeltaDegrees) {
            cornerCount++;
            cornerCounted = true;
          }
          if (!sharpCounted &&
              turnSamples >= DriveAnalysisRules.sustainedCornerSamples &&
              turnDegrees >= DriveAnalysisRules.sharpTurnHeadingDeltaDegrees) {
            sharpTurns++;
            sharpCounted = true;
          }
        } else {
          quietTurnSamples++;
          if (quietTurnSamples >= DriveAnalysisRules.cornerEndQuietSamples) {
            turnDegrees = 0;
            turnSamples = 0;
            quietTurnSamples = 0;
            cornerCounted = false;
            sharpCounted = false;
          }
        }
      } else {
        turnDegrees = 0;
        turnSamples = 0;
        quietTurnSamples = 0;
        cornerCounted = false;
        sharpCounted = false;
      }

      previousSpeed = speed;
      previousTime = sample.timestamp;
    }

    return DriveMetrics(
      hardBrakeCount: hardBrakes,
      hardAccelerationCount: hardAccelerations,
      sharpTurnCount: sharpTurns,
      maxAccelerationG: maxAcceleration / 9.81,
      maxBrakingG: maxBraking.abs() / 9.81,
      maxCorneringSpeed: maxCornerSpeed,
      cornerCount: cornerCount,
      maxAltitude: hasAltitude ? maxAltitude : 0,
      altitudeGain: hasAltitude ? altitudeGain : 0,
      altitudeLoss: hasAltitude ? altitudeLoss : null,
      bestZeroToHundredSeconds: bestZeroToHundred,
      bestSixtyToHundredSeconds: bestSixtyToHundred,
    );
  }

  List<DriveTelemetrySample> _filter(Iterable<DriveTelemetrySample> input) {
    final ordered = input.where(_basicValidity).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final accepted = <DriveTelemetrySample>[];
    for (final rawSample in ordered) {
      final sample = rawSample.speedMps < DriveAnalysisRules.stationarySpeedMps
          ? DriveTelemetrySample(
              latitude: rawSample.latitude,
              longitude: rawSample.longitude,
              speedMps: 0,
              accuracyMeters: rawSample.accuracyMeters,
              heading: rawSample.heading,
              altitudeMeters: rawSample.altitudeMeters,
              timestamp: rawSample.timestamp,
            )
          : rawSample;
      if (accepted.isEmpty) {
        accepted.add(sample);
        continue;
      }
      final previous = accepted.last;
      final dt = _secondsBetween(previous.timestamp, sample.timestamp);
      if (dt < DriveAnalysisRules.minimumSampleIntervalSeconds ||
          dt > DriveAnalysisRules.maximumSampleIntervalSeconds) {
        continue;
      }
      final positionSpeed = _distanceMeters(previous, sample) / dt;
      if (positionSpeed > DriveAnalysisRules.maximumPlausiblePositionSpeedMps) {
        continue;
      }
      final acceleration = (sample.speedMps - previous.speedMps) / dt;
      if (acceleration.abs() >
          DriveAnalysisRules.maximumPlausibleAccelerationMps2) {
        continue;
      }
      accepted.add(sample);
    }
    return accepted;
  }

  bool _basicValidity(DriveTelemetrySample sample) =>
      sample.latitude.isFinite &&
      sample.longitude.isFinite &&
      sample.latitude.abs() <= 90 &&
      sample.longitude.abs() <= 180 &&
      sample.accuracyMeters.isFinite &&
      sample.accuracyMeters >= 0 &&
      sample.accuracyMeters <= DriveAnalysisRules.maximumAccuracyMeters &&
      sample.speedMps.isFinite &&
      sample.speedMps >= 0 &&
      sample.speedMps <= DriveAnalysisRules.maximumPlausibleSpeedMps;

  bool _validAltitude(double altitude) =>
      altitude.isFinite && altitude >= -500 && altitude <= 9000;

  double _distanceMeters(
    DriveTelemetrySample first,
    DriveTelemetrySample second,
  ) {
    const earthRadius = 6371000.0;
    final lat1 = first.latitude * math.pi / 180;
    final lat2 = second.latitude * math.pi / 180;
    final deltaLat = (second.latitude - first.latitude) * math.pi / 180;
    final deltaLng = (second.longitude - first.longitude) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _headingDelta(double first, double second) {
    if (!first.isFinite ||
        !second.isFinite ||
        first < 0 ||
        second < 0 ||
        first >= 360 ||
        second >= 360) {
      return 0;
    }
    var delta = (second - first).abs();
    if (delta > 180) delta = 360 - delta;
    return delta;
  }

  DateTime _crossingTime(
    DateTime from,
    DateTime to,
    double fromSpeed,
    double toSpeed,
    double target,
  ) {
    if (toSpeed <= fromSpeed) return to;
    final fraction = ((target - fromSpeed) / (toSpeed - fromSpeed)).clamp(
      0.0,
      1.0,
    );
    return from.add(
      Duration(
        microseconds: (to.difference(from).inMicroseconds * fraction).round(),
      ),
    );
  }

  double _secondsBetween(DateTime from, DateTime to) =>
      to.difference(from).inMicroseconds / 1000000;

  double _shorter(double? current, double candidate) =>
      current == null ? candidate : math.min(current, candidate);
}
