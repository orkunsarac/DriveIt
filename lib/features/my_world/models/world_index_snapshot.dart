import 'active_world_trace.dart';

/// Copy-on-write durable state for the active World ownership index.
class WorldIndexSnapshot {
  const WorldIndexSnapshot({
    required this.generation,
    required this.operationId,
    required this.traces,
    required this.processedDriveSessionIds,
    required this.driveScoreAlgorithmVersion,
    required this.validatedRoadProcessingVersion,
    required this.createdAt,
    this.operationReason = 'recordProcessing',
  });

  final int generation;
  final String operationId;
  final List<ActiveWorldTrace> traces;
  final List<String> processedDriveSessionIds;
  final int driveScoreAlgorithmVersion;
  final int validatedRoadProcessingVersion;
  final DateTime createdAt;
  final String operationReason;

  static WorldIndexSnapshot empty({
    required int driveScoreAlgorithmVersion,
    required int validatedRoadProcessingVersion,
  }) => WorldIndexSnapshot(
    generation: 0,
    operationId: 'initial',
    traces: const [],
    processedDriveSessionIds: const [],
    driveScoreAlgorithmVersion: driveScoreAlgorithmVersion,
    validatedRoadProcessingVersion: validatedRoadProcessingVersion,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    operationReason: 'initial',
  );

  WorldIndexSnapshot copyWith({
    int? generation,
    String? operationId,
    List<ActiveWorldTrace>? traces,
    List<String>? processedDriveSessionIds,
    int? driveScoreAlgorithmVersion,
    int? validatedRoadProcessingVersion,
    DateTime? createdAt,
    String? operationReason,
  }) => WorldIndexSnapshot(
    generation: generation ?? this.generation,
    operationId: operationId ?? this.operationId,
    traces: traces ?? this.traces,
    processedDriveSessionIds:
        processedDriveSessionIds ?? this.processedDriveSessionIds,
    driveScoreAlgorithmVersion:
        driveScoreAlgorithmVersion ?? this.driveScoreAlgorithmVersion,
    validatedRoadProcessingVersion:
        validatedRoadProcessingVersion ?? this.validatedRoadProcessingVersion,
    createdAt: createdAt ?? this.createdAt,
    operationReason: operationReason ?? this.operationReason,
  );

  bool hasProcessedDrive(String driveSessionId) =>
      processedDriveSessionIds.contains(driveSessionId);
}

/// A tiny pointer is switched only after a complete snapshot has been stored.
class WorldIndexPointer {
  const WorldIndexPointer({
    required this.activeGeneration,
    required this.updatedAt,
  });

  final int activeGeneration;
  final DateTime updatedAt;
}
