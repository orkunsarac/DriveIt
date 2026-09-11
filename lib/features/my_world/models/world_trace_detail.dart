import '../../../models/drive_score_record.dart';
import '../../../models/drive_session.dart';

class WorldTraceDetail {
  const WorldTraceDetail({
    required this.drive,
    required this.score,
    required this.activeWorldDistanceMeters,
    this.worldTraceScore,
    this.traceDistanceMeters,
    this.traceStart,
    this.traceEnd,
    this.traceDurationSeconds,
    this.traceAverageSpeed,
    this.traceMaxSpeed,
    this.travelDirection,
  });

  final DriveSession drive;
  final DriveScoreRecord? score;
  final double activeWorldDistanceMeters;
  final double? worldTraceScore;
  final double? traceDistanceMeters;
  final String? traceStart;
  final String? traceEnd;
  final int? traceDurationSeconds;
  final double? traceAverageSpeed;
  final double? traceMaxSpeed;
  final String? travelDirection;
}
