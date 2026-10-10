import '../models/drive_session.dart';
import '../models/drive_score_record.dart';
import '../models/canonical_telemetry_point.dart';
import '../features/my_world/models/validated_road.dart';
import '../features/my_world/models/matched_road_point.dart';
import '../features/my_world/models/matched_road_section.dart';
import 'gps_hive_transfer_sink.dart';
import 'gps_session_transfer.dart';

/// Private local payload only. No inferred timestamps, account assignment,
/// external file dependency, new Hive type IDs, or network credentials.
class LocalSourceBundle {
  const LocalSourceBundle({
    required this.drive,
    this.telemetry,
    this.score,
    this.roads = const [],
    this.ownerScope = 'unassigned',
  });
  final DriveSession drive;
  final DriveTelemetryRecord? telemetry;
  final DriveScoreRecord? score;
  final List<ValidatedRoad> roads;
  final String ownerScope;

  Map<String, dynamic> toMap() => {
    'version': 1,
    'ownerScope': ownerScope,
    'drive': {...driveTransferManifest(drive), 'mapImagePath': ''},
    'telemetry': telemetry == null
        ? null
        : {
            'driveId': telemetry!.driveSessionId,
            'version': telemetry!.dataVersion,
            'createdAt': telemetry!.createdAt.toIso8601String(),
            'metadata': telemetry!.acquisitionMetadata,
            'points': telemetry!.points
                .map(GpsSessionTransfer.pointContent)
                .toList(),
          },
    'score': score == null
        ? null
        : {
            'driveId': score!.driveId,
            'algorithm': score!.algorithmVersion,
            'telemetryVersion': score!.telemetryDataVersion,
            'calculatedAt': score!.calculatedAt.toIso8601String(),
            'total': score!.totalScore,
            'confidence': score!.overallConfidence,
            'categories': score!.categories.map((c) => c.toMap()).toList(),
          },
    'roads': roads.map(_roadMap).toList(),
  };

  factory LocalSourceBundle.fromMap(Map<String, dynamic> m) {
    if (m['version'] != 1) throw StateError('Unsupported source version');
    final t = m['telemetry'] as Map?;
    final s = m['score'] as Map?;
    return LocalSourceBundle(
      drive: driveFromTransferManifest(Map<String, dynamic>.from(m['drive'])),
      ownerScope: m['ownerScope'] as String,
      telemetry: t == null
          ? null
          : DriveTelemetryRecord(
              driveSessionId: t['driveId'],
              dataVersion: t['version'],
              createdAt: DateTime.parse(t['createdAt']),
              acquisitionMetadata: Map<String, dynamic>.from(t['metadata']),
              points: (t['points'] as List).map((p) {
                final result = CanonicalTelemetryPoint.fromMap(
                  Map<String, dynamic>.from(p),
                );
                if (result == null) {
                  throw StateError('Invalid source telemetry');
                }
                return result;
              }).toList(),
            ),
      score: s == null
          ? null
          : DriveScoreRecord(
              driveId: s['driveId'],
              algorithmVersion: s['algorithm'],
              telemetryDataVersion: s['telemetryVersion'],
              calculatedAt: DateTime.parse(s['calculatedAt']),
              totalScore: (s['total'] as num).toDouble(),
              overallConfidence: (s['confidence'] as num).toDouble(),
              categories: (s['categories'] as List)
                  .map((c) => DriveScoreCategoryRecord.fromMap(c))
                  .toList(),
            ),
      roads: (m['roads'] as List).map((r) => _roadFromMap(r)).toList(),
    );
  }

