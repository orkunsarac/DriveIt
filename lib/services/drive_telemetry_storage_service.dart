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
    Map<String, dynamic> acquisitionMetadata = const {},
  }) async {
    if (points.isEmpty) return;
    await _box.put(
      driveSessionId,
      DriveTelemetryRecord(
        driveSessionId: driveSessionId,
        dataVersion: DriveTelemetryRecord.currentDataVersion,
        createdAt: DateTime.now(),
        points: List<CanonicalTelemetryPoint>.unmodifiable(points),
        acquisitionMetadata: Map.unmodifiable(acquisitionMetadata),
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
      breakBefore: fields[9] as bool? ?? false,
      gapDurationMicros: fields[10] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, CanonicalTelemetryPoint object) {
    writer
      ..writeByte(11)
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
      ..write(object.accelerationMps2)
      ..writeByte(9)
      ..write(object.breakBefore)
      ..writeByte(10)
      ..write(object.gapDurationMicros);
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
    final metadata = fields[4] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(fields[4] as Map);
    final points = (fields[3] as List? ?? const <dynamic>[])
        .cast<CanonicalTelemetryPoint>()
        .toList();
    final quality = metadata['canonicalQualityV1'];
    if (quality is List) {
      for (final item in quality) {
        final entry = Map<String, dynamic>.from(item as Map);
        final index = entry['index'] as int;
        if (index < 0 || index >= points.length) {
          throw StateError('Invalid telemetry quality index');
        }
        final point = points[index];
        points[index] = CanonicalTelemetryPoint.fromMap({
          ...point.toMap(),
          'timeMicros': point.timestamp.microsecondsSinceEpoch,
          'timeIsUtc': point.timestamp.isUtc,
          'speedSource': entry['speedSource'],
          'accelerationReliable': entry['accelerationReliable'],
        })!;
      }
    }
    return DriveTelemetryRecord(
      driveSessionId: fields[0] as String,
      dataVersion: fields[1] as int? ?? 1,
      createdAt:
          fields[2] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
      points: points,
      acquisitionMetadata: metadata,
    );
  }

  @override
  void write(BinaryWriter writer, DriveTelemetryRecord object) {
    final quality = <Map<String, dynamic>>[
      for (var i = 0; i < object.points.length; i++)
        if (object.points[i].speedSource != 'legacy' ||
            !object.points[i].accelerationReliable)
          {
            'index': i,
            'speedSource': object.points[i].speedSource,
            'accelerationReliable': object.points[i].accelerationReliable,
          },
    ];
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(object.driveSessionId)
      ..writeByte(1)
      ..write(object.dataVersion)
      ..writeByte(2)
      ..write(object.createdAt)
      ..writeByte(3)
      ..write(object.points)
      ..writeByte(4)
      ..write({
        ...object.acquisitionMetadata,
        if (quality.isNotEmpty) 'canonicalQualityV1': quality,
      });
  }
}
