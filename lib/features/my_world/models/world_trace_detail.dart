import '../../../models/drive_score_record.dart';
import '../../../models/drive_session.dart';

class WorldTraceDetail {
  const WorldTraceDetail({
    required this.drive,
    required this.score,
    required this.activeWorldDistanceMeters,
  });

  final DriveSession drive;
  final DriveScoreRecord? score;
  final double activeWorldDistanceMeters;
}
