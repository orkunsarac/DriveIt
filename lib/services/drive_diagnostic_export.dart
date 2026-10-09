import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/drive_session.dart';
import '../models/canonical_telemetry_point.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/models/matched_road_point.dart';
import '../features/my_world/persistence/my_world_hive.dart';
import 'drive_telemetry_storage_service.dart';

/// Reads existing boxes only. Never opens boxes, invokes analysis persistence,
/// or accesses account/configuration storage.
class DriveDiagnosticExport {
  static Map<String, Object?> read(String id) {
    final drive = Hive.box<DriveSession>('drives').get(id);
    if (drive == null) throw StateError('Sürüş kaydı bulunamadı.');
    final roads = Hive.isBoxOpen(MyWorldHive.validatedRoadsBoxName)
        ? Hive.box<ValidatedRoad>(
            MyWorldHive.validatedRoadsBoxName,
          ).values.where((r) => r.driveSessionId == id).toList()
        : <ValidatedRoad>[];
    return build(drive, DriveTelemetryStorageService.get(id), roads);
  }

  static Future<void> share(String id) async {
    final json = const JsonEncoder.withIndent('  ').convert(read(id));
    final directory = await getTemporaryDirectory();
    final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final exportDirectory = Directory('${directory.path}/drive_diagnostics');
    await exportDirectory.create(recursive: true);
    final file = File('${exportDirectory.path}/drive-diagnostic-$safeId.json');
    await file.writeAsString(json, flush: true);
    await const MethodChannel(
      'driveit/posters',
    ).invokeMethod<void>('shareDiagnosticJson', {'path': file.path});
  }

