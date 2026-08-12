import 'package:hive/hive.dart';

import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/active_world_trace.dart';
import '../models/validated_road.dart';
import '../models/world_index_snapshot.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';

/// Hive registration and box names owned exclusively by Benim Dunyam v2.
///
/// Type IDs 0 and 1 belong to the existing DriveSession and RoutePoint
/// adapters. IDs 10-18 are reserved for this feature and must not be reused.
class MyWorldHive {
  const MyWorldHive._();

  static const String validatedRoadsBoxName = 'my_world_validated_roads';
  static const String processingBoxName = 'my_world_processing';
  static const String pendingJobsBoxName = 'my_world_pending_jobs';
  static const String indexSnapshotsBoxName = 'my_world_index_snapshots';
  static const String indexMetadataBoxName = 'my_world_index_metadata';

  static void registerAdapters(HiveInterface hive) {
    _register(hive, MatchedRoadPointAdapter());
    _register(hive, RoadValidationStatusAdapter());
    _register(hive, ValidatedRoadAdapter());
    _register(hive, WorldProcessingStateAdapter());
    _register(hive, WorldDriveProcessingRecordAdapter());
    _register(hive, WorldJobTypeAdapter());
    _register(hive, WorldJobStatusAdapter());
    _register(hive, WorldPendingJobAdapter());
    _register(hive, MatchedRoadSectionAdapter());
    _register(hive, ActiveWorldTraceAdapter());
    _register(hive, WorldIndexSnapshotAdapter());
    _register(hive, WorldIndexPointerAdapter());
  }

  static Future<void> openBoxes(HiveInterface hive) async {
    await hive.openBox<ValidatedRoad>(validatedRoadsBoxName);
    await hive.openBox<WorldDriveProcessingRecord>(processingBoxName);
    await hive.openBox<WorldPendingJob>(pendingJobsBoxName);
    await hive.openBox<WorldIndexSnapshot>(indexSnapshotsBoxName);
    await hive.openBox<WorldIndexPointer>(indexMetadataBoxName);
  }

  static void _register<T>(HiveInterface hive, TypeAdapter<T> adapter) {
    if (!hive.isAdapterRegistered(adapter.typeId)) {
      hive.registerAdapter<T>(adapter);
    }
  }
}

class MatchedRoadPointAdapter extends TypeAdapter<MatchedRoadPoint> {
  @override
  final int typeId = 10;

  @override
  MatchedRoadPoint read(BinaryReader reader) {
    final fields = _readFields(reader);
    return MatchedRoadPoint(
      latitude: (fields[0] as num).toDouble(),
      longitude: (fields[1] as num).toDouble(),
      headingDegrees: (fields[2] as num?)?.toDouble(),
      providerRoadReference: fields[3] as String?,
      confidence: (fields[4] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, MatchedRoadPoint object) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(object.latitude)
      ..writeByte(1)
      ..write(object.longitude)
      ..writeByte(2)
      ..write(object.headingDegrees)
      ..writeByte(3)
      ..write(object.providerRoadReference)
      ..writeByte(4)
      ..write(object.confidence);
  }
}

class RoadValidationStatusAdapter extends TypeAdapter<RoadValidationStatus> {
  @override
  final int typeId = 11;

  @override
  RoadValidationStatus read(BinaryReader reader) => _enumValue(
    RoadValidationStatus.values,
    reader.readByte(),
    RoadValidationStatus.failed,
  );

  @override
  void write(BinaryWriter writer, RoadValidationStatus object) =>
      writer.writeByte(object.index);
}

class ValidatedRoadAdapter extends TypeAdapter<ValidatedRoad> {
  @override
  final int typeId = 12;

