import 'matched_road_point.dart';

/// One continuous road geometry returned by the matching provider.
///
/// Separate sections must never be joined with an artificial straight line.
class MatchedRoadSection {
  final String id;
  final List<MatchedRoadPoint> geometry;
  final double distanceMeters;
  final double? confidence;
  final int sourceTraceIndex;
  final int sourceChunkIndex;

  const MatchedRoadSection({
    required this.id,
    required this.geometry,
    required this.distanceMeters,
    required this.confidence,
    required this.sourceTraceIndex,
    required this.sourceChunkIndex,
  });
}
