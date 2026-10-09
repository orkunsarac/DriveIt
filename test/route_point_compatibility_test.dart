import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'support/legacy_route_fixture.dart';

void main() {
  for (final value in <Object?>[null, DateTime.utc(2025, 9, 28), true, false]) {
    test(
      'legacy binary field 2=$value is preserved without casting DateTime',
      () {
        final old = HiveImpl()..registerAdapter(LegacyRouteFixtureAdapter());
        final writer = BinaryWriterImpl(old)..write(LegacyRouteFixture(value));
        final current = HiveImpl()..registerAdapter(RoutePointAdapter());
        final point =
            BinaryReaderImpl(writer.toBytes(), current).read() as RoutePoint;
        expect(point.latitude, 40);
        expect(point.longitude, 29);
        expect(point.breakBefore, value is bool ? value : false);
        expect(point.legacyHiveFields[2], value);
        final rewritten = BinaryWriterImpl(current)..write(point);
        final reread =
            BinaryReaderImpl(rewritten.toBytes(), current).read() as RoutePoint;
        expect(reread.legacyHiveFields[2], value);
        expect(reread.breakBefore, point.breakBefore);
      },
    );
  }
  for (final value in [false, true]) {
    test('new binary field 254=$value; no reused field 2', () {
      final hive = HiveImpl()..registerAdapter(RoutePointAdapter());
      final writer = BinaryWriterImpl(hive)
        ..write(RoutePoint(latitude: 40, longitude: 29, breakBefore: value));
      final read =
          BinaryReaderImpl(writer.toBytes(), hive).read() as RoutePoint;
      expect(read.breakBefore, value);
      expect(read.legacyHiveFields, isEmpty);
    });
  }
  test(
    'real Hive frames: nested legacy points, mixed box, reopen and rewrite',
    () async {
      final dir = await Directory.systemTemp.createTemp('route_compat_');
      final old = HiveImpl()
        ..init(dir.path)
        ..registerAdapter(LegacyRouteFixtureAdapter())
        ..registerAdapter(LegacyDriveFixtureAdapter());
      final box = await old.openBox<LegacyDriveFixture>('drives');
      final timestamp = DateTime.utc(2025, 9, 28);
      await box.put(
        'legacy',
        LegacyDriveFixture([
          LegacyRouteFixture(timestamp),
          const LegacyRouteFixture(null),
        ]),
      );
      await old.close();
      final bytesBefore = await File('${dir.path}/drives.hive').readAsBytes();
      final current = HiveImpl()
        ..init(dir.path)
        ..registerAdapter(RoutePointAdapter())
        ..registerAdapter(DriveSessionAdapter());
      final drives = await current.openBox<DriveSession>('drives');
      final drive = drives.get('legacy')!;
      expect(drive.route.length, 2);
      expect(drive.route.first.legacyHiveFields[2], timestamp);
      expect(drive.route.every((p) => !p.breakBefore), isTrue);
      expect(await File('${dir.path}/drives.hive').readAsBytes(), bytesBefore);
      await drives.put(
        'new',
        DriveSession(
          id: 'new',
          date: DateTime.utc(2026),
          distance: 100,
          durationSeconds: 60,
          averageSpeed: 6,
          maxSpeed: 10,
          mapImagePath: '',
          route: [RoutePoint(latitude: 40, longitude: 29, breakBefore: true)],
        ),
      );
      await drives.put('legacy', drive);
      await drives.close();
      final reopened = await current.openBox<DriveSession>('drives');
      expect(reopened.length, 2);
      expect(
        reopened.get('legacy')!.route.first.legacyHiveFields[2],
        timestamp,
      );
      expect(reopened.get('legacy')!.distance, 100);
      expect(reopened.get('new')!.route.first.breakBefore, isTrue);
      await current.close();
      await dir.delete(recursive: true);
    },
  );
}
