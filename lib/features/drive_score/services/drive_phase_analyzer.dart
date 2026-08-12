import 'dart:math' as math;

import '../../../models/canonical_telemetry_point.dart';
import '../config/drive_detection_calibration.dart';
import '../models/driving_analysis_models.dart';
import 'drive_feature_extractor.dart';

/// Deterministic, score-free interpretation of a canonical drive timeline.
class DrivePhaseAnalyzer {
  final DriveFeatureExtractor featureExtractor;

  const DrivePhaseAnalyzer({
    this.featureExtractor = const DriveFeatureExtractor(),
  });

  DrivePhaseAnalysisResult analyze({
    required String driveSessionId,
    required Iterable<CanonicalTelemetryPoint> telemetry,
  }) {
    final points = telemetry.toList(growable: false);
    final features = featureExtractor.extract(points);
    if (features.isEmpty) {
      return DrivePhaseAnalysisResult(
        driveSessionId: driveSessionId,
        features: const [],
        phaseTimeline: const [],
        corneringTimeline: const [],
        trafficTimeline: const [],
        events: const [],
      );
    }

    final traffic = _detectTraffic(features);
    final stopRuns = _detectRuns(
      features,
      enters: (feature) =>
          feature.point.speedMps <= DriveDetectionCalibration.stoppedSpeedMps,
      continues: (feature) =>
          feature.point.speedMps <= DriveDetectionCalibration.stoppedSpeedMps,
      minimumDuration: DriveDetectionCalibration.stoppedMinimumDuration,
      validate: (run) =>
          _distance(features, run.start, run.end) <=
          DriveDetectionCalibration.stoppedMaximumDistanceMeters,
    );
    final accelerationRuns = _detectRuns(
      features,
      enters: (feature) =>
          feature.smoothedAccelerationMps2 >=
          DriveDetectionCalibration.accelerationEnterMps2,
      continues: (feature) =>
          feature.smoothedAccelerationMps2 >=
          DriveDetectionCalibration.accelerationExitMps2,
      minimumDuration: DriveDetectionCalibration.accelerationMinimumDuration,
      validate: (run) =>
          features[run.end].point.speedMps -
              features[run.start].point.speedMps >=
          DriveDetectionCalibration.accelerationMinimumSpeedGainMps,
    );
    final decelerationRuns = _detectRuns(
      features,
      enters: (feature) =>
          feature.smoothedAccelerationMps2 <=
          DriveDetectionCalibration.decelerationEnterMps2,
      continues: (feature) =>
          feature.smoothedAccelerationMps2 <=
          DriveDetectionCalibration.decelerationExitMps2,
      minimumDuration: DriveDetectionCalibration.decelerationMinimumDuration,
      validate: (run) =>
          features[run.start].point.speedMps -
              features[run.end].point.speedMps >=
          DriveDetectionCalibration.decelerationMinimumSpeedLossMps,
    );
    final cruiseRuns = _detectRuns(
      features,
      enters: _isCruiseFeature,
      continues: _isCruiseFeature,
      minimumDuration: DriveDetectionCalibration.cruiseMinimumDuration,
      validate: (_) => true,
    );
    final cornerRuns = _detectRuns(
      features,
      enters: (feature) =>
          feature.point.speedMps >=
              DriveDetectionCalibration.cornerMinimumSpeedMps &&
          feature.headingChangeRateDegreesPerSecond >=
              DriveDetectionCalibration.cornerEnterHeadingRateDegreesPerSecond,
      continues: (feature) =>
          feature.point.speedMps >=
              DriveDetectionCalibration.cornerMinimumSpeedMps &&
          feature.headingChangeRateDegreesPerSecond >=
              DriveDetectionCalibration.cornerExitHeadingRateDegreesPerSecond,
      minimumDuration: DriveDetectionCalibration.cornerMinimumDuration,
      validate: (run) =>
          _headingChange(features, run.start, run.end) >=
              DriveDetectionCalibration.cornerMinimumHeadingChangeDegrees &&
          _distance(features, run.start, run.end) >=
              DriveDetectionCalibration.cornerMinimumDistanceMeters,
    );

    final phases = List<DrivingPhase>.filled(
      features.length,
      DrivingPhase.unknown,
    );
    _paint(phases, cruiseRuns, DrivingPhase.cruising);
    _paint(phases, accelerationRuns, DrivingPhase.accelerating);
    _paint(phases, decelerationRuns, DrivingPhase.decelerating);
    _paint(phases, stopRuns, DrivingPhase.stopped);

    final events =
        <DrivingEvent>[
          ...stopRuns.map(
            (run) => _event(
              driveSessionId,
              DrivingEventType.stop,
              run,
              features,
              traffic,
            ),
          ),
          ...accelerationRuns.map(
            (run) => _event(
              driveSessionId,
              DrivingEventType.acceleration,
              run,
              features,
              traffic,
            ),
          ),
          ...decelerationRuns.map(
            (run) => _event(
              driveSessionId,
              DrivingEventType.deceleration,
              run,
              features,
              traffic,
            ),
          ),
          ...cornerRuns.map(
            (run) => _event(
              driveSessionId,
              DrivingEventType.corner,
              run,
              features,
              traffic,
            ),
          ),
          ...cruiseRuns.map(
            (run) => _event(
              driveSessionId,
              DrivingEventType.cruise,
              run,
              features,
              traffic,
            ),
          ),
        ]..sort((first, second) {
          final startComparison = first.startIndex.compareTo(second.startIndex);
          return startComparison != 0
              ? startComparison
              : first.type.index.compareTo(second.type.index);
        });

    return DrivePhaseAnalysisResult(
      driveSessionId: driveSessionId,
      features: List.unmodifiable(features),
      phaseTimeline: List.unmodifiable(_compressPhases(phases, features)),
      corneringTimeline: List.unmodifiable(
        cornerRuns.map(
          (run) => DrivingPhaseInterval(
            phase: DrivingPhase.cornering,
            startIndex: run.start,
            endIndex: run.end,
            startTime: features[run.start].point.timestamp,
            endTime: features[run.end].point.timestamp,
          ),
        ),
      ),
      trafficTimeline: List.unmodifiable(traffic),
      events: List.unmodifiable(_resolveOwnership(events)),
    );
  }

