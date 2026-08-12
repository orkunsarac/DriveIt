import '../../../models/drive_session.dart';
import '../config/my_world_rules.dart';
import '../models/validated_road.dart';
import '../providers/road_matching_provider.dart';

class RoadValidationOutcome {
  final ValidatedRoad? road;
  final RoadMatchingFailureKind failureKind;
  final String? errorMessage;

  const RoadValidationOutcome({
    required this.road,
    required this.failureKind,
    required this.errorMessage,
  });

  bool get isRetryable => failureKind.isRetryable;
}

class RoadMatchingService {
  final RoadMatchingProvider provider;
  final DateTime Function() _clock;

  RoadMatchingService({required this.provider, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  Future<RoadValidationOutcome> validate(DriveSession drive) async {
    final version = MyWorldRules.validatedRoadProcessingVersion;
    final result = await provider.match(
      RoadMatchingRequest(
        driveSessionId: drive.id,
        rawRoute: List.unmodifiable(drive.route),
        processingVersion: version,
      ),
    );
    if (!result.hasUsableGeometry) {
      return RoadValidationOutcome(
        road: null,
        failureKind: result.failureKind,
        errorMessage: result.errorMessage,
      );
    }
    final now = _clock();
    final confidence = result.confidence;
    return RoadValidationOutcome(
      road: ValidatedRoad(
        id: '${drive.id}:${provider.providerId}:v$version',
        driveSessionId: drive.id,
        geometry: List.unmodifiable(result.geometry),
        sections: List.unmodifiable(result.sections),
        validDistanceMeters: result.validDistanceMeters,
        status: result.status,
        validatedAt: now,
        providerId: provider.providerId,
        confidence: confidence?.clamp(0, 1),
        processingVersion: version,
        requiresRetry: result.hasRetryableFailure,
        directionKey: result.directionKey,
        averageHeadingDegrees: result.averageHeadingDegrees,
        createdAt: now,
        updatedAt: now,
      ),
      failureKind: result.failureKind,
      errorMessage: result.errorMessage,
    );
  }
}
