import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../my_world/services/world_trace_presentation_service.dart';
import '../../my_world/services/world_trace_visibility_policy.dart';
import '../models/planet_viewport.dart';

class PlanetMapDrawing {
  const PlanetMapDrawing(this.polylines, this.circles);
  final Set<Polyline> polylines;
  final Set<Circle> circles;
}

class PlanetMapPresentation {
  static const palette = [
    Color(0xff53d7ff),
    Color(0xff3b93ff),
    Color(0xffff5577),
    Color(0xff45e08a),
    Color(0xffffa43a),
    Color(0xffb477ff),
    Color(0xffffd34d),
    Color(0xffff62c8),
  ];
  static const presentation = WorldTracePresentationService();
  static const visibility = WorldTraceVisibilityPolicy();
  static PlanetMapDrawing draw(PlanetSnapshot snapshot, double zoom) {
    final partners = <String, PlanetTrace>{};
    final traces = snapshot.traces;
    for (var i = 0; i < traces.length; i++) {
      for (var j = i + 1; j < traces.length; j++) {
        if (presentation.oppositeGeometry(
          traces[i].geometry,
          traces[j].geometry,
        )) {
          partners[traces[i].id] = traces[j];
          partners[traces[j].id] = traces[i];
        }
      }
    }
    final lines = <Polyline>{}, circles = <Circle>{};
    for (final trace in traces) {
      if (!visibility.isVisible(
        distanceMeters: trace.distanceMeters,
        zoom: zoom,
      )) {
        continue;
      }
      final partner = partners[trace.id];
      final points = presentation.renderPoints(
        id: trace.id,
        points: trace.geometry,
        separateOpposite: partner != null,
        zoom: zoom,
        partnerId: partner?.id,
        partnerPoints: partner?.geometry,
      );
      final variant =
          trace.styleKey.codeUnits.fold<int>(0, (sum, c) => sum * 31 + c) &
          0x7fffffff;
      final color = palette[variant % palette.length];
      lines.add(
        Polyline(
          polylineId: PolylineId('planet_glow:${trace.id}'),
          points: points,
          color: color.withAlpha(55),
          width: 3,
          zIndex: 1,
          geodesic: true,
        ),
      );
      lines.add(
        Polyline(
          polylineId: PolylineId('planet_core:${trace.id}'),
          points: points,
          color: color,
          width: 2,
          zIndex: 2,
          geodesic: true,
        ),
      );
      if (visibility.areMarkersVisible(zoom)) {
        final radius = visibility.markerRadiusMeters(
          zoom: zoom,
          selected: false,
        );
        circles.add(
          Circle(
            circleId: CircleId('planet_start:${trace.id}'),
            center: points.first,
            radius: radius,
            strokeWidth: 1,
            strokeColor: color,
            fillColor: Colors.transparent,
            zIndex: 3,
          ),
        );
        circles.add(
          Circle(
            circleId: CircleId('planet_end:${trace.id}'),
            center: points.last,
            radius: radius,
            strokeWidth: 1,
            strokeColor: color,
            fillColor: color.withAlpha(150),
            zIndex: 3,
          ),
        );
      }
    }
    return PlanetMapDrawing(Set.unmodifiable(lines), Set.unmodifiable(circles));
  }
}
