import 'package:hive/hive.dart';
import '../models/drive_session.dart';
import '../models/route_point.dart';
import '../models/canonical_telemetry_point.dart';
import 'drive_telemetry_storage_service.dart';
import 'gps_session_transfer.dart';

Map<String, dynamic> driveTransferManifest(DriveSession d) => {
  'id': d.id,
  'dateMicros': d.date.microsecondsSinceEpoch,
  'dateIsUtc': d.date.isUtc,
  'distance': d.distance,
  'durationSeconds': d.durationSeconds,
  'averageSpeed': d.averageSpeed,
  'maxSpeed': d.maxSpeed,
  'mapImagePath': d.mapImagePath,
  'route': d.route
      .map(
        (p) => {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'breakBefore': p.breakBefore,
        },
      )
      .toList(),
  'stopCount': d.stopCount,
  'stoppedSeconds': d.stoppedSeconds,
  'hardBrakeCount': d.hardBrakeCount,
  'hardAccelerationCount': d.hardAccelerationCount,
  'sharpTurnCount': d.sharpTurnCount,
  'maxAccelerationG': d.maxAccelerationG,
  'maxBrakingG': d.maxBrakingG,
  'maxCorneringSpeed': d.maxCorneringSpeed,
  'cornerCount': d.cornerCount,
  'maxAltitude': d.maxAltitude,
  'altitudeGain': d.altitudeGain,
  'altitudeLoss': d.altitudeLoss,
  'bestZeroToHundredSeconds': d.bestZeroToHundredSeconds,
  'bestSixtyToHundredSeconds': d.bestSixtyToHundredSeconds,
};

DriveSession driveFromTransferManifest(Map<String, dynamic> m) => DriveSession(
  id: m['id'] as String,
  date: DateTime.fromMicrosecondsSinceEpoch(
    m['dateMicros'] as int,
    isUtc: m['dateIsUtc'] as bool,
  ),
  distance: (m['distance'] as num).toDouble(),
  durationSeconds: m['durationSeconds'] as int,
  averageSpeed: (m['averageSpeed'] as num).toDouble(),
  maxSpeed: (m['maxSpeed'] as num).toDouble(),
  mapImagePath: m['mapImagePath'] as String,
  route: (m['route'] as List)
      .map(
        (p) => RoutePoint(
          latitude: (p['latitude'] as num).toDouble(),
          longitude: (p['longitude'] as num).toDouble(),
          breakBefore: p['breakBefore'] as bool,
        ),
      )
      .toList(),
  stopCount: m['stopCount'] as int,
  stoppedSeconds: m['stoppedSeconds'] as int,
  hardBrakeCount: m['hardBrakeCount'] as int,
  hardAccelerationCount: m['hardAccelerationCount'] as int,
  sharpTurnCount: m['sharpTurnCount'] as int,
  maxAccelerationG: (m['maxAccelerationG'] as num).toDouble(),
  maxBrakingG: (m['maxBrakingG'] as num).toDouble(),
  maxCorneringSpeed: (m['maxCorneringSpeed'] as num).toDouble(),
  cornerCount: m['cornerCount'] as int,
  maxAltitude: (m['maxAltitude'] as num).toDouble(),
  altitudeGain: (m['altitudeGain'] as num).toDouble(),
  altitudeLoss: (m['altitudeLoss'] as num?)?.toDouble(),
  bestZeroToHundredSeconds: (m['bestZeroToHundredSeconds'] as num?)?.toDouble(),
  bestSixtyToHundredSeconds: (m['bestSixtyToHundredSeconds'] as num?)
      ?.toDouble(),
);

class GpsHiveTransferSink implements GpsTransferSink {
  @override
  Future<Map<String, dynamic>?> readDrive(String id) async {
    final d = Hive.box<DriveSession>('drives').get(id);
    return d == null ? null : driveTransferManifest(d);
  }

  @override
  Future<List<CanonicalTelemetryPoint>?> readTelemetry(String id) async =>
      DriveTelemetryStorageService.get(id)?.points;
  @override
  Future<void> writeDrive(String id, Map<String, dynamic> manifest) =>
      Hive.box<DriveSession>(
        'drives',
      ).put(id, driveFromTransferManifest(manifest));
  @override
  Future<void> writeTelemetry(
    String id,
    List<CanonicalTelemetryPoint> points,
    Map<String, dynamic> metadata,
  ) async {
    // Empty telemetry still needs an explicit receipt, rather than absence.
    await Hive.box<DriveTelemetryRecord>(DriveTelemetryHive.boxName).put(
      id,
      DriveTelemetryRecord(
        driveSessionId: id,
        dataVersion: 1,
        createdAt: DateTime.now(),
        points: points,
        acquisitionMetadata: metadata,
      ),
    );
  }

  @override
  Future<void> flush() async {
    await Hive.box<DriveSession>('drives').flush();
    await Hive.box<DriveTelemetryRecord>(DriveTelemetryHive.boxName).flush();
  }
}
