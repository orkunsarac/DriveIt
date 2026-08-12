enum WorldJobType { validateRoad, rebuildValidatedRoad }

enum WorldJobStatus {
  pending,
  running,
  retryScheduled,
  completed,
  failedPermanent,
}

class WorldPendingJob {
  final String id;
  final String driveSessionId;
  final WorldJobType type;
  final WorldJobStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorldPendingJob({
    required this.id,
    required this.driveSessionId,
    required this.type,
    required this.status,
    required this.retryCount,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  /// One logical job per drive and operation. This becomes the Hive key and
  /// makes repeated enqueue calls idempotent.
  static String idempotencyKey(String driveSessionId, WorldJobType type) =>
      '${type.name}:$driveSessionId';

  factory WorldPendingJob.pending({
    required String driveSessionId,
    required WorldJobType type,
    required DateTime now,
  }) => WorldPendingJob(
    id: idempotencyKey(driveSessionId, type),
    driveSessionId: driveSessionId,
    type: type,
    status: WorldJobStatus.pending,
    retryCount: 0,
    lastError: null,
    createdAt: now,
    updatedAt: now,
  );

  WorldPendingJob copyWith({
    WorldJobStatus? status,
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
    DateTime? updatedAt,
  }) => WorldPendingJob(
    id: id,
    driveSessionId: driveSessionId,
    type: type,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: clearLastError ? null : lastError ?? this.lastError,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
