import 'package:hive/hive.dart';

part 'route_point.g.dart';

@HiveType(typeId: 1)
class RoutePoint extends HiveObject {
  @HiveField(0)
  double latitude;

  @HiveField(1)
  double longitude;

  RoutePoint({
    required this.latitude,
    required this.longitude,
  });
}