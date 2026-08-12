class TransitionControlCalibration {
  static const double cruiseDecelCruiseMaximumScore = 20;
  static const double cruiseCornerCruiseMaximumScore = 20;
  static const double accelerationCruiseMaximumScore = 10;
  static const double totalMaximumScore = 50;
  static const Duration maximumGap = Duration(seconds: 8);
  static const double minimumCruiseSpeedMps = 30 / 3.6;
  static const double trafficExclusionConfidence = .65;
  static const double targetCruiseVarianceTolerance = 4;

  const TransitionControlCalibration._();
}
