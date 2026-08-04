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

  @HiveField(8)
double flowScore;

@HiveField(9)
double cruiseSpeed;

@HiveField(10)
double stability;

  @HiveField(11)
  int oscillation;

  @HiveField(12)
  int stopCount;

  @HiveField(13)
  int stoppedSeconds;

  DriveSession({
    required this.id,
    required this.date,
    required this.distance,
    required this.durationSeconds,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.mapImagePath,
    required this.route,
    required this.flowScore,
    required this.cruiseSpeed,
    required this.stability,
    required this.oscillation,
    this.stopCount = 0,
    this.stoppedSeconds = 0,
  });
}
