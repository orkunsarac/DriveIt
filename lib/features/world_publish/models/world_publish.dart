enum WorldPublishStatus { pending, processing, published, failed }

/// Server-owned publish state. No local DriveSession or Hive schema is changed.
class WorldPublish {
  const WorldPublish({
    required this.id,
    required this.userId,
    required this.localDriveId,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.worldRulesVersion,
    required this.status,
    required this.errorCode,
    required this.createdAt,
    required this.updatedAt,
    required this.processedAt,
    this.sourcePath,
    this.sourceSchemaVersion,
    this.telemetryVersion,
    this.driveScoreAlgorithmVersion,
    this.rawRoutePointCount,
    this.telemetryPointCount,
    this.sourceReadyAt,
  });

  final String id;
  final String userId;
  final String localDriveId;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int worldRulesVersion;
  final WorldPublishStatus status;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processedAt;
  final String? sourcePath;
  final int? sourceSchemaVersion;
  final int? telemetryVersion;
  final int? driveScoreAlgorithmVersion;
  final int? rawRoutePointCount;
  final int? telemetryPointCount;
  final DateTime? sourceReadyAt;

  bool get sourceReady => sourceReadyAt != null && sourcePath != null;

  factory WorldPublish.fromRow(Map<String, dynamic> row) => WorldPublish(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    localDriveId: row['local_drive_id'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    endedAt: DateTime.parse(row['ended_at'] as String),
    distanceMeters: (row['distance_meters'] as num).toDouble(),
    worldRulesVersion: (row['world_rules_version'] as num).toInt(),
    status: WorldPublishStatus.values.byName(row['status'] as String),
    errorCode: row['error_code'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    processedAt: row['processed_at'] == null
        ? null
        : DateTime.parse(row['processed_at'] as String),
    sourcePath: row['source_path'] as String?,
    sourceSchemaVersion: (row['source_schema_version'] as num?)?.toInt(),
    telemetryVersion: (row['telemetry_version'] as num?)?.toInt(),
    driveScoreAlgorithmVersion: (row['drive_score_algorithm_version'] as num?)
        ?.toInt(),
    rawRoutePointCount: (row['raw_route_point_count'] as num?)?.toInt(),
    telemetryPointCount: (row['telemetry_point_count'] as num?)?.toInt(),
    sourceReadyAt: row['source_ready_at'] == null
        ? null
        : DateTime.parse(row['source_ready_at'] as String),
  );
}
