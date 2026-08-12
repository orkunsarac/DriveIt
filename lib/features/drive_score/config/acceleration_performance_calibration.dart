class AccelerationPerformanceCalibration {
  static const double rawMaximumScore = 25;
  static const double throttleMaximumScore = 15;
  static const double settlingMaximumScore = 10;
  static const double totalMaximumScore = 50;
  static const double minimumSpeedGainMps = 4;
  static const double trafficExclusionConfidence = .65;
  static const double lowSpeedTrafficExclusionMps = 12;
  static const Duration settlingWindow = Duration(seconds: 4);
  static const double rawAccelerationReferenceMps2 = 2.5;
  static const double throttleVariationTolerance = .55;
  static const double settlingVariationToleranceMps = 3;

  const AccelerationPerformanceCalibration._();
}
