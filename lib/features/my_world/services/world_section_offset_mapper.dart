import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import 'geo_distance.dart';

/// Maps geometry-derived distances into one canonical section-offset space.
class WorldSectionOffsetMapper {
  const WorldSectionOffsetMapper._();

  static double sectionLength(MatchedRoadSection section) {
    final declared = section.distanceMeters;
    final measured = geometryLength(section.geometry);
    // Declared provider distance is the canonical ownership coordinate. All
    // geometry-derived offsets are normalized into this same range.
    return declared.isFinite && declared > 0 ? declared : measured;
  }

  static double geometryLength(List<MatchedRoadPoint> geometry) {
    var total = 0.0;
    for (var i = 0; i < geometry.length - 1; i++) {
      final distance = GeoDistance.between(
        geometry[i].latitude,
        geometry[i].longitude,
        geometry[i + 1].latitude,
        geometry[i + 1].longitude,
      );
      if (distance.isFinite && distance > 0) total += distance;
    }
    return total;
  }

  static double normalize({
    required double geometryOffsetMeters,
    required double geometryLengthMeters,
    required double sectionLengthMeters,
  }) {
    if (!geometryOffsetMeters.isFinite ||
        !geometryLengthMeters.isFinite ||
        !sectionLengthMeters.isFinite ||
        geometryLengthMeters <= 0 ||
        sectionLengthMeters <= 0) {
      return 0;
    }
    final ratio = (geometryOffsetMeters / geometryLengthMeters).clamp(0.0, 1.0);
    return (ratio * sectionLengthMeters).clamp(0.0, sectionLengthMeters);
  }
}
