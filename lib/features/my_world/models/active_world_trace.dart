/// A currently visible ownership span in Benim Dunyam.
///
/// Geometry deliberately remains in [ValidatedRoad]/[MatchedRoadSection]. This
/// record stores only a stable reference and the physical interval to draw.
class ActiveWorldTrace {
  const ActiveWorldTrace({
    required this.id,
    required this.sourceDriveSessionId,
    required this.validatedRoadId,
    required this.matchedSectionId,
    required this.startOffsetMeters,
    required this.endOffsetMeters,
    required this.directionKey,
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
    required this.createdAt,
    required this.updatedAt,
    required this.processingVersion,
  });

  final String id;
  final String sourceDriveSessionId;
  final String validatedRoadId;
  final String matchedSectionId;
  final double startOffsetMeters;
  final double endOffsetMeters;
  final String directionKey;
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int processingVersion;

  double get distanceMeters => endOffsetMeters - startOffsetMeters;

  ActiveWorldTrace copyWith({
    String? id,
    double? startOffsetMeters,
    double? endOffsetMeters,
    DateTime? updatedAt,
  }) => ActiveWorldTrace(
    id: id ?? this.id,
    sourceDriveSessionId: sourceDriveSessionId,
    validatedRoadId: validatedRoadId,
    matchedSectionId: matchedSectionId,
    startOffsetMeters: startOffsetMeters ?? this.startOffsetMeters,
    endOffsetMeters: endOffsetMeters ?? this.endOffsetMeters,
    directionKey: directionKey,
    minLatitude: minLatitude,
    maxLatitude: maxLatitude,
    minLongitude: minLongitude,
    maxLongitude: maxLongitude,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    processingVersion: processingVersion,
  );

  bool intersectsBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) =>
      this.minLatitude <= maxLatitude &&
      this.maxLatitude >= minLatitude &&
      this.minLongitude <= maxLongitude &&
      this.maxLongitude >= minLongitude;
}
