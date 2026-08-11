import 'dart:io';

import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';

void main() {
  test('opens a legacy DriveSession with safe analysis defaults', () async {
    final directory = await Directory.systemTemp.createTemp('driveit_hive_');
    final legacyHive = HiveImpl()..init(directory.path);
    legacyHive.registerAdapter(RoutePointAdapter());
    legacyHive.registerAdapter(_LegacyDriveSessionAdapter());
    final legacyBox = await legacyHive.openBox<_LegacyDriveSession>('drives');
    await legacyBox.put('legacy', _LegacyDriveSession());
    await legacyBox.close();

    final currentHive = HiveImpl()..init(directory.path);
    currentHive.registerAdapter(RoutePointAdapter());
    currentHive.registerAdapter(DriveSessionAdapter());
    final currentBox = await currentHive.openBox<DriveSession>('drives');
    final drive = currentBox.get('legacy');

    expect(drive, isNotNull);
    expect(drive!.distance, 1200);
    expect(drive.route, isEmpty);
    expect(drive.hardBrakeCount, 0);
    expect(drive.hardAccelerationCount, 0);
    expect(drive.bestZeroToHundredSeconds, isNull);

    await currentBox.close();
    await directory.delete(recursive: true);
  });
}

class _LegacyDriveSession {
  final String id = 'legacy';
}

class _LegacyDriveSessionAdapter extends TypeAdapter<_LegacyDriveSession> {
  @override
  int get typeId => 0;

  @override
  _LegacyDriveSession read(BinaryReader reader) => _LegacyDriveSession();

  @override
  void write(BinaryWriter writer, _LegacyDriveSession obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(DateTime(2025, 1, 1))
      ..writeByte(2)
      ..write(1200.0)
      ..writeByte(3)
      ..write(300)
      ..writeByte(4)
      ..write(14.4)
      ..writeByte(5)
      ..write(30.0)
      ..writeByte(6)
      ..write('')
      ..writeByte(7)
      ..write(<RoutePoint>[])
      ..writeByte(8)
      ..write(800.0)
      ..writeByte(9)
      ..write(20.0)
      ..writeByte(10)
      ..write(90.0)
      ..writeByte(11)
      ..write(2)
      ..writeByte(12)
      ..write(1)
      ..writeByte(13)
      ..write(20);
  }
}
