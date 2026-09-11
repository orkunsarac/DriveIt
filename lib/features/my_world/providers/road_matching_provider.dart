import '../../../models/route_point.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/validated_road.dart';

class RoadMatchingRequest {
  final String driveSessionId;
  final List<RoutePoint> rawRoute;
  final int processingVersion;
  final List<CanonicalTelemetryPoint> canonicalTelemetry;

  const RoadMatchingRequest({
    required this.driveSessionId,
    required this.rawRoute,
    required this.processingVersion,
    this.canonicalTelemetry = const [],
  });
}

class RoadMatchingResult {
  final List<MatchedRoadSection> sections;
  final List<MatchedRoadPoint> geometry;
  final double validDistanceMeters;
  final RoadValidationStatus status;
  final double? confidence;
  final String directionKey;
  final double? averageHeadingDegrees;
  final RoadMatchingFailureKind failureKind;
  final String? errorMessage;

  const RoadMatchingResult({
    required this.sections,
    required this.geometry,
    required this.validDistanceMeters,
    required this.status,
    required this.confidence,
    required this.directionKey,
    required this.averageHeadingDegrees,
    this.failureKind = RoadMatchingFailureKind.none,
    required this.errorMessage,
  });

  bool get hasUsableGeometry =>
      sections.isNotEmpty &&
      (status == RoadValidationStatus.validated ||
          status == RoadValidationStatus.partiallyValidated);

  bool get hasRetryableFailure => failureKind.isRetryable;

  factory RoadMatchingResult.failure({
    required RoadMatchingFailureKind kind,
    required String message,
  }) => RoadMatchingResult(
    sections: const [],
    geometry: const [],
    validDistanceMeters: 0,
    status: RoadValidationStatus.failed,
    confidence: null,
    directionKey: '',
    averageHeadingDegrees: null,
    failureKind: kind,
    errorMessage: message,
  );
}

enum RoadMatchingFailureKind {
  none,
  missingAccessToken,
  insufficientInput,
  invalidInput,
  network,
  timeout,
  authentication,
  rateLimited,
  server,
  malformedResponse,
  apiError,
}

extension RoadMatchingFailureKindBehavior on RoadMatchingFailureKind {
  bool get isRetryable =>
      this == RoadMatchingFailureKind.missingAccessToken ||
      this == RoadMatchingFailureKind.network ||
      this == RoadMatchingFailureKind.timeout ||
      this == RoadMatchingFailureKind.rateLimited ||
      this == RoadMatchingFailureKind.server;
}

abstract interface class RoadMatchingProvider {
  String get providerId;

  Future<RoadMatchingResult> match(RoadMatchingRequest request);
}
