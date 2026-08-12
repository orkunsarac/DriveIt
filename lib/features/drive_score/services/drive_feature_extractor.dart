import 'dart:collection';

import '../../../models/canonical_telemetry_point.dart';
import '../config/drive_detection_calibration.dart';
import '../models/driving_analysis_models.dart';

class DriveFeatureExtractor {
  const DriveFeatureExtractor();

  List<TelemetryFeature> extract(List<CanonicalTelemetryPoint> points) {
    if (points.isEmpty) return const <TelemetryFeature>[];

    final window = ListQueue<int>();
    var speedSum = 0.0;
    var speedSquareSum = 0.0;
    var lowSpeedCount = 0;
    var smoothedAcceleration = 0.0;
    var stationaryDuration = 0.0;
    var movingDuration = 0.0;
    final features = <TelemetryFeature>[];

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      window.addLast(index);
      speedSum += point.speedMps;
      speedSquareSum += point.speedMps * point.speedMps;
      if (point.speedMps <= DriveDetectionCalibration.trafficLowSpeedMps) {
        lowSpeedCount++;
      }

      final cutoff = point.timestamp.subtract(
        DriveDetectionCalibration.featureWindow,
      );
      while (window.length > 1 &&
          points[window.first].timestamp.isBefore(cutoff)) {
        final removed = points[window.removeFirst()];
        speedSum -= removed.speedMps;
        speedSquareSum -= removed.speedMps * removed.speedMps;
        if (removed.speedMps <= DriveDetectionCalibration.trafficLowSpeedMps) {
          lowSpeedCount--;
        }
      }

      final count = window.length;
      final mean = speedSum / count;
      final variance = (speedSquareSum / count - mean * mean).clamp(
        0,
        double.infinity,
      );
      smoothedAcceleration = index == 0
          ? point.accelerationMps2
          : smoothedAcceleration +
                DriveDetectionCalibration.accelerationSmoothingFactor *
                    (point.accelerationMps2 - smoothedAcceleration);

      var headingDelta = 0.0;
      var headingRate = 0.0;
      if (index > 0) {
        final previous = points[index - 1];
        final dt =
            point.timestamp.difference(previous.timestamp).inMicroseconds /
            1000000;
        if (dt > 0) {
          if (point.speedMps <=
              DriveDetectionCalibration.stoppedSpeedMps) {
            stationaryDuration += dt;
            movingDuration = 0;
          } else {
            movingDuration += dt;
            stationaryDuration = 0;
          }
        }
        if (dt > 0 &&
            point.speedMps >= DriveDetectionCalibration.cornerMinimumSpeedMps) {
          headingDelta = _shortestHeadingDelta(
            previous.headingDegrees,
            point.headingDegrees,
          );
          headingRate = headingDelta.abs() / dt;
        }
      }

      features.add(
        TelemetryFeature(
          index: index,
          point: point,
          rollingMeanSpeedMps: mean,
          rollingSpeedVariance: variance.toDouble(),
          smoothedAccelerationMps2: smoothedAcceleration,
          headingDeltaDegrees: headingDelta,
          headingChangeRateDegreesPerSecond: headingRate,
          rollingLowSpeedRatio: lowSpeedCount / count,
          stationaryDurationSeconds: stationaryDuration,
          movingDurationSeconds: movingDuration,
        ),
      );
    }
    return features;
  }

  double _shortestHeadingDelta(double first, double second) {
    if (!first.isFinite || !second.isFinite) return 0;
    return ((second - first + 540) % 360) - 180;
  }
}
