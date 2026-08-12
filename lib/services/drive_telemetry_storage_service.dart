import 'package:hive/hive.dart';

import '../models/canonical_telemetry_point.dart';

class DriveTelemetryHive {
  static const String boxName = 'drive_telemetry';
  static const int pointTypeId = 2;
  static const int recordTypeId = 3;

  static void registerAdapters(HiveInterface hive) {
    if (!hive.isAdapterRegistered(pointTypeId)) {
      hive.registerAdapter(CanonicalTelemetryPointAdapter());
    }
    if (!hive.isAdapterRegistered(recordTypeId)) {
      hive.registerAdapter(DriveTelemetryRecordAdapter());
    }
  }

  static Future<void> openBox(HiveInterface hive) =>
      hive.openBox<DriveTelemetryRecord>(boxName);
}

class DriveTelemetryStorageService {
  static Box<DriveTelemetryRecord> get _box =>
      Hive.box<DriveTelemetryRecord>(DriveTelemetryHive.boxName);

  static Future<void> save({
    required String driveSessionId,
    required List<CanonicalTelemetryPoint> points,
  }) async {
    if (points.isEmpty) return;
    await _box.put(
      driveSessionId,
      DriveTelemetryRecord(
        driveSessionId: driveSessionId,
        dataVersion: DriveTelemetryRecord.currentDataVersion,
        createdAt: DateTime.now(),
        points: List<CanonicalTelemetryPoint>.unmodifiable(points),
      ),
    );
  }

  static DriveTelemetryRecord? get(String driveSessionId) =>
      Hive.isBoxOpen(DriveTelemetryHive.boxName)
      ? _box.get(driveSessionId)
      : null;

  static Future<void> delete(String driveSessionId) async {
    if (Hive.isBoxOpen(DriveTelemetryHive.boxName)) {
      await _box.delete(driveSessionId);
    }
  }
}

class CanonicalTelemetryPointAdapter
    extends TypeAdapter<CanonicalTelemetryPoint> {
  @override
  final int typeId = DriveTelemetryHive.pointTypeId;

  @override
  CanonicalTelemetryPoint read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return CanonicalTelemetryPoint(
      latitude: (fields[0] as num).toDouble(),
      longitude: (fields[1] as num).toDouble(),
      timestamp: fields[2] as DateTime,
      speedMps: (fields[3] as num?)?.toDouble() ?? 0,
      headingDegrees: (fields[4] as num?)?.toDouble() ?? 0,
      altitudeMeters: (fields[5] as num?)?.toDouble() ?? 0,
      accuracyMeters: (fields[6] as num?)?.toDouble() ?? 999,
      distanceFromPreviousMeters: (fields[7] as num?)?.toDouble() ?? 0,
      accelerationMps2: (fields[8] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, CanonicalTelemetryPoint object) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(object.latitude)
      ..writeByte(1)
      ..write(object.longitude)
      ..writeByte(2)
      ..write(object.timestamp)
      ..writeByte(3)
      ..write(object.speedMps)
      ..writeByte(4)
      ..write(object.headingDegrees)
      ..writeByte(5)
      ..write(object.altitudeMeters)
      ..writeByte(6)
      ..write(object.accuracyMeters)
      ..writeByte(7)
      ..write(object.distanceFromPreviousMeters)
      ..writeByte(8)
      ..write(object.accelerationMps2);
  }
}

class DriveTelemetryRecordAdapter extends TypeAdapter<DriveTelemetryRecord> {
  @override
  final int typeId = DriveTelemetryHive.recordTypeId;

  @override
  DriveTelemetryRecord read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return DriveTelemetryRecord(
      driveSessionId: fields[0] as String,
      dataVersion: fields[1] as int? ?? 1,
      createdAt:
          fields[2] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
      points: (fields[3] as List? ?? const <dynamic>[])
          .cast<CanonicalTelemetryPoint>(),
    );
  }

  @override
  void write(BinaryWriter writer, DriveTelemetryRecord object) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(object.driveSessionId)
      ..writeByte(1)
      ..write(object.dataVersion)
      ..writeByte(2)
      ..write(object.createdAt)
      ..writeByte(3)
      ..write(object.points);
  }
}
