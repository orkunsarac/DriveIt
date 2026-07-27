class DriveSummary {
  final double flowScore;
  final double cruiseSpeed;
  final double stability;
  final int oscillation;

  final double distanceKm;
  final Duration driveDuration;
  final double maxSpeed;

  final DateTime createdAt;

  const DriveSummary({
    required this.flowScore,
    required this.cruiseSpeed,
    required this.stability,
    required this.oscillation,
    required this.distanceKm,
    required this.driveDuration,
    required this.maxSpeed,
    required this.createdAt,
  });
}