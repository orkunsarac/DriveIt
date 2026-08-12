class WorldRebuildResult {
  const WorldRebuildResult({
    required this.success,
    required this.totalDrivesScanned,
    required this.drivesProcessed,
    required this.drivesSkipped,
    required this.missingValidationCount,
    required this.resultingTraceCount,
    required this.totalWorldDistanceMeters,
    required this.targetAlgorithmVersion,
    this.failureReason,
  });

  final bool success;
  final int totalDrivesScanned;
  final int drivesProcessed;
  final int drivesSkipped;
  final int missingValidationCount;
  final int resultingTraceCount;
  final double totalWorldDistanceMeters;
  final int targetAlgorithmVersion;
  final String? failureReason;
}

class WorldRebuildNeed {
  const WorldRebuildNeed({required this.needsRebuild, required this.reason});

  final bool needsRebuild;
  final String? reason;
}

class WorldRebuildBounds {
  const WorldRebuildBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool containsBounds(WorldRebuildBounds other) =>
      minLatitude <= other.maxLatitude &&
      maxLatitude >= other.minLatitude &&
      minLongitude <= other.maxLongitude &&
      maxLongitude >= other.minLongitude;
}