  bool _isCruiseFeature(TelemetryFeature feature) =>
      feature.point.speedMps >=
          DriveDetectionCalibration.cruiseMinimumSpeedMps &&
      feature.smoothedAccelerationMps2.abs() <=
          DriveDetectionCalibration.cruiseAccelerationToleranceMps2 &&
      feature.rollingSpeedVariance <=
          DriveDetectionCalibration.cruiseMaximumSpeedVariance;

  List<_Run> _detectRuns(
    List<TelemetryFeature> features, {
    required bool Function(TelemetryFeature) enters,
    required bool Function(TelemetryFeature) continues,
    required Duration minimumDuration,
    required bool Function(_Run) validate,
  }) {
    final result = <_Run>[];
    int? start;
    int? lastMatching;
    for (var index = 0; index < features.length; index++) {
      final feature = features[index];
      if (start == null) {
        if (enters(feature)) {
          start = index;
          lastMatching = index;
        }
        continue;
      }
      if (continues(feature)) {
        lastMatching = index;
        continue;
      }
      final grace = feature.point.timestamp.difference(
        features[lastMatching!].point.timestamp,
      );
      if (grace <= DriveDetectionCalibration.detectorExitGrace) continue;
      _finishRun(
        result,
        features,
        start,
        lastMatching,
        minimumDuration,
        validate,
      );
      start = enters(feature) ? index : null;
      lastMatching = start;
    }
    if (start != null && lastMatching != null) {
      _finishRun(
        result,
        features,
        start,
        lastMatching,
        minimumDuration,
        validate,
      );
    }
    return result;
  }

