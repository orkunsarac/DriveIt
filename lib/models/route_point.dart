import 'package:hive/hive.dart';

part 'route_point.g.dart';

@HiveType(typeId: 1)
class RoutePoint extends HiveObject {
  @HiveField(0)
  double latitude;

  @HiveField(1)
  double longitude;
  // Field 2 is reserved: deployed legacy records contain a DateTime there.
  @HiveField(254)
  bool breakBefore;

  // Preserve fields from older writers without guessing their semantics.
  final Map<int, dynamic> legacyHiveFields;

  RoutePoint({
    required this.latitude,
    required this.longitude,
    this.breakBefore = false,
    Map<int, dynamic>? legacyHiveFields,
  }) : legacyHiveFields = Map.unmodifiable(legacyHiveFields ?? {});
}

List<List<RoutePoint>> routeSegments(List<RoutePoint> route) {
  final result = <List<RoutePoint>>[];
  for (final point in route) {
    if (result.isEmpty || point.breakBefore) result.add(<RoutePoint>[]);
    result.last.add(point);
  }
  return result;
}
