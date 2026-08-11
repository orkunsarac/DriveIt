import 'package:hive/hive.dart';
import 'route_point.dart';

part 'drive_session.g.dart';

@HiveType(typeId: 0)
class DriveSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double distance;

  @HiveField(3)
  int durationSeconds;

  @HiveField(4)
  double averageSpeed;

  @HiveField(5)
  double maxSpeed;

  @HiveField(6)
  String mapImagePath;

  @HiveField(7)
  List<RoutePoint> route;

  // Hive fields 8-11 are reserved for removed Flow Analysis data.
  @HiveField(12)
  int stopCount;

  @HiveField(13)
  int stoppedSeconds;

  // 8-11 remain reserved for the removed Flow Analysis fields.
  @HiveField(14)
  int hardBrakeCount;

  @HiveField(15)
  int hardAccelerationCount;

  @HiveField(16)
  int sharpTurnCount;

  @HiveField(17)
  double maxAccelerationG;

  @HiveField(18)
  double maxBrakingG;

  @HiveField(19)
  double maxCorneringSpeed;

  @HiveField(20)
  int cornerCount;

  @HiveField(21)
  double maxAltitude;

  @HiveField(22)
  double altitudeGain;

  @HiveField(23)
  double? bestZeroToHundredSeconds;

  @HiveField(24)
  double? bestSixtyToHundredSeconds;

  @HiveField(25)
  double? altitudeLoss;

  /// Average speed while moving, excluding recorded stop time.
  /// Distance is stored in metres and duration values in seconds.
  double get drivingAverageSpeed {
    final movingSeconds = durationSeconds - stoppedSeconds;
    if (distance <= 0 || movingSeconds <= 0) return 0;
    return (distance / 1000) / (movingSeconds / 3600);
  }

  DriveSession({
    required this.id,
    required this.date,
    required this.distance,
    required this.durationSeconds,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.mapImagePath,
    required this.route,
    this.stopCount = 0,
    this.stoppedSeconds = 0,
    this.hardBrakeCount = 0,
    this.hardAccelerationCount = 0,
    this.sharpTurnCount = 0,
    this.maxAccelerationG = 0,
    this.maxBrakingG = 0,
    this.maxCorneringSpeed = 0,
    this.cornerCount = 0,
    this.maxAltitude = 0,
    this.altitudeGain = 0,
    this.bestZeroToHundredSeconds,
    this.bestSixtyToHundredSeconds,
    this.altitudeLoss,
  });
}