  void _finishRun(
    List<_Run> target,
    List<TelemetryFeature> features,
    int start,
    int end,
    Duration minimumDuration,
    bool Function(_Run) validate,
  ) {
    final run = _Run(start, end);
    final duration = features[end].point.timestamp.difference(
      features[start].point.timestamp,
    );
    if (duration >= minimumDuration && validate(run)) target.add(run);
  }

  List<TrafficContext> _detectTraffic(List<TelemetryFeature> features) {
    final result = <TrafficContext>[];
    var start = 0;
    for (var end = 0; end < features.length; end++) {
      final cutoff = features[end].point.timestamp.subtract(
        DriveDetectionCalibration.trafficWindow,
      );
      while (start < end && features[start].point.timestamp.isBefore(cutoff)) {
        start++;
      }
      final observed = features[end].point.timestamp.difference(
        features[start].point.timestamp,
      );
      if (observed < DriveDetectionCalibration.minimumTrafficObservation) {
        result.add(TrafficContext.unknown);
        continue;
      }

      var speedSum = 0.0;
      var speedSquareSum = 0.0;
      var lowSpeed = 0;
      var stopped = 0;
      var stopTransitions = 0;
      var longitudinalCycles = 0;
      var previousStopped = false;
      var previousAccelerationSign = 0;
      for (var index = start; index <= end; index++) {
        final feature = features[index];
        final speed = feature.point.speedMps;
        speedSum += speed;
        speedSquareSum += speed * speed;
        if (speed <= DriveDetectionCalibration.trafficLowSpeedMps) lowSpeed++;
        final isStopped = speed <= DriveDetectionCalibration.stoppedSpeedMps;
        if (isStopped) stopped++;
        if (index > start && isStopped != previousStopped) stopTransitions++;
        previousStopped = isStopped;

        final acceleration = feature.smoothedAccelerationMps2;
        final sign =
            acceleration >= DriveDetectionCalibration.accelerationEnterMps2
            ? 1
            : acceleration <= DriveDetectionCalibration.decelerationEnterMps2
            ? -1
            : 0;
        if (sign != 0 &&
            previousAccelerationSign != 0 &&
            sign != previousAccelerationSign) {
          longitudinalCycles++;
        }
        if (sign != 0) previousAccelerationSign = sign;
      }
      final count = end - start + 1;
      final mean = speedSum / count;
      final variance = math.max(0, speedSquareSum / count - mean * mean);
      final lowRatio = lowSpeed / count;
      final stopRatio = stopped / count;
      final slowSignal =
          (1 - mean / DriveDetectionCalibration.trafficLowSpeedMps).clamp(
            0.0,
            1.0,
          );
      final variabilitySignal = (variance / 25).clamp(0.0, 1.0);
      final transitionSignal = (stopTransitions / 4).clamp(0.0, 1.0);
      final cycleSignal = (longitudinalCycles / 4).clamp(0.0, 1.0);
      final denseConfidence =
          (lowRatio * .45 + slowSignal * .35 + variabilitySignal * .2).clamp(
            0.0,
            1.0,
          );
      final stopGoConfidence =
          (lowRatio * .3 +
                  stopRatio * .25 +
                  transitionSignal * .25 +
                  cycleSignal * .2)
              .clamp(0.0, 1.0);

      if (stopGoConfidence >=
          DriveDetectionCalibration.stopAndGoConfidenceThreshold) {
        result.add(
          TrafficContext(
            regime: TrafficRegime.stopAndGo,
            confidence: stopGoConfidence,
            denseTrafficConfidence: denseConfidence,
            stopAndGoConfidence: stopGoConfidence,
          ),
        );
      } else if (denseConfidence >=
          DriveDetectionCalibration.denseTrafficConfidenceThreshold) {
        result.add(
          TrafficContext(
            regime: TrafficRegime.denseTraffic,
            confidence: denseConfidence,
            denseTrafficConfidence: denseConfidence,
            stopAndGoConfidence: stopGoConfidence,
          ),
        );
      } else {
        result.add(
          TrafficContext(
            regime: TrafficRegime.freeFlow,
            confidence: (1 - math.max(denseConfidence, stopGoConfidence))
                .clamp(0.0, 1.0)
                .toDouble(),
            denseTrafficConfidence: denseConfidence,
            stopAndGoConfidence: stopGoConfidence,
          ),
        );
      }
    }
    return result;
  }

