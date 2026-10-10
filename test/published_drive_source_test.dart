import 'dart:convert';

import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/models/published_drive_source.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/published_drive_source_builder.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';

final _end = DateTime.utc(2026, 9, 23, 12, 2, 3, 456, 789);

DriveSession _drive({List<RoutePoint>? route}) => DriveSession(
  id: 'stable-drive-id',
  date: _end,
  distance: 5123.123456789,
  durationSeconds: 123,
  averageSpeed: 40,
  maxSpeed: 80,
  mapImagePath: 'not-a-source-field',
  route:
      route ??
      [
        RoutePoint(latitude: 40.123456789123, longitude: 29.987654321987),
        RoutePoint(latitude: 40.123456789124, longitude: 29.987654321988),
        RoutePoint(latitude: 40.123456789125, longitude: 29.987654321989),
        RoutePoint(latitude: 40.123456789126, longitude: 29.987654321990),
      ],
);

WorldPublish _publish({String localDriveId = 'stable-drive-id'}) =>
    WorldPublish(
      id: 'publish-uuid',
      userId: 'server-user',
      localDriveId: localDriveId,
      startedAt: _end.subtract(const Duration(seconds: 123)),
      endedAt: _end,
      distanceMeters: 5123.123456789,
      worldRulesVersion: MyWorldRules.worldRulesVersion,
      status: WorldPublishStatus.pending,
      errorCode: null,
      createdAt: _end,
      updatedAt: _end,
      processedAt: null,
    );

DriveTelemetryRecord _telemetry({
  String driveId = 'stable-drive-id',
  List<CanonicalTelemetryPoint>? points,
}) => DriveTelemetryRecord(
  driveSessionId: driveId,
  dataVersion: DriveTelemetryRecord.currentDataVersion,
  createdAt: _end,
  acquisitionMetadata: const {'reliabilityPolicyVersion': 1},
  points:
      points ??
      List.generate(
        201,
        (index) => CanonicalTelemetryPoint(
          latitude: 40.123456789123 + index * 0.000000000001,
          longitude: 29.987654321987 + index * 0.000000000001,
          timestamp: _end.subtract(Duration(seconds: 200 - index)),
          speedMps: 8.123456789123 + index,
          headingDegrees: 91.23456789123 + index,
          altitudeMeters: 50.123456789123 + index,
          accuracyMeters: 2.123456789123 + index % 3,
          distanceFromPreviousMeters: index == 0 ? 0 : 25.123456789123,
          accelerationMps2: -0.123456789123 + index,
        ),
      ),
);

