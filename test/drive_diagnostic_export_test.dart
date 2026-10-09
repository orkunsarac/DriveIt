import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/services/drive_diagnostic_export.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';

void main() {
  test('validated road geometry and sections exported without mutation', () {
    final geometry = [
      const MatchedRoadPoint(
        latitude: 40,
        longitude: 29,
        headingDegrees: 90,
        providerRoadReference: 'road',
        confidence: 0.8,
      ),
    ];
    final road = ValidatedRoad(
      id: 'v',
      driveSessionId: 'd',
      geometry: geometry,
      sections: [
        MatchedRoadSection(
          id: 's',
          geometry: geometry,
          distanceMeters: 44,
          confidence: 0.8,
          sourceTraceIndex: 2,
          sourceChunkIndex: 3,
        ),
      ],
      validDistanceMeters: 44,
      status: RoadValidationStatus.partiallyValidated,
      validatedAt: DateTime.utc(2026),
      providerId: 'provider',
      confidence: 0.8,
      processingVersion: 1,
      directionKey: 'forward',
      averageHeadingDegrees: 90,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final d = DriveSession(
      id: 'd',
      date: DateTime.utc(2026),
      distance: 44,
      durationSeconds: 10,
      averageSpeed: 0,
      maxSpeed: 0,
      mapImagePath: '',
      route: [],
    );
    final data = jsonDecode(
      jsonEncode(DriveDiagnosticExport.build(d, null, [road])),
    );
    expect(data['validatedRoads'][0]['sections'][0]['sourceChunkIndex'], 3);
    expect(
      data['validatedRoads'][0]['geometry'][0]['providerRoadReference'],
      'road',
    );
    expect(identical(road.geometry, geometry), true);
    expect(road.geometry.length, 1);
    expect(d.route, isEmpty);
  });
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('drive-export-test-');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DriveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RoutePointAdapter());
    DriveTelemetryHive.registerAdapters(Hive);
    await Hive.openBox<DriveSession>('drives');
    await DriveTelemetryHive.openBox(Hive);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  DriveSession drive() => DriveSession(
    id: 'test',
    date: DateTime.utc(2026),
    distance: 55,
    durationSeconds: 60,
    averageSpeed: 3.3,
    maxSpeed: 12,
    mapImagePath: '',
    route: [
      RoutePoint(latitude: 40, longitude: 29),
      RoutePoint(latitude: 40.001, longitude: 29),
    ],
  );
  CanonicalTelemetryPoint point(int seconds, double lat) =>
      CanonicalTelemetryPoint(
        latitude: lat,
        longitude: 29,
        timestamp: DateTime.utc(
          2026,
        ).add(Duration(seconds: seconds, microseconds: 123)),
        speedMps: 2,
        headingDegrees: 90,
        altitudeMeters: 50,
        accuracyMeters: 4,
        distanceFromPreviousMeters: 7,
        accelerationMps2: 0.2,
      );
  test('missing telemetry produces valid JSON and no writes', () async {
    final box = Hive.box<DriveSession>('drives');
    await box.put('test', drive());
    final before = await File('${dir.path}/drives.hive').readAsBytes();
    final data = DriveDiagnosticExport.read('test');
    expect(jsonDecode(jsonEncode(data))['telemetryAvailable'], false);
    expect(data['route'], hasLength(2));
    expect(await File('${dir.path}/drives.hive').readAsBytes(), before);
    expect(Hive.box<DriveTelemetryRecord>('drive_telemetry').isEmpty, true);
  });
  test(
    'all canonical data/order preserved; read does not change Hive bytes',
    () async {
      await Hive.box<DriveSession>('drives').put('test', drive());
      final points = [point(0, 40), point(6, 40.0005), point(22, 40.001)];
      await DriveTelemetryStorageService.save(
        driveSessionId: 'test',
        points: points,
      );
      final before = {
        for (final name in ['drives', 'drive_telemetry'])
          name: await File('${dir.path}/$name.hive').readAsBytes(),
      };
      final data = jsonDecode(jsonEncode(DriveDiagnosticExport.read('test')));
      final samples = data['telemetry']['points'] as List;
      expect(samples.length, 3);
      for (var i = 0; i < points.length; i++) {
        expect(samples[i]['latitude'], points[i].latitude);
        expect(
          samples[i]['timestampEpochMicroseconds'],
          points[i].timestamp.microsecondsSinceEpoch,
        );
        expect(samples[i]['accuracyMeters'], 4);
        expect(samples[i]['speedMps'], 2);
        expect(samples[i]['headingDegrees'], 90);
        expect(samples[i]['distanceFromPreviousMeters'], 7);
        expect(samples[i]['altitudeMeters'], 50);
        expect(samples[i]['accelerationMps2'], 0.2);
      }
      expect(data['diagnostics']['intervals'][0]['gapOver5Seconds'], true);
      expect(data['diagnostics']['intervals'][1]['gapOver15Seconds'], true);
      expect(data['diagnostics']['unusedTelemetryIndices'], [1]);
      for (final name in before.keys) {
        expect(
          await File('${dir.path}/$name.hive').readAsBytes(),
          before[name],
        );
      }
      expect(data['drive']['dateMeaning'], contains('not a verified'));
    },
  );
  test('ambiguous repeated coordinates are not labelled unused', () {
    final d = drive();
    final p = point(0, 40);
    final data = DriveDiagnosticExport.build(
      d,
      DriveTelemetryRecord(
        driveSessionId: d.id,
        dataVersion: 1,
        createdAt: DateTime.utc(2026),
        points: [p, p, point(20, 40.001)],
      ),
      [],
    );
    expect((data['diagnostics'] as Map)['unusedTelemetryIndices'], null);
  });
}