  @override
  ValidatedRoad read(BinaryReader reader) {
    final fields = _readFields(reader);
    return ValidatedRoad(
      id: fields[0] as String,
      driveSessionId: fields[1] as String,
      geometry: (fields[2] as List).cast<MatchedRoadPoint>(),
      sections: fields[13] is List
          ? (fields[13] as List).cast<MatchedRoadSection>()
          : const [],
      validDistanceMeters: (fields[3] as num).toDouble(),
      status: fields[4] as RoadValidationStatus,
      validatedAt: fields[5] as DateTime?,
      providerId: fields[6] as String,
      confidence: (fields[7] as num?)?.toDouble(),
      processingVersion: (fields[8] as num).toInt(),
      requiresRetry: fields[14] as bool? ?? false,
      directionKey: fields[9] as String,
      averageHeadingDegrees: (fields[10] as num?)?.toDouble(),
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ValidatedRoad object) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.driveSessionId)
      ..writeByte(2)
      ..write(object.geometry)
      ..writeByte(3)
      ..write(object.validDistanceMeters)
      ..writeByte(4)
      ..write(object.status)
      ..writeByte(5)
      ..write(object.validatedAt)
      ..writeByte(6)
      ..write(object.providerId)
      ..writeByte(7)
      ..write(object.confidence)
      ..writeByte(8)
      ..write(object.processingVersion)
      ..writeByte(9)
      ..write(object.directionKey)
      ..writeByte(10)
      ..write(object.averageHeadingDegrees)
      ..writeByte(11)
      ..write(object.createdAt)
      ..writeByte(12)
      ..write(object.updatedAt)
      ..writeByte(13)
      ..write(object.sections)
      ..writeByte(14)
      ..write(object.requiresRetry);
  }
}

class WorldProcessingStateAdapter extends TypeAdapter<WorldProcessingState> {
  @override
  final int typeId = 13;

  @override
  WorldProcessingState read(BinaryReader reader) => _enumValue(
    WorldProcessingState.values,
    reader.readByte(),
    WorldProcessingState.failedPermanent,
  );

  @override
  void write(BinaryWriter writer, WorldProcessingState object) =>
      writer.writeByte(object.index);
}

class WorldDriveProcessingRecordAdapter
    extends TypeAdapter<WorldDriveProcessingRecord> {
  @override
  final int typeId = 14;

  @override
  WorldDriveProcessingRecord read(BinaryReader reader) {
    final fields = _readFields(reader);
    return WorldDriveProcessingRecord(
      driveSessionId: fields[0] as String,
      state: fields[1] as WorldProcessingState,
      validatedRoadId: fields[2] as String?,
      lastError: fields[3] as String?,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorldDriveProcessingRecord object) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(object.driveSessionId)
      ..writeByte(1)
      ..write(object.state)
      ..writeByte(2)
      ..write(object.validatedRoadId)
      ..writeByte(3)
      ..write(object.lastError)
      ..writeByte(4)
      ..write(object.updatedAt);
  }
}

class WorldJobTypeAdapter extends TypeAdapter<WorldJobType> {
  @override
  final int typeId = 15;

  @override
  WorldJobType read(BinaryReader reader) => _enumValue(
    WorldJobType.values,
    reader.readByte(),
    WorldJobType.validateRoad,
  );

  @override
  void write(BinaryWriter writer, WorldJobType object) =>
      writer.writeByte(object.index);
}

class WorldJobStatusAdapter extends TypeAdapter<WorldJobStatus> {
  @override
  final int typeId = 16;

  @override
  WorldJobStatus read(BinaryReader reader) => _enumValue(
    WorldJobStatus.values,
    reader.readByte(),
    WorldJobStatus.failedPermanent,
  );

  @override
  void write(BinaryWriter writer, WorldJobStatus object) =>
      writer.writeByte(object.index);
}

class WorldPendingJobAdapter extends TypeAdapter<WorldPendingJob> {
  @override
  final int typeId = 17;

  @override
  WorldPendingJob read(BinaryReader reader) {
    final fields = _readFields(reader);
    return WorldPendingJob(
      id: fields[0] as String,
      driveSessionId: fields[1] as String,
      type: fields[2] as WorldJobType,
      status: fields[3] as WorldJobStatus,
      retryCount: (fields[4] as num).toInt(),
      lastError: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorldPendingJob object) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.driveSessionId)
      ..writeByte(2)
      ..write(object.type)
      ..writeByte(3)
      ..write(object.status)
      ..writeByte(4)
      ..write(object.retryCount)
      ..writeByte(5)
      ..write(object.lastError)
      ..writeByte(6)
      ..write(object.createdAt)
      ..writeByte(7)
      ..write(object.updatedAt);
  }
}

class MatchedRoadSectionAdapter extends TypeAdapter<MatchedRoadSection> {
  @override
  final int typeId = 18;

  @override
  MatchedRoadSection read(BinaryReader reader) {
    final fields = _readFields(reader);
    return MatchedRoadSection(
      id: fields[0] as String,
      geometry: (fields[1] as List).cast<MatchedRoadPoint>(),
      distanceMeters: (fields[2] as num).toDouble(),
      confidence: (fields[3] as num?)?.toDouble(),
      sourceTraceIndex: (fields[4] as num).toInt(),
      sourceChunkIndex: (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, MatchedRoadSection object) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.geometry)
      ..writeByte(2)
      ..write(object.distanceMeters)
      ..writeByte(3)
      ..write(object.confidence)
      ..writeByte(4)
      ..write(object.sourceTraceIndex)
      ..writeByte(5)
      ..write(object.sourceChunkIndex);
  }
}

