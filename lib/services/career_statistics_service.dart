import '../models/drive_score_record.dart';
import '../models/drive_session.dart';
import 'drive_score_storage_service.dart';
import 'drive_storage_service.dart';

/// Read-only, deterministic lifetime statistics derived from saved drives.
/// It deliberately does not write a second career cache or mutate a drive.
class CareerStatisticsService {
  const CareerStatisticsService();

  CareerStatistics calculate({List<DriveSession>? drives}) {
    final source = drives ?? DriveStorageService.getAllDrives();
    if (source.isEmpty) return const CareerStatistics.empty();
    final scores = <DriveScoreRecord>[];
    for (final drive in source) {
      final score = DriveScoreStorageService.get(driveId: drive.id);
      if (score != null) scores.add(score);
    }
    final totalDistance = source.fold<double>(0, (sum, d) => sum + d.distance);
    final totalDuration = source.fold<int>(
      0,
      (sum, d) => sum + d.durationSeconds,
    );
    final totalMovingSeconds = source.fold<int>(
      0,
      (sum, d) => sum +
          (d.durationSeconds - d.stoppedSeconds < 0
              ? 0
              : d.durationSeconds - d.stoppedSeconds),
    );
    final maxSpeedDrive = source.reduce((a, b) => a.maxSpeed >= b.maxSpeed ? a : b);
    final longestDrive = source.reduce((a, b) => a.distance >= b.distance ? a : b);
    final longestDurationDrive = source.reduce(
      (a, b) => a.durationSeconds >= b.durationSeconds ? a : b,
    );
    final bestScore = scores.isEmpty
        ? null
        : scores.reduce((a, b) => a.totalScore >= b.totalScore ? a : b);
    final averageScore = scores.isEmpty
        ? null
        : scores.fold<double>(0, (sum, s) => sum + s.totalScore) / scores.length;
    final latestScores = [...scores]
      ..sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    final recent = latestScores.take(5).toList();
    final recentAverage = recent.isEmpty
        ? null
        : recent.fold<double>(0, (sum, s) => sum + s.totalScore) / recent.length;
    final maxGDrive = source.reduce(
      (a, b) => a.maxAccelerationG >= b.maxAccelerationG ? a : b,
    );
    final strongestBrakeDrive = source.reduce(
      (a, b) => a.maxBrakingG >= b.maxBrakingG ? a : b,
    );
    final bestZeroToHundred = source
        .where((d) => d.bestZeroToHundredSeconds != null && d.bestZeroToHundredSeconds! > 0)
        .fold<DriveSession?>(null, (best, d) {
          if (best == null || d.bestZeroToHundredSeconds! < best.bestZeroToHundredSeconds!) return d;
          return best;
        });
    return CareerStatistics(
      drives: source,
      scoredDriveCount: scores.length,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      totalMovingSeconds: totalMovingSeconds,
      averageDistanceMeters: totalDistance / source.length,
      averageDurationSeconds: totalDuration / source.length,
      maxSpeedDrive: maxSpeedDrive,
      longestDrive: longestDrive,
      longestDurationDrive: longestDurationDrive,
      bestScore: bestScore,
      averageScore: averageScore,
      recentAverageScore: recentAverage,
      maxAccelerationDrive: maxGDrive,
      strongestBrakingDrive: strongestBrakeDrive,
      bestZeroToHundredDrive: bestZeroToHundred,
      totalStops: source.fold<int>(0, (sum, d) => sum + d.stopCount),
      totalBrakingEvents: source.fold<int>(0, (sum, d) => sum + d.hardBrakeCount),
      totalCorners: source.fold<int>(0, (sum, d) => sum + d.cornerCount),
      lifetimeAverageSpeedKmh: totalMovingSeconds <= 0
          ? 0
          : totalDistance / 1000 / (totalMovingSeconds / 3600),
    );
  }
}

class CareerStatistics {
  final List<DriveSession> drives;
  final int scoredDriveCount, totalStops, totalBrakingEvents, totalCorners;
  final double totalDistanceMeters, averageDistanceMeters, averageDurationSeconds;
  final int totalDurationSeconds, totalMovingSeconds;
  final double lifetimeAverageSpeedKmh;
  final DriveSession? maxSpeedDrive, longestDrive, longestDurationDrive;
  final DriveSession? maxAccelerationDrive, strongestBrakingDrive, bestZeroToHundredDrive;
  final DriveScoreRecord? bestScore;
  final double? averageScore, recentAverageScore;

  const CareerStatistics({
    required this.drives,
    required this.scoredDriveCount,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.totalMovingSeconds,
    required this.averageDistanceMeters,
    required this.averageDurationSeconds,
    required this.maxSpeedDrive,
    required this.longestDrive,
    required this.longestDurationDrive,
    required this.bestScore,
    required this.averageScore,
    required this.recentAverageScore,
    required this.maxAccelerationDrive,
    required this.strongestBrakingDrive,
    required this.bestZeroToHundredDrive,
    required this.totalStops,
    required this.totalBrakingEvents,
    required this.totalCorners,
    required this.lifetimeAverageSpeedKmh,
  });

  const CareerStatistics.empty()
      : drives = const [],
        scoredDriveCount = 0,
        totalStops = 0,
        totalBrakingEvents = 0,
        totalCorners = 0,
        totalDistanceMeters = 0,
        totalDurationSeconds = 0,
        totalMovingSeconds = 0,
        averageDistanceMeters = 0,
        averageDurationSeconds = 0,
        lifetimeAverageSpeedKmh = 0,
        maxSpeedDrive = null,
        longestDrive = null,
        longestDurationDrive = null,
        maxAccelerationDrive = null,
        strongestBrakingDrive = null,
        bestZeroToHundredDrive = null,
        bestScore = null,
        averageScore = null,
        recentAverageScore = null;
}
