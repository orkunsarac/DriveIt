import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlanetViewport {
  const PlanetViewport(this.south, this.north, this.west, this.east, this.zoom);
  final double south, north, west, east, zoom;
  Map<String, dynamic> get params => {
    'p_south': south,
    'p_north': north,
    'p_west': west,
    'p_east': east,
    'p_zoom': zoom,
  };
  String get key => '$south:$north:$west:$east:$zoom';
}

class PlanetTrace {
  PlanetTrace(this.id, this.styleKey, this.distanceMeters, List<LatLng> points)
    : geometry = List.unmodifiable(points);
  final String id, styleKey;
  final double distanceMeters;
  final List<LatLng> geometry;
}

class PlanetSnapshot {
  const PlanetSnapshot(this.generation, this.zoomIn, this.traces);
  final BigInt generation;
  final bool zoomIn;
  final List<PlanetTrace> traces;
  factory PlanetSnapshot.parse(Object? response) {
    final value = response as Map<String, dynamic>;
    final generation = BigInt.parse(value['generation'] as String);
    if (generation < BigInt.zero ||
        !['ready', 'zoom_in'].contains(value['state'])) {
      throw const FormatException('Invalid map response');
    }
    final ids = <String>{};
    final traces = (value['traces'] as List).map((raw) {
      final t = raw as Map<String, dynamic>;
      final id = t['id'] as String;
      if (!ids.add(id)) throw const FormatException('Duplicate map trace');
      final geo = t['geometry'] as Map<String, dynamic>;
      if (geo['type'] != 'LineString') {
        throw const FormatException('Invalid map geometry');
      }
      final points = (geo['coordinates'] as List).map((p) {
        final pair = p as List;
        final lon = (pair[0] as num).toDouble(),
            lat = (pair[1] as num).toDouble();
        if (!lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180) {
          throw const FormatException('Invalid map point');
        }
        return LatLng(lat, lon);
      }).toList();
      final distance = double.parse(t['distance_meters'] as String);
      if (points.length < 2 || !distance.isFinite || distance <= 0) {
        throw const FormatException('Invalid map span');
      }
      return PlanetTrace(id, t['style_key'] as String, distance, points);
    }).toList();
    if (traces.length > 200) throw const FormatException('Map response limit');
    return PlanetSnapshot(
      generation,
      value['state'] == 'zoom_in',
      List.unmodifiable(traces),
    );
  }
}
