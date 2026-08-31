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
    if (telemetry.length >= 2) {
      final start = _nearestIndex(telemetry, geometry.first);
      final end = _nearestIndex(telemetry, geometry.last);
      final from = start <= end ? start : end;
      final to = start <= end ? end : start;
      final subset = telemetry.sublist(from, to + 1);
      if (subset.length >= 2) {
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
    );
  }

  int _nearestIndex(
    List<CanonicalTelemetryPoint> points,
    MatchedRoadPoint target,
  ) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final value =
          (points[i].latitude - target.latitude) *
              (points[i].latitude - target.latitude) +
          (points[i].longitude - target.longitude) *
              (points[i].longitude - target.longitude);
      if (value < distance) {
        distance = value;
        best = i;
      }
    }
    return best;
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