  static Map<String, Object?> coordinate(double lat, double lon) => {
    'latitude': lat,
    'longitude': lon,
  };
  static Map<String, Object?> matched(MatchedRoadPoint p) => {
    ...coordinate(p.latitude, p.longitude),
    'headingDegrees': p.headingDegrees,
    'providerRoadReference': p.providerRoadReference,
    'confidence': p.confidence,
  };
  static double distance(double a, double b, double c, double d) {
    final lat = (c - a) * math.pi / 180, lon = (d - b) * math.pi / 180;
    final h =
        math.pow(math.sin(lat / 2), 2) +
        math.cos(a * math.pi / 180) *
            math.cos(c * math.pi / 180) *
            math.pow(math.sin(lon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }

  static Map<String, Object?> build(
    DriveSession d,
    DriveTelemetryRecord? record,
    List<ValidatedRoad> roads,
  ) {
    final points = record?.points ?? <CanonicalTelemetryPoint>[];
    final intervals = <Map<String, Object?>>[];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final dt = b.timestamp.difference(a.timestamp).inMicroseconds / 1000000;
      final metres = distance(a.latitude, a.longitude, b.latitude, b.longitude);
      final speed = dt > 0 ? metres / dt : null;
      intervals.add({
        'fromIndex': i - 1,
        'toIndex': i,
        'seconds': dt,
        'geometryDistanceMeters': metres,
        'geometryAverageSpeedMps': speed,
        'gapOver5Seconds': dt > 5,
        'gapOver15Seconds': dt > 15,
        'nonIncreasingTimestamp': dt <= 0,
        'unusualJump': metres > 120 || (speed != null && speed > 80),
      });
    }
    // Exact, ordered subsequence matching only; no nearest-point guesses.
    final used = <int>{};
    var cursor = 0;
    var reliable = points.isNotEmpty;
    for (final r in d.route) {
      while (cursor < points.length &&
          !(points[cursor].latitude == r.latitude &&
              points[cursor].longitude == r.longitude)) {
        cursor++;
      }
      if (cursor == points.length) {
        reliable = false;
        break;
      }
      used.add(cursor++);
    }
    double? endpoint(bool first) {
      if (d.route.isEmpty || points.isEmpty) return null;
      final r = first ? d.route.first : d.route.last;
      final t = first ? points.first : points.last;
      return distance(r.latitude, r.longitude, t.latitude, t.longitude);
    }

    return {
      'schemaVersion': 1,
      'telemetryAvailable': record != null,
      'drive': {
        'id': d.id,
        'date': d.date.toIso8601String(),
        'dateEpochMicroseconds': d.date.microsecondsSinceEpoch,
        'dateMeaning': 'record save date; not a verified drive end time',
        'distanceMeters': d.distance,
        'durationSeconds': d.durationSeconds,
        'averageSpeedKmh': d.averageSpeed,
        'maxSpeedKmh': d.maxSpeed,
        'mapImagePath': d.mapImagePath,
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
      },
      'route': [
        for (final p in d.route)
          {
            ...coordinate(p.latitude, p.longitude),
            if (p.breakBefore) 'breakBefore': true,
          },
      ],
      'telemetry': {
        'driveSessionId': record?.driveSessionId,
        'dataVersion': record?.dataVersion,
        'createdAt': record?.createdAt.toIso8601String(),
        'acquisitionMetadata': record?.acquisitionMetadata ?? const {},
        'points': [
          for (final p in points)
            {
              ...coordinate(p.latitude, p.longitude),
              'timestamp': p.timestamp.toIso8601String(),
              'timestampEpochMicroseconds': p.timestamp.microsecondsSinceEpoch,
              'speedMps': p.speedMps,
              'headingDegrees': p.headingDegrees,
              'altitudeMeters': p.altitudeMeters,
              'accuracyMeters': p.accuracyMeters,
              'distanceFromPreviousMeters': p.distanceFromPreviousMeters,
              'accelerationMps2': p.accelerationMps2,
              'speedSource': p.speedSource,
              'accelerationReliable': p.accelerationReliable,
              'breakBefore': p.breakBefore,
              'gapDurationMicros': p.gapDurationMicros,
            },
        ],
      },
      'validatedRoads': [
        for (final r in roads)
          {
            'id': r.id,
            'driveSessionId': r.driveSessionId,
            'geometry': r.geometry.map(matched).toList(),
            'sections': [
              for (final s in r.sections)
                {
                  'id': s.id,
                  'geometry': s.geometry.map(matched).toList(),
                  'distanceMeters': s.distanceMeters,
                  'confidence': s.confidence,
                  'sourceTraceIndex': s.sourceTraceIndex,
                  'sourceChunkIndex': s.sourceChunkIndex,
                },
            ],
            'validDistanceMeters': r.validDistanceMeters,
            'status': r.status.name,
            'validatedAt': r.validatedAt?.toIso8601String(),
            'providerId': r.providerId,
            'confidence': r.confidence,
            'processingVersion': r.processingVersion,
            'requiresRetry': r.requiresRetry,
            'directionKey': r.directionKey,
            'averageHeadingDegrees': r.averageHeadingDegrees,
            'createdAt': r.createdAt.toIso8601String(),
            'updatedAt': r.updatedAt.toIso8601String(),
          },
      ],
      'diagnostics': {
        'intervals': intervals,
        'possibleInterruptionIntervals': intervals
            .where(
              (x) =>
                  x['gapOver5Seconds'] == true ||
                  x['unusualJump'] == true ||
                  x['nonIncreasingTimestamp'] == true,
            )
            .toList(),
        'firstEndpointDifferenceMeters': endpoint(true),
        'lastEndpointDifferenceMeters': endpoint(false),
        'routeTelemetryMatching':
            'exact ordered subsequence; repeated coordinates can be ambiguous',
        'routeTelemetryMatchingReliable':
            reliable &&
            points.map((p) => '${p.latitude},${p.longitude}').toSet().length ==
                points.length,
        'unusedTelemetryIndices':
            reliable &&
                points
                        .map((p) => '${p.latitude},${p.longitude}')
                        .toSet()
                        .length ==
                    points.length
            ? [
                for (var i = 0; i < points.length; i++)
                  if (!used.contains(i)) i,
              ]
            : null,
        'limitations':
            'Accepted canonical samples only. Gaps/jumps are indicators, not proven GPS failure causes.',
        'thresholds': {
          'gapSeconds': [5, 15],
          'jumpDistanceMeters': 120,
          'jumpSpeedMps': 80,
        },
      },
    };
  }
}
