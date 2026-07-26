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
    );
  }

  @override
  void write(BinaryWriter writer, DriveSession obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.route);
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
