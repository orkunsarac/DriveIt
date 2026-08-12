/// Detection-only calibration values for Drive Score Phase 2.
///
/// These values classify telemetry states and events. They are not category
/// weights, scoring thresholds or a Drive Score formula.
class DriveDetectionCalibration {
  static const double stoppedSpeedMps = 5 / 3.6;
  static const Duration stoppedMinimumDuration = Duration(seconds: 3);
  static const double stoppedMaximumDistanceMeters = 8;

  static const double accelerationEnterMps2 = .35;
  static const double accelerationExitMps2 = .15;
  static const double accelerationMinimumSpeedGainMps = 2;
  static const Duration accelerationMinimumDuration = Duration(
    milliseconds: 1500,
  );

  static const double decelerationEnterMps2 = -.35;
  static const double decelerationExitMps2 = -.15;
  static const double decelerationMinimumSpeedLossMps = 2;
  static const Duration decelerationMinimumDuration = Duration(
    milliseconds: 1500,
  );

  static const double cruiseMinimumSpeedMps = 5;
  static const double cruiseAccelerationToleranceMps2 = .3;
  static const double cruiseMaximumSpeedVariance = 1.5;
  static const Duration cruiseMinimumDuration = Duration(seconds: 5);

  static const double cornerMinimumSpeedMps = 4;
  static const double cornerEnterHeadingRateDegreesPerSecond = 4;
  static const double cornerExitHeadingRateDegreesPerSecond = 2;
  static const double cornerMinimumHeadingChangeDegrees = 15;
  static const double cornerMinimumDistanceMeters = 15;
  static const Duration cornerMinimumDuration = Duration(seconds: 2);

  static const Duration featureWindow = Duration(seconds: 5);
  static const Duration trafficWindow = Duration(seconds: 45);
  static const Duration minimumTrafficObservation = Duration(seconds: 8);
  static const double trafficLowSpeedMps = 30 / 3.6;
  static const double denseTrafficConfidenceThreshold = .55;
  static const double stopAndGoConfidenceThreshold = .62;

  static const double accelerationSmoothingFactor = .35;
  static const Duration detectorExitGrace = Duration(seconds: 1);

  const DriveDetectionCalibration._();
}