  void validate() {
    if (drive.id.isEmpty ||
        ownerScope.isEmpty ||
        (telemetry != null && telemetry!.driveSessionId != drive.id) ||
        (score != null && score!.driveId != drive.id) ||
        roads.any((r) => r.driveSessionId != drive.id)) {
      throw StateError('Source identity mismatch');
    }
    if (!drive.distance.isFinite ||
        drive.distance < 0 ||
        drive.durationSeconds < 0 ||
        drive.route.any(
          (p) =>
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180,
        ) ||
        (telemetry?.points.any((p) => !p.hasValidCoordinate) ?? false)) {
      throw StateError('Invalid source geometry or metrics');
    }
    for (final road in roads) {
      if (road.id.isEmpty ||
          !road.validDistanceMeters.isFinite ||
          road.validDistanceMeters < 0 ||
          [...road.geometry, ...road.sections.expand((s) => s.geometry)].any(
            (p) =>
                !p.latitude.isFinite ||
                !p.longitude.isFinite ||
                p.latitude.abs() > 90 ||
                p.longitude.abs() > 180,
          )) {
        throw StateError('Invalid validated source');
      }
    }
  }

  static Map<String, dynamic> _pointMap(MatchedRoadPoint p) => {
    'lat': p.latitude,
    'lon': p.longitude,
    'heading': p.headingDegrees,
    'reference': p.providerRoadReference,
    'confidence': p.confidence,
  };
  static MatchedRoadPoint _pointFromMap(Map p) => MatchedRoadPoint(
    latitude: (p['lat'] as num).toDouble(),
    longitude: (p['lon'] as num).toDouble(),
    headingDegrees: (p['heading'] as num?)?.toDouble(),
    providerRoadReference: p['reference'],
    confidence: (p['confidence'] as num?)?.toDouble(),
  );
  static Map<String, dynamic> _roadMap(ValidatedRoad r) => {
    'id': r.id,
    'driveId': r.driveSessionId,
    'geometry': r.geometry.map(_pointMap).toList(),
    'sections': r.sections
        .map(
          (s) => {
            'id': s.id,
            'geometry': s.geometry.map(_pointMap).toList(),
            'distance': s.distanceMeters,
            'confidence': s.confidence,
            'trace': s.sourceTraceIndex,
            'chunk': s.sourceChunkIndex,
          },
        )
        .toList(),
    'distance': r.validDistanceMeters,
    'status': r.status.name,
    'validatedAt': r.validatedAt?.toIso8601String(),
    'provider': r.providerId,
    'confidence': r.confidence,
    'version': r.processingVersion,
    'retry': r.requiresRetry,
    'direction': r.directionKey,
    'heading': r.averageHeadingDegrees,
    'createdAt': r.createdAt.toIso8601String(),
    'updatedAt': r.updatedAt.toIso8601String(),
  };
  static ValidatedRoad _roadFromMap(Map r) => ValidatedRoad(
    id: r['id'],
    driveSessionId: r['driveId'],
    geometry: (r['geometry'] as List).map((p) => _pointFromMap(p)).toList(),
    sections: (r['sections'] as List)
        .map(
          (s) => MatchedRoadSection(
            id: s['id'],
            geometry: (s['geometry'] as List)
                .map((p) => _pointFromMap(p))
                .toList(),
            distanceMeters: (s['distance'] as num).toDouble(),
            confidence: (s['confidence'] as num?)?.toDouble(),
            sourceTraceIndex: s['trace'],
            sourceChunkIndex: s['chunk'],
          ),
        )
        .toList(),
    validDistanceMeters: (r['distance'] as num).toDouble(),
    status: RoadValidationStatus.values.byName(r['status']),
    validatedAt: r['validatedAt'] == null
        ? null
        : DateTime.parse(r['validatedAt']),
    providerId: r['provider'],
    confidence: (r['confidence'] as num?)?.toDouble(),
    processingVersion: r['version'],
    requiresRetry: r['retry'],
    directionKey: r['direction'],
    averageHeadingDegrees: (r['heading'] as num?)?.toDouble(),
    createdAt: DateTime.parse(r['createdAt']),
    updatedAt: DateTime.parse(r['updatedAt']),
  );
}
