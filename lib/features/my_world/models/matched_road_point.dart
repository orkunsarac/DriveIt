class MatchedRoadPoint {
  final double latitude;
  final double longitude;
  final double? headingDegrees;
  final String? providerRoadReference;
  final double? confidence;

  const MatchedRoadPoint({
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.providerRoadReference,
    this.confidence,
  });
}
