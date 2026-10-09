import 'package:hive/hive.dart';

/// Synthetic legacy writer, independent of the current RoutePoint model.
/// Field 2's DateTime type is confirmed by the A55 crash; its original semantic
/// name is unavailable in reachable Git history. No real user's route is used.
class LegacyRouteFixture {
  final Object? field2;
  const LegacyRouteFixture(this.field2);
}

class LegacyRouteFixtureAdapter extends TypeAdapter<LegacyRouteFixture> {
  @override
  int get typeId => 1;
  @override
  LegacyRouteFixture read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, LegacyRouteFixture obj) {
    writer
      ..writeByte(obj.field2 == null ? 2 : 3)
      ..writeByte(0)
      ..write(40.0)
      ..writeByte(1)
      ..write(29.0);
    if (obj.field2 != null) {
      writer
        ..writeByte(2)
        ..write(obj.field2);
    }
  }
}

class LegacyDriveFixture {
  final List<LegacyRouteFixture> route;
  const LegacyDriveFixture(this.route);
}

class LegacyDriveFixtureAdapter extends TypeAdapter<LegacyDriveFixture> {
  @override
  int get typeId => 0;
  @override
  LegacyDriveFixture read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, LegacyDriveFixture obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write('legacy')
      ..writeByte(1)
      ..write(DateTime.utc(2025))
      ..writeByte(2)
      ..write(100.0)
      ..writeByte(3)
      ..write(60)
      ..writeByte(4)
      ..write(6.0)
      ..writeByte(5)
      ..write(10.0)
      ..writeByte(6)
      ..write('')
      ..writeByte(7)
      ..write(obj.route);
  }
}
