class DrivingSmoothnessCalibration {
  static const double maximumScore = 100;
  static const Duration minimumEligibleDuration = Duration(seconds: 8);
  static const Duration sampleSufficientDuration = Duration(seconds: 30);
  static const Duration strongDuration = Duration(minutes: 2);
  static const Duration maximumDuration = Duration(minutes: 5);
  static const double trafficExclusionConfidence = .65;
  static const double minimumCruiseSpeedMps = 30 / 3.6;
  static const double stabilityVarianceToleranceMps2 = 4;

  const DrivingSmoothnessCalibration._();
}
