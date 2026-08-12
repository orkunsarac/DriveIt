import '../../../models/canonical_telemetry_point.dart';

enum DrivingPhase {
  unknown,
  stopped,
  accelerating,
  cruising,
  decelerating,
  cornering,
}

enum TrafficRegime { unknown, freeFlow, denseTraffic, stopAndGo }

enum DrivingEventType { stop, acceleration, deceleration, corner, cruise }

/// The domain that may later interpret an event. This is attribution metadata,
/// not a score or penalty decision.
enum EventOwnerDomain { stopping, acceleration, braking, cornering, cruising }

enum EventContextTag {
  stopped,
  accelerating,
  cruising,
  decelerating,
  cornering,
  freeFlow,
  denseTraffic,
  stopAndGo,
}

class TelemetryFeature {
  final int index;
  final CanonicalTelemetryPoint point;
  final double rollingMeanSpeedMps;
  final double rollingSpeedVariance;
  final double smoothedAccelerationMps2;
  final double headingDeltaDegrees;
  final double headingChangeRateDegreesPerSecond;
  final double rollingLowSpeedRatio;
  final double stationaryDurationSeconds;
  final double movingDurationSeconds;

  const TelemetryFeature({
    required this.index,
    required this.point,
    required this.rollingMeanSpeedMps,
    required this.rollingSpeedVariance,
    required this.smoothedAccelerationMps2,
    required this.headingDeltaDegrees,
    required this.headingChangeRateDegreesPerSecond,
    required this.rollingLowSpeedRatio,
    required this.stationaryDurationSeconds,
    required this.movingDurationSeconds,
  });
}

class TrafficContext {
  final TrafficRegime regime;
  final double confidence;
  final double denseTrafficConfidence;
  final double stopAndGoConfidence;

  const TrafficContext({
    required this.regime,
    required this.confidence,
    required this.denseTrafficConfidence,
    required this.stopAndGoConfidence,
  });

  static const unknown = TrafficContext(
    regime: TrafficRegime.unknown,
    confidence: 0,
    denseTrafficConfidence: 0,
    stopAndGoConfidence: 0,
  );
}

class DrivingPhaseInterval {
  final DrivingPhase phase;
  final int startIndex;
  final int endIndex;
  final DateTime startTime;
  final DateTime endTime;

  const DrivingPhaseInterval({
    required this.phase,
    required this.startIndex,
    required this.endIndex,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration => endTime.difference(startTime);
}

class DrivingEvent {
  final String id;
  final String driveSessionId;
  final DrivingEventType type;
  final int startIndex;
  final int endIndex;
  final DateTime startTime;
  final DateTime endTime;
  final double startSpeedMps;
  final double endSpeedMps;
  final double maximumSpeedMps;
  final double minimumSpeedMps;
  final double distanceMeters;
  final double confidence;
  final TrafficContext trafficContext;
  final EventOwnerDomain primaryOwner;
  final Set<EventOwnerDomain> ownershipEligibility;
  final Set<EventContextTag> contextTags;
  final List<String> overlappingEventIds;
  final Map<String, double> metadata;

  const DrivingEvent({
    required this.id,
    required this.driveSessionId,
    required this.type,
    required this.startIndex,
    required this.endIndex,
    required this.startTime,
    required this.endTime,
    required this.startSpeedMps,
    required this.endSpeedMps,
    required this.maximumSpeedMps,
    required this.minimumSpeedMps,
    required this.distanceMeters,
    required this.confidence,
    required this.trafficContext,
    required this.primaryOwner,
    required this.ownershipEligibility,
    required this.contextTags,
    this.overlappingEventIds = const <String>[],
    this.metadata = const <String, double>{},
  });

  Duration get duration => endTime.difference(startTime);

  DrivingEvent copyWith({
    Set<EventContextTag>? contextTags,
    List<String>? overlappingEventIds,
  }) {
    return DrivingEvent(
      id: id,
      driveSessionId: driveSessionId,
      type: type,
      startIndex: startIndex,
      endIndex: endIndex,
      startTime: startTime,
      endTime: endTime,
      startSpeedMps: startSpeedMps,
      endSpeedMps: endSpeedMps,
      maximumSpeedMps: maximumSpeedMps,
      minimumSpeedMps: minimumSpeedMps,
      distanceMeters: distanceMeters,
      confidence: confidence,
      trafficContext: trafficContext,
      primaryOwner: primaryOwner,
      ownershipEligibility: ownershipEligibility,
      contextTags: contextTags ?? this.contextTags,
      overlappingEventIds: overlappingEventIds ?? this.overlappingEventIds,
      metadata: metadata,
    );
  }
}

class DrivePhaseAnalysisResult {
  final String driveSessionId;
  final List<TelemetryFeature> features;
  final List<DrivingPhaseInterval> phaseTimeline;
  final List<DrivingPhaseInterval> corneringTimeline;
  final List<TrafficContext> trafficTimeline;
  final List<DrivingEvent> events;

  const DrivePhaseAnalysisResult({
    required this.driveSessionId,
    required this.features,
    required this.phaseTimeline,
    required this.corneringTimeline,
    required this.trafficTimeline,
    required this.events,
  });

  Iterable<DrivingEvent> eventsOfType(DrivingEventType type) =>
      events.where((event) => event.type == type);
}