/// IDs 19-21 extend the Phase 1 reservation without changing any legacy
/// adapters or boxes.
class ActiveWorldTraceAdapter extends TypeAdapter<ActiveWorldTrace> {
  @override
  final int typeId = 19;

  @override
  ActiveWorldTrace read(BinaryReader reader) {
    final fields = _readFields(reader);
    return ActiveWorldTrace(
      id: fields[0] as String,
      sourceDriveSessionId: fields[1] as String,
      validatedRoadId: fields[2] as String,
      matchedSectionId: fields[3] as String,
      startOffsetMeters: (fields[4] as num).toDouble(),
      endOffsetMeters: (fields[5] as num).toDouble(),
      directionKey: fields[6] as String,
      minLatitude: (fields[7] as num).toDouble(),
      maxLatitude: (fields[8] as num).toDouble(),
      minLongitude: (fields[9] as num).toDouble(),
      maxLongitude: (fields[10] as num).toDouble(),
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      processingVersion: (fields[13] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ActiveWorldTrace object) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.sourceDriveSessionId)
      ..writeByte(2)
      ..write(object.validatedRoadId)
      ..writeByte(3)
      ..write(object.matchedSectionId)
      ..writeByte(4)
      ..write(object.startOffsetMeters)
      ..writeByte(5)
      ..write(object.endOffsetMeters)
      ..writeByte(6)
      ..write(object.directionKey)
      ..writeByte(7)
      ..write(object.minLatitude)
      ..writeByte(8)
      ..write(object.maxLatitude)
      ..writeByte(9)
      ..write(object.minLongitude)
      ..writeByte(10)
      ..write(object.maxLongitude)
      ..writeByte(11)
      ..write(object.createdAt)
      ..writeByte(12)
      ..write(object.updatedAt)
      ..writeByte(13)
      ..write(object.processingVersion);
  }
}

class WorldIndexSnapshotAdapter extends TypeAdapter<WorldIndexSnapshot> {
  @override
  final int typeId = 20;

  @override
  WorldIndexSnapshot read(BinaryReader reader) {
    final fields = _readFields(reader);
    return WorldIndexSnapshot(
      generation: (fields[0] as num).toInt(),
      operationId: fields[1] as String,
      traces: (fields[2] as List).cast<ActiveWorldTrace>(),
      processedDriveSessionIds: (fields[3] as List).cast<String>(),
      driveScoreAlgorithmVersion: (fields[4] as num).toInt(),
      validatedRoadProcessingVersion: (fields[5] as num).toInt(),
      createdAt: fields[6] as DateTime,
      operationReason: fields[7] as String? ?? 'recordProcessing',
    );
  }

  @override
  void write(BinaryWriter writer, WorldIndexSnapshot object) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(object.generation)
      ..writeByte(1)
      ..write(object.operationId)
      ..writeByte(2)
      ..write(object.traces)
      ..writeByte(3)
      ..write(object.processedDriveSessionIds)
      ..writeByte(4)
      ..write(object.driveScoreAlgorithmVersion)
      ..writeByte(5)
      ..write(object.validatedRoadProcessingVersion)
      ..writeByte(6)
      ..write(object.createdAt)
      ..writeByte(7)
      ..write(object.operationReason);
  }
}

class WorldIndexPointerAdapter extends TypeAdapter<WorldIndexPointer> {
  @override
  final int typeId = 21;

  @override
  WorldIndexPointer read(BinaryReader reader) {
    final fields = _readFields(reader);
    return WorldIndexPointer(
      activeGeneration: (fields[0] as num).toInt(),
      updatedAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorldIndexPointer object) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(object.activeGeneration)
      ..writeByte(1)
      ..write(object.updatedAt);
  }
}

Map<int, dynamic> _readFields(BinaryReader reader) {
  final fieldCount = reader.readByte();
  return <int, dynamic>{
    for (var index = 0; index < fieldCount; index++)
      reader.readByte(): reader.read(),
  };
}

T _enumValue<T>(List<T> values, int index, T fallback) =>
    index >= 0 && index < values.length ? values[index] : fallback;
