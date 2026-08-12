import 'dart:math' as math;

class GeoDistance {
  const GeoDistance._();

  static const double _earthRadiusMeters = 6371008.8;

  static double between(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    final lat1 = _radians(latitudeA);
    final lat2 = _radians(latitudeB);
    final deltaLat = _radians(latitudeB - latitudeA);
    final deltaLon = _radians(longitudeB - longitudeA);
    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);
    final haversine =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    return 2 * _earthRadiusMeters * math.asin(math.sqrt(haversine.clamp(0, 1)));
  }

  static double bearing(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    final lat1 = _radians(latitudeA);
    final lat2 = _radians(latitudeB);
    final deltaLon = _radians(longitudeB - longitudeA);
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    return (_degrees(math.atan2(y, x)) + 360) % 360;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
  static double _degrees(double radians) => radians * 180 / math.pi;
}
