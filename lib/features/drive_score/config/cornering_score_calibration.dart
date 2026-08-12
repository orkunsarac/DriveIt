class CorneringScoreCalibration {
  static const double speedRetentionMaximumScore = 60;
  static const double entryQualityMaximumScore = 35;
  static const double exitQualityMaximumScore = 35;
  static const double stabilityMaximumScore = 20;
  static const double totalMaximumScore = 150;

  static const double minimumCornerConfidence = .5;
  static const double minimumEntrySpeedMps = 10;
  static const double minimumHeadingChangeDegrees = 15;
  static const double minimumCornerDistanceMeters = 15;
  static const double trafficLowSpeedExclusionMps = 12;
  static const double trafficExclusionConfidence = .6;
  static const Duration exitRecoveryWindow = Duration(seconds: 3);

  static const double wideRadiusMeters = 500;
  static const double tightRadiusMeters = 25;
  static const double wideCornerExpectedLoss = .08;
  static const double tightCornerExpectedLoss = .48;
  static const double retentionExtraLossTolerance = .32;
  static const double entryVariationTolerance = .18;
  static const double exitRecoveryTarget = .95;
  static const double stabilityVarianceTolerance = .06;
  static const double trafficRetentionSoftening = .35;
  static const double maximumEventWeight = 1.5;

  const CorneringScoreCalibration._();
}
