import 'dart:math' as math;

import '../../../models/drive_score_record.dart';
import '../../../models/drive_session.dart';
import '../models/world_trace_detail.dart';
import '../models/active_world_trace.dart';
import '../models/matched_road_point.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../drive_score/services/drive_score_calculator.dart';
import '../../../services/drive_telemetry_storage_service.dart';

typedef WorldDriveLoader = DriveSession? Function(String driveId);
typedef WorldScoreLoader = DriveScoreRecord? Function(String driveId);
typedef WorldActiveDistanceLoader = Future<double> Function(String driveId);

class WorldTraceDetailService {
  static const _maxTelemetryEndpointDistanceMeters = 250.0;
  const WorldTraceDetailService({
    required this.driveLoader,
    required this.scoreLoader,
    required this.activeDistanceLoader,
    this.telemetryLoader,
  });

  final WorldDriveLoader driveLoader;
  final WorldScoreLoader scoreLoader;
  final WorldActiveDistanceLoader activeDistanceLoader;
  final WorldTelemetryLoader? telemetryLoader;

  Future<WorldTraceDetail?> load(String driveId) async {
    final drive = driveLoader(driveId);
    if (drive == null) return null;
    return WorldTraceDetail(
      drive: drive,
      score: scoreLoader(driveId),
      activeWorldDistanceMeters: await activeDistanceLoader(driveId),
    );
  }

  Future<WorldTraceDetail?> loadTrace({
    required ActiveWorldTrace trace,
    required List<MatchedRoadPoint> geometry,
  }) async {
    final detail = await load(trace.sourceDriveSessionId);
    if (detail == null || geometry.length < 2) return detail;
    final telemetry =
        await (telemetryLoader ??
            ((id) async =>
                DriveTelemetryStorageService.get(id)?.points ?? const []))(
          trace.sourceDriveSessionId,
        );
    double? segmentScore;
    int? segmentDurationSeconds;
    double? segmentAverageSpeed;
    double? segmentMaxSpeed;
    if (telemetry.length >= 2) {
      final startMatch = _nearestMatch(telemetry, geometry.first);
      final endMatch = _nearestMatch(telemetry, geometry.last);
      if (startMatch.distanceMeters > _maxTelemetryEndpointDistanceMeters ||
          endMatch.distanceMeters > _maxTelemetryEndpointDistanceMeters) {
        return _geometryOnlyDetail(detail, trace, geometry);
      }
      final start = startMatch.index;
      final end = endMatch.index;
      final from = start <= end ? start : end;
      final to = start <= end ? end : start;
      final subset = telemetry.sublist(from, to + 1);
      if (subset.length >= 2) {
        final elapsed = subset.last.timestamp
            .difference(subset.first.timestamp)
            .inSeconds;
        final distance = trace.distanceMeters > 0
            ? trace.distanceMeters
            : subset.fold<double>(
                0,
                (sum, point) => sum + point.distanceFromPreviousMeters,
              );
        segmentDurationSeconds = elapsed > 0 ? elapsed : null;
        segmentAverageSpeed = elapsed > 0 ? distance / elapsed * 3.6 : null;
        segmentMaxSpeed = subset
            .map((point) => point.speedMps * 3.6)
            .reduce(math.max);
        try {
          segmentScore = const DriveScoreCalculator()
              .calculate(telemetry: subset)
              .totalScore;
        } on InsufficientDriveScoreTelemetryException {
          segmentScore = null;
        }
      }
    }
    return WorldTraceDetail(
      drive: detail.drive,
      score: detail.score,
      activeWorldDistanceMeters: detail.activeWorldDistanceMeters,
      worldTraceScore: segmentScore,
      traceDistanceMeters: trace.distanceMeters,
      traceStart: _formatPoint(geometry.first),
      traceEnd: _formatPoint(geometry.last),
      traceDurationSeconds: segmentDurationSeconds,
      traceAverageSpeed: segmentAverageSpeed,
      traceMaxSpeed: segmentMaxSpeed,
      travelDirection: trace.directionKey,
    );
  }

  WorldTraceDetail _geometryOnlyDetail(
    WorldTraceDetail detail,
    ActiveWorldTrace trace,
    List<MatchedRoadPoint> geometry,
  ) => WorldTraceDetail(
    drive: detail.drive,
    score: detail.score,
    activeWorldDistanceMeters: detail.activeWorldDistanceMeters,
    traceDistanceMeters: trace.distanceMeters,
    traceStart: _formatPoint(geometry.first),
    traceEnd: _formatPoint(geometry.last),
    travelDirection: trace.directionKey,
  );

  _TelemetryMatch _nearestMatch(
    List<CanonicalTelemetryPoint> points,
    MatchedRoadPoint target,
  ) {
    var best = 0;
    var distanceSquared = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final dLat = (points[i].latitude - target.latitude) * 111320;
      final dLon =
          (points[i].longitude - target.longitude) *
          111320 *
          math.cos((points[i].latitude + target.latitude) * math.pi / 360);
      final value = dLat * dLat + dLon * dLon;
      if (value < distanceSquared) {
        distanceSquared = value;
        best = i;
      }
    }
    return _TelemetryMatch(best, math.sqrt(distanceSquared));
  }

  String _formatPoint(MatchedRoadPoint point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  static DriveSession? latestProcessedDrive({
    required Iterable<String> processedDriveIds,
    required Iterable<DriveSession> drives,
  }) {
    final processed = processedDriveIds.toSet();
    final candidates = drives
        .where((drive) => processed.contains(drive.id))
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    return candidates.reduce(
      (first, second) => first.date.isAfter(second.date) ? first : second,
    );
  }
}

typedef WorldTelemetryLoader =
    Future<List<CanonicalTelemetryPoint>> Function(String driveId);

class _TelemetryMatch {
  const _TelemetryMatch(this.index, this.distanceMeters);

  final int index;
  final double distanceMeters;
}
