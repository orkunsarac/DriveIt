import '../models/canonical_telemetry_point.dart';
import '../models/route_point.dart';
import 'drive_time_analysis.dart';

/// Read-only projection for new summaries/transfers. Original telemetry and
/// historical Hive geometry remain untouched. No interpolation or rematching.
class DriveRouteProjection {
  DriveRouteProjection(List<CanonicalTelemetryPoint> points) {
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final boundary =
          i > 0 && !DriveTimeAnalysis.reliableInterval(points[i - 1], p);
      if (route.isEmpty || boundary || p.distanceFromPreviousMeters > 0) {
        route.add(
          RoutePoint(
            latitude: p.latitude,
            longitude: p.longitude,
            breakBefore: route.isNotEmpty && boundary,
          ),
        );
        if (i > 0 && !boundary) distanceMeters += p.distanceFromPreviousMeters;
      }
    }
  }
  final List<RoutePoint> route = [];
  double distanceMeters = 0;
  List<Map<String, dynamic>> get encodedRoute => route
      .map(
        (p) => {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'breakBefore': p.breakBefore,
        },
      )
      .toList();
}
