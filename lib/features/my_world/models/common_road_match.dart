import 'matched_road_point.dart';

/// One continuous, same-direction geometric overlap between two validated
/// road sections. Offsets are metres from the start of each validated road.
class CommonRoadMatch {
  const CommonRoadMatch({
    required this.firstDriveId,
    required this.secondDriveId,
    required this.firstSectionId,
    required this.secondSectionId,
    required this.firstStartOffsetMeters,
    required this.firstEndOffsetMeters,
    required this.secondStartOffsetMeters,
    required this.secondEndOffsetMeters,
    required this.commonStart,
    required this.commonEnd,
    required this.commonDistanceMeters,
    required this.directionCompatible,
    required this.geometryConfidence,
    required this.comparisonEligible,
    this.ownershipCovered = true,
    required this.referenceGeometry,
  });

  final String firstDriveId;
  final String secondDriveId;
  final String firstSectionId;
  final String secondSectionId;
  final double firstStartOffsetMeters;
  final double firstEndOffsetMeters;
  final double secondStartOffsetMeters;
  final double secondEndOffsetMeters;
  final MatchedRoadPoint commonStart;
  final MatchedRoadPoint commonEnd;
  final double commonDistanceMeters;
  final bool directionCompatible;
  final double geometryConfidence;
  final bool comparisonEligible;

  /// True when the geometry and travel direction are sufficiently certain
  /// for World ownership suppression. This is intentionally independent from
  /// [comparisonEligible], which is gated by the 3 km local-score threshold.
  final bool ownershipCovered;
  final List<MatchedRoadPoint> referenceGeometry;
}
