// Compatibility adapter: preserve legacy fields. Do not replace with generated
// output unless the legacy pass-through and transitional field-2 tests pass.

part of 'route_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutePointAdapter extends TypeAdapter<RoutePoint> {
  @override
  final int typeId = 1;

  @override
  RoutePoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutePoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      breakBefore: fields.containsKey(254)
          ? fields[254] as bool
          : fields[2] is bool
          ? fields[2] as bool
          : false,
      legacyHiveFields: Map<int, dynamic>.from(fields)
        ..remove(0)
        ..remove(1)
        ..remove(254),
    );
  }

  @override
  void write(BinaryWriter writer, RoutePoint obj) {
    writer
      ..writeByte(3 + obj.legacyHiveFields.length)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(254)
      ..write(obj.breakBefore);
    for (final field in obj.legacyHiveFields.entries) {
      writer
        ..writeByte(field.key)
        ..write(field.value);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
