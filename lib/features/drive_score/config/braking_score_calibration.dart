/// Calibration for the Drive Score v1 braking and anticipation category.
///
/// Category maxima are constitutional product rules. The remaining values are
/// deliberately centralized starting calibration values and can be tuned with
/// real, anonymised DriveIt telemetry without changing the scoring contract.
class BrakingScoreCalibration {
  static const double anticipationMaximumScore = 150;
  static const double severityMaximumScore = 100;
  static const double oscillationMaximumScore = 60;
  static const double stoppingQualityMaximumScore = 40;
  static const double totalMaximumScore =
      anticipationMaximumScore +
      severityMaximumScore +
      oscillationMaximumScore +
      stoppingQualityMaximumScore;

  static const Duration anticipationLookback = Duration(seconds: 5);
  static const double anticipationEarlyLossTarget = .55;
  static const double anticipationLateLossStartFraction = .60;
  static const double anticipationMaximumLateLossFraction = .72;
  static const double anticipationSmoothnessAccelerationDeviationMps2 = .9;

  static const double normalBrakingMps2 = 1.5;
  static const double noticeableBrakingMps2 = 2.5;
  static const double strongBrakingMps2 = 3.5;
  static const double hardBrakingMps2 = 5.0;
  static const double singleEmergencyPenaltyCap = .35;
  static const double repeatedSeverityPenaltyMultiplier = 1.35;

  static const double denseTrafficPenaltySuppression = .25;
  static const double stopAndGoPenaltySuppression = .45;
  static const double cornerPenaltySuppression = .40;

  static const double minimumMeaningfulStopApproachSpeedMps = 15 / 3.6;
  static const Duration stopFinalWindow = Duration(seconds: 2);
  static const double stopSmoothnessAccelerationDeviationMps2 = .8;
  static const double stopLateBrakingRatioTarget = .55;
  static const Duration stopAssociationGap = Duration(seconds: 3);

  static const double lowSpeedBrakeThrottleWindowSeconds = 14;
  static const double mediumSpeedBrakeThrottleWindowSeconds = 10.5;
  static const double highSpeedBrakeThrottleWindowSeconds = 7.5;
  static const double mediumSpeedThresholdMps = 50 / 3.6;
  static const double highSpeedThresholdMps = 90 / 3.6;
  static const double meaningfulBrakeThrottleSpeedGainMps = 3;
  static const double brakeThrottleSeverityReferenceMps2 = 3.5;
  static const double singleCyclePenaltyMultiplier = .15;
  static const double repeatedCyclePenaltyMultiplier = 1.0;
  static const double repeatFrequencyReference = 3;
  static const double trafficOscillationSuppressionMinimum = .80;
  static const double trafficOscillationSuppressionMaximum = 1.0;

  const BrakingScoreCalibration._();
}
