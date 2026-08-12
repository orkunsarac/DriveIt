enum WorldProcessingState {
  notProcessed,
  pendingValidation,
  validated,
  rejectedInsufficientValidDistance,
  readyForWorldProcessing,
  processing,
  processed,
  failedRetryable,
  failedPermanent,
}

class WorldDriveProcessingRecord {
  final String driveSessionId;
  final WorldProcessingState state;
  final String? validatedRoadId;
  final String? lastError;
  final DateTime updatedAt;

  const WorldDriveProcessingRecord({
    required this.driveSessionId,
    required this.state,
    required this.validatedRoadId,
    required this.lastError,
    required this.updatedAt,
  });
}
