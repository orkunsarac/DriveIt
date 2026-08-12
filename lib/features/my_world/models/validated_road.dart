import 'matched_road_point.dart';
import 'matched_road_section.dart';

enum RoadValidationStatus {
  pending,
  validated,
  partiallyValidated,
  rejected,
  failed,
}

class ValidatedRoad {
  final String id;
  final String driveSessionId;

  /// Flattened compatibility view. [sections] is the canonical representation
  /// whenever validation contains disconnected road pieces.
  final List<MatchedRoadPoint> geometry;
  final List<MatchedRoadSection> sections;
  final double validDistanceMeters;
  final RoadValidationStatus status;
  final DateTime? validatedAt;
  final String providerId;
  final double? confidence;
  final int processingVersion;
  final bool requiresRetry;

  /// Stable provider/canonical-road direction identifier. Geometry is always
  /// stored in travel order, so opposite travel must receive a different key.
  final String directionKey;
  final double? averageHeadingDegrees;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ValidatedRoad({
    required this.id,
    required this.driveSessionId,
    required this.geometry,
    this.sections = const [],
    required this.validDistanceMeters,
    required this.status,
    required this.validatedAt,
    required this.providerId,
    required this.confidence,
    required this.processingVersion,
    this.requiresRetry = false,
    required this.directionKey,
    required this.averageHeadingDegrees,
    required this.createdAt,
    required this.updatedAt,
  });
}