  DrivingEvent _event(
    String sessionId,
    DrivingEventType type,
    _Run run,
    List<TelemetryFeature> features,
    List<TrafficContext> traffic,
  ) {
    var maximumSpeed = 0.0;
    var minimumSpeed = double.infinity;
    for (var index = run.start; index <= run.end; index++) {
      final speed = features[index].point.speedMps;
      maximumSpeed = math.max(maximumSpeed, speed);
      minimumSpeed = math.min(minimumSpeed, speed);
    }
    final midpoint = run.start + ((run.end - run.start) ~/ 2);
    final trafficContext = traffic[midpoint];
    final baseTags = <EventContextTag>{};
    final trafficTag = _tagForTraffic(trafficContext.regime);
    if (trafficTag != null) baseTags.add(trafficTag);
    final owner = _ownerFor(type);
    final metadata = <String, double>{};
    if (type == DrivingEventType.corner) {
      metadata['totalHeadingChangeDegrees'] = _headingChange(
        features,
        run.start,
        run.end,
      );
      metadata['apexIndex'] = _cornerApex(features, run).toDouble();
      baseTags.add(EventContextTag.cornering);
    } else {
      baseTags.add(_tagForEvent(type));
    }
    final durationSeconds =
        features[run.end].point.timestamp
            .difference(features[run.start].point.timestamp)
            .inMilliseconds /
        1000;
    final confidence = (durationSeconds / 5).clamp(.5, 1.0).toDouble();
    return DrivingEvent(
      id: '$sessionId:${type.name}:${run.start}:${run.end}',
      driveSessionId: sessionId,
      type: type,
      startIndex: run.start,
      endIndex: run.end,
      startTime: features[run.start].point.timestamp,
      endTime: features[run.end].point.timestamp,
      startSpeedMps: features[run.start].point.speedMps,
      endSpeedMps: features[run.end].point.speedMps,
      maximumSpeedMps: maximumSpeed,
      minimumSpeedMps: minimumSpeed == double.infinity ? 0 : minimumSpeed,
      distanceMeters: _distance(features, run.start, run.end),
      confidence: confidence,
      trafficContext: trafficContext,
      primaryOwner: owner,
      ownershipEligibility: <EventOwnerDomain>{owner},
      contextTags: baseTags,
      metadata: metadata,
    );
  }

