// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drive_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DriveSessionAdapter extends TypeAdapter<DriveSession> {
  @override
  final int typeId = 0;

  @override
  DriveSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DriveSession(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      distance: fields[2] as double,
      durationSeconds: fields[3] as int,
      averageSpeed: fields[4] as double,
      maxSpeed: fields[5] as double,
      mapImagePath: fields[6] as String,
      route: (fields[7] as List).cast<RoutePoint>(),
      // Older development builds used these slots for boolean flags.
      // Treat those values as empty stop statistics instead of crashing Hive
      // while opening the existing box.
      stopCount: fields[12] is int ? fields[12] as int : 0,
      stoppedSeconds: fields[13] is int ? fields[13] as int : 0,
      hardBrakeCount: fields[14] is int ? fields[14] as int : 0,
      hardAccelerationCount: fields[15] is int ? fields[15] as int : 0,
      sharpTurnCount: fields[16] is int ? fields[16] as int : 0,
      maxAccelerationG: fields[17] is num ? (fields[17] as num).toDouble() : 0,
      maxBrakingG: fields[18] is num ? (fields[18] as num).toDouble() : 0,
      maxCorneringSpeed: fields[19] is num ? (fields[19] as num).toDouble() : 0,
      cornerCount: fields[20] is int ? fields[20] as int : 0,
      maxAltitude: fields[21] is num ? (fields[21] as num).toDouble() : 0,
      altitudeGain: fields[22] is num ? (fields[22] as num).toDouble() : 0,
      bestZeroToHundredSeconds: fields[23] is num
          ? (fields[23] as num).toDouble()
          : null,
      bestSixtyToHundredSeconds: fields[24] is num
          ? (fields[24] as num).toDouble()
          : null,
      altitudeLoss: fields[25] is num ? (fields[25] as num).toDouble() : null,
    );
  }

  @override
  void write(BinaryWriter writer, DriveSession obj) {
    writer
      // Legacy Flow Analysis fields 8-11 are deliberately not written.
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.distance)
      ..writeByte(3)
      ..write(obj.durationSeconds)
      ..writeByte(4)
      ..write(obj.averageSpeed)
      ..writeByte(5)
      ..write(obj.maxSpeed)
      ..writeByte(6)
      ..write(obj.mapImagePath)
      ..writeByte(7)
      ..write(obj.route)
      ..writeByte(12)
      ..write(obj.stopCount)
      ..writeByte(13)
      ..write(obj.stoppedSeconds)
      ..writeByte(14)
      ..write(obj.hardBrakeCount)
      ..writeByte(15)
      ..write(obj.hardAccelerationCount)
      ..writeByte(16)
      ..write(obj.sharpTurnCount)
      ..writeByte(17)
      ..write(obj.maxAccelerationG)
      ..writeByte(18)
      ..write(obj.maxBrakingG)
      ..writeByte(19)
      ..write(obj.maxCorneringSpeed)
      ..writeByte(20)
      ..write(obj.cornerCount)
      ..writeByte(21)
      ..write(obj.maxAltitude)
      ..writeByte(22)
      ..write(obj.altitudeGain)
      ..writeByte(23)
      ..write(obj.bestZeroToHundredSeconds)
      ..writeByte(24)
      ..write(obj.bestSixtyToHundredSeconds)
      ..writeByte(25)
      ..write(obj.altitudeLoss);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriveSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
