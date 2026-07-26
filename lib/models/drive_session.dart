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

  DriveSession({
    required this.id,
    required this.date,
    required this.distance,
    required this.durationSeconds,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.mapImagePath,
    required this.route,
  });
}