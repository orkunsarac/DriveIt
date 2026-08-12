import 'dart:io';

import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/hive_impl.dart';

void main() {
  test('canonical telemetry and RoutePoint survive Hive round trip', () async {
    final directory = await Directory.systemTemp.createTemp(
      'driveit_telemetry_',
    );
    final hive = HiveImpl()..init(directory.path);
    hive.registerAdapter(RoutePointAdapter());
    DriveTelemetryHive.registerAdapters(hive);

    final routeBox = await hive.openBox<RoutePoint>('route_point_test');
    final routePoint = RoutePoint(latitude: 41.1, longitude: 29.2);
    await routeBox.put('point', routePoint);
    final restoredRoute = routeBox.get('point');

    final telemetryBox = await hive.openBox<DriveTelemetryRecord>(
      DriveTelemetryHive.boxName,
    );
    final timestamp = DateTime(2026, 8, 11, 12, 30);
    final record = DriveTelemetryRecord(
      driveSessionId: 'drive-1',
      dataVersion: DriveTelemetryRecord.currentDataVersion,
      createdAt: timestamp,
      points: [
        CanonicalTelemetryPoint(
          latitude: 41.1,
          longitude: 29.2,
          timestamp: timestamp,
          speedMps: 12.5,
          headingDegrees: 87,
          altitudeMeters: 120,
          accuracyMeters: 4,
          distanceFromPreviousMeters: 8.5,
          accelerationMps2: 1.25,
        ),
      ],
    );
    await telemetryBox.put(record.driveSessionId, record);
    final restored = telemetryBox.get(record.driveSessionId);

    expect(restoredRoute?.latitude, routePoint.latitude);
    expect(restoredRoute?.longitude, routePoint.longitude);
    expect(restored?.driveSessionId, 'drive-1');
    expect(restored?.dataVersion, DriveTelemetryRecord.currentDataVersion);
    expect(restored?.points, hasLength(1));
    expect(restored?.points.single.timestamp, timestamp);
    expect(restored?.points.single.speedMps, 12.5);
    expect(restored?.points.single.distanceFromPreviousMeters, 8.5);
    expect(restored?.points.single.accelerationMps2, 1.25);

    await routeBox.close();
    await telemetryBox.close();
    await directory.delete(recursive: true);
  });

  test('telemetry type IDs do not reuse DriveSession or My World IDs', () {
    expect(DriveTelemetryHive.pointTypeId, 2);
    expect(DriveTelemetryHive.recordTypeId, 3);
    expect(
      {2, 3}.intersection({0, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18}),
      isEmpty,
    );
  });
}
