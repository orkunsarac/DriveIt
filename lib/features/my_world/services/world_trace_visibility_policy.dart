/// Presentation-only visibility and marker sizing rules for active traces.
class WorldTraceVisibilityPolicy {
  const WorldTraceVisibilityPolicy();

  bool isVisible({required double distanceMeters, required double zoom}) {
    if (zoom >= 13) return true;
    if (zoom >= 11) return distanceMeters >= 300;
    if (zoom >= 8) return distanceMeters >= 1000;
    if (zoom >= 6) return distanceMeters >= 2500;
    return distanceMeters >= 5000;
  }

  bool areMarkersVisible(double zoom) => zoom >= 6;

  double markerRadiusMeters({required double zoom, required bool selected}) {
    final minimum = selected ? 2.5 : 2.0;
    final maximum = selected ? 8.0 : 5.5;
    return (10 - zoom * .45).clamp(minimum, maximum);
  }
}