  List<DrivingEvent> _resolveOwnership(List<DrivingEvent> events) {
    final overlapIds = <String, List<String>>{
      for (final event in events) event.id: <String>[],
    };
    final tags = <String, Set<EventContextTag>>{
      for (final event in events) event.id: {...event.contextTags},
    };
    for (var firstIndex = 0; firstIndex < events.length; firstIndex++) {
      final first = events[firstIndex];
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < events.length;
        secondIndex++
      ) {
        final second = events[secondIndex];
        if (second.startIndex > first.endIndex) break;
        if (second.endIndex < first.startIndex) continue;
        overlapIds[first.id]!.add(second.id);
        overlapIds[second.id]!.add(first.id);
        tags[first.id]!.add(_tagForEvent(second.type));
        tags[second.id]!.add(_tagForEvent(first.type));
      }
    }
    return events
        .map(
          (event) => event.copyWith(
            contextTags: Set.unmodifiable(tags[event.id]!),
            overlappingEventIds: List.unmodifiable(overlapIds[event.id]!),
          ),
        )
        .toList(growable: false);
  }

  EventOwnerDomain _ownerFor(DrivingEventType type) => switch (type) {
    DrivingEventType.stop => EventOwnerDomain.stopping,
    DrivingEventType.acceleration => EventOwnerDomain.acceleration,
    DrivingEventType.deceleration => EventOwnerDomain.braking,
    DrivingEventType.corner => EventOwnerDomain.cornering,
    DrivingEventType.cruise => EventOwnerDomain.cruising,
  };

  EventContextTag _tagForEvent(DrivingEventType type) => switch (type) {
    DrivingEventType.stop => EventContextTag.stopped,
    DrivingEventType.acceleration => EventContextTag.accelerating,
    DrivingEventType.deceleration => EventContextTag.decelerating,
    DrivingEventType.corner => EventContextTag.cornering,
    DrivingEventType.cruise => EventContextTag.cruising,
  };

  EventContextTag? _tagForTraffic(TrafficRegime regime) => switch (regime) {
    TrafficRegime.stopAndGo => EventContextTag.stopAndGo,
    TrafficRegime.denseTraffic => EventContextTag.denseTraffic,
    TrafficRegime.freeFlow => EventContextTag.freeFlow,
    TrafficRegime.unknown => null,
  };

  void _paint(List<DrivingPhase> phases, List<_Run> runs, DrivingPhase phase) {
    for (final run in runs) {
      for (var index = run.start; index <= run.end; index++) {
        phases[index] = phase;
      }
    }
  }

  List<DrivingPhaseInterval> _compressPhases(
    List<DrivingPhase> phases,
    List<TelemetryFeature> features,
  ) {
    final result = <DrivingPhaseInterval>[];
    var start = 0;
    for (var index = 1; index <= phases.length; index++) {
      if (index < phases.length && phases[index] == phases[start]) continue;
      result.add(
        DrivingPhaseInterval(
          phase: phases[start],
          startIndex: start,
          endIndex: index - 1,
          startTime: features[start].point.timestamp,
          endTime: features[index - 1].point.timestamp,
        ),
      );
      start = index;
    }
    return result;
  }

  double _distance(List<TelemetryFeature> features, int start, int end) {
    var distance = 0.0;
    for (var index = start + 1; index <= end; index++) {
      distance += features[index].point.distanceFromPreviousMeters;
    }
    return distance;
  }

  double _headingChange(List<TelemetryFeature> features, int start, int end) {
    var headingChange = 0.0;
    for (var index = start + 1; index <= end; index++) {
      headingChange += features[index].headingDeltaDegrees.abs();
    }
    return headingChange;
  }

  int _cornerApex(List<TelemetryFeature> features, _Run run) {
    var apex = run.start;
    var maximumRate = 0.0;
    for (var index = run.start; index <= run.end; index++) {
      if (features[index].headingChangeRateDegreesPerSecond > maximumRate) {
        maximumRate = features[index].headingChangeRateDegreesPerSecond;
        apex = index;
      }
    }
    return apex;
  }
}

/// A live collector using the exact same deterministic offline analyzer.
/// No separate live thresholds or filtering path is introduced.
class DrivePhaseAnalysisSession {
  final String driveSessionId;
  final DrivePhaseAnalyzer analyzer;
  final List<CanonicalTelemetryPoint> _points = [];

  DrivePhaseAnalysisSession({
    required this.driveSessionId,
    this.analyzer = const DrivePhaseAnalyzer(),
  });

  void add(CanonicalTelemetryPoint point) => _points.add(point);

  DrivePhaseAnalysisResult finish() =>
      analyzer.analyze(driveSessionId: driveSessionId, telemetry: _points);
}

class _Run {
  final int start;
  final int end;

  const _Run(this.start, this.end);
}
