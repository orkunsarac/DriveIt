import '../../../models/drive_score_record.dart';
import '../../../models/drive_session.dart';
import '../models/world_trace_detail.dart';

typedef WorldDriveLoader = DriveSession? Function(String driveId);
typedef WorldScoreLoader = DriveScoreRecord? Function(String driveId);
typedef WorldActiveDistanceLoader = Future<double> Function(String driveId);

class WorldTraceDetailService {
  const WorldTraceDetailService({
    required this.driveLoader,
    required this.scoreLoader,
    required this.activeDistanceLoader,
  });

  final WorldDriveLoader driveLoader;
  final WorldScoreLoader scoreLoader;
  final WorldActiveDistanceLoader activeDistanceLoader;

  Future<WorldTraceDetail?> load(String driveId) async {
    final drive = driveLoader(driveId);
    if (drive == null) return null;
    return WorldTraceDetail(
      drive: drive,
      score: scoreLoader(driveId),
      activeWorldDistanceMeters: await activeDistanceLoader(driveId),
    );
  }

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
