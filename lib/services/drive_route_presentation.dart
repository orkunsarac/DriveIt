import '../models/route_point.dart';

/// Single-drive, read-only presentation. Never passed to matching or storage.
class DriveRoutePresentation {
  DriveRoutePresentation(List<RoutePoint> route) {
    final parts = routeSegments(route);
    for (var i = 1; i < parts.length; i++) {
      final before = parts[i - 1], after = parts[i];
      // Isolated fixes do not establish reliable segments. Do not search past
      // invalid endpoints or bridge another segment to manufacture continuity.
      if (before.length < 2 || after.length < 2) continue;
      final a = before.last, b = after.first;
      if (!b.breakBefore || !_valid(a) || !_valid(b)) continue;
      if (a.latitude == b.latitude && a.longitude == b.longitude) continue;
      gaps.add(List.unmodifiable([a, b]));
    }
  }

  final List<List<RoutePoint>> gaps = [];

  static bool _valid(RoutePoint p) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude >= -90 &&
      p.latitude <= 90 &&
      p.longitude >= -180 &&
      p.longitude <= 180 &&
      !(p.latitude == 0 && p.longitude == 0);
}