void main() {
  test(
    'copies every raw and canonical point in original order without rounding',
    () {
      final drive = _drive();
      final telemetry = _telemetry();
      String? loadedId;
      final builder = PublishedDriveSourceBuilder(
        telemetryLoader: (id) {
          loadedId = id;
          return telemetry;
        },
      );

      final result = builder.build(drive: drive, publish: _publish());
      expect(result.status, PublishedDriveSourceBuildStatus.success);
      final source = result.source!;
      expect(loadedId, drive.id);
      expect(source.schemaVersion, PublishedDriveSourceSchema.currentVersion);
      expect(source.publishId, 'publish-uuid');
      expect(source.localDriveId, drive.id);
      expect(source.telemetryVersion, telemetry.dataVersion);
      expect(
        source.driveScoreAlgorithmVersion,
        DriveScoreAlgorithmVersion.v1.value,
      );
      expect(source.worldRulesVersion, MyWorldRules.worldRulesVersion);
      expect(source.startedAt, _end.subtract(const Duration(seconds: 123)));
      expect(source.endedAt, _end);
      expect(source.recordedDistanceMeters, drive.distance);
      expect(source.rawRoute.length, drive.route.length);
      expect(source.canonicalTelemetry.length, telemetry.points.length);
      for (var i = 0; i < drive.route.length; i++) {
        expect(source.rawRoute[i].latitude, drive.route[i].latitude);
        expect(source.rawRoute[i].longitude, drive.route[i].longitude);
      }
      for (var i = 0; i < telemetry.points.length; i++) {
        final actual = source.canonicalTelemetry[i];
        final expected = telemetry.points[i];
        expect(actual.latitude, expected.latitude);
        expect(actual.longitude, expected.longitude);
        expect(actual.timestamp, expected.timestamp);
        expect(actual.speedMps, expected.speedMps);
        expect(actual.headingDegrees, expected.headingDegrees);
        expect(actual.altitudeMeters, expected.altitudeMeters);
        expect(actual.accuracyMeters, expected.accuracyMeters);
        expect(
          actual.distanceFromPreviousMeters,
          expected.distanceFromPreviousMeters,
        );
        expect(actual.accelerationMps2, expected.accelerationMps2);
      }
      expect(() => source.rawRoute.clear(), throwsUnsupportedError);
      expect(() => source.canonicalTelemetry.clear(), throwsUnsupportedError);
      drive.route.first.latitude = 0;
      expect(source.rawRoute.first.latitude, 40.123456789123);
    },
  );

  test('JSON round-trip retains all fields, order and microseconds', () {
    final source = PublishedDriveSourceBuilder(
      telemetryLoader: (_) => _telemetry(),
    ).build(drive: _drive(), publish: _publish()).source!;
    final encoded = jsonEncode(source.toJson());
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final restored = PublishedDriveSource.fromJson(decoded);
    expect(restored.toJson(), source.toJson());
    expect(
      restored.startedAt.microsecondsSinceEpoch,
      source.startedAt.microsecondsSinceEpoch,
    );
    expect(
      restored.endedAt.microsecondsSinceEpoch,
      source.endedAt.microsecondsSinceEpoch,
    );
    expect(
      (decoded['canonical_telemetry'] as List).first.keys,
      containsAll([
        'latitude',
        'longitude',
        'timestamp',
        'speed_mps',
        'heading_degrees',
        'altitude_meters',
        'accuracy_meters',
        'distance_from_previous_meters',
        'acceleration_mps2',
      ]),
    );
    expect(decoded.keys, isNot(contains('average_speed')));
    expect(decoded.keys, isNot(contains('max_speed')));
    expect(decoded.keys, isNot(contains('map_image_path')));
  });

  test('missing or insufficient telemetry never produces a payload', () {
    for (final record in <DriveTelemetryRecord?>[
      null,
      _telemetry(points: [_telemetry().points.first]),
    ]) {
      final result = PublishedDriveSourceBuilder(
        telemetryLoader: (_) => record,
      ).build(drive: _drive(), publish: _publish());
      expect(
        result.status,
        PublishedDriveSourceBuildStatus.missingCanonicalTelemetry,
      );
      expect(result.source, isNull);
    }
  });

  test('publish/drive mismatch is typed and does not read telemetry', () {
    final result =
        PublishedDriveSourceBuilder(
          telemetryLoader: (_) => fail('telemetry should not be read'),
        ).build(
          drive: _drive(),
          publish: _publish(localDriveId: 'other'),
        );
    expect(result.status, PublishedDriveSourceBuildStatus.publishDriveMismatch);
    expect(result.source, isNull);
  });

  test('unusable raw route and invalid canonical telemetry are rejected', () {
    final badRoute = _drive(
      route: [
        RoutePoint(latitude: 40, longitude: 29),
        RoutePoint(latitude: 40, longitude: 29),
      ],
    );
    final builder = PublishedDriveSourceBuilder(
      telemetryLoader: (_) => _telemetry(),
    );
    expect(
      builder.build(drive: badRoute, publish: _publish()).status,
      PublishedDriveSourceBuildStatus.invalidDrive,
    );
    final badRecord = _telemetry(driveId: 'other');
    expect(
      PublishedDriveSourceBuilder(
        telemetryLoader: (_) => badRecord,
      ).build(drive: _drive(), publish: _publish()).status,
      PublishedDriveSourceBuildStatus.invalidCanonicalTelemetry,
    );
  });
}
