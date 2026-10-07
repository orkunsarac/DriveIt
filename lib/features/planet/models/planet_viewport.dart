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
  double get longitudeSpan => (east - west + 360) % 360;
  bool get canFetch =>
      zoom >= 10 &&
      north - south <= 1 &&
      longitudeSpan > 0 &&
      longitudeSpan <= 1;
  bool contains(PlanetViewport other) {
    final offset = (other.west - west + 360) % 360;
    return south <= other.south &&
        north >= other.north &&
        offset + other.longitudeSpan <= longitudeSpan + 1e-10;
  }

  /// 20% each side, bounded by the unchanged server one-degree guard.
  PlanetViewport buffered() {
    final latMargin = ((north - south) * .2).clamp(
      0.0,
      (1 - (north - south)) / 2,
    );
    final lonMargin = (longitudeSpan * .2).clamp(0.0, (1 - longitudeSpan) / 2);
    double wrap(double longitude) => (longitude + 180) % 360 - 180;
    return PlanetViewport(
      (south - latMargin).clamp(-85.0, 85.0),
      (north + latMargin).clamp(-85.0, 85.0),
      wrap(west - lonMargin),
      wrap(east + lonMargin),
      zoom,
    );
  }
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
