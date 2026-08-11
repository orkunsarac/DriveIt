class DriveMetrics {
  final int hardBrakeCount;
  final int hardAccelerationCount;
  final int sharpTurnCount;
  final double maxAccelerationG;
  final double maxBrakingG;
  final double maxCorneringSpeed;
  final int cornerCount;
  final double maxAltitude;
  final double altitudeGain;
  final double? altitudeLoss;
  final double? bestZeroToHundredSeconds;
  final double? bestSixtyToHundredSeconds;

  const DriveMetrics({
    this.hardBrakeCount = 0,
    this.hardAccelerationCount = 0,
    this.sharpTurnCount = 0,
    this.maxAccelerationG = 0,
    this.maxBrakingG = 0,
    this.maxCorneringSpeed = 0,
    this.cornerCount = 0,
    this.maxAltitude = 0,
    this.altitudeGain = 0,
    this.altitudeLoss,
    this.bestZeroToHundredSeconds,
    this.bestSixtyToHundredSeconds,
  });
}
