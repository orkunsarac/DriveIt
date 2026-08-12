import 'dart:math' as math;
import '../config/transition_control_calibration.dart';
import '../models/driving_analysis_models.dart';
import '../models/flow_acceleration_transition_models.dart';

class TransitionControlEngine {
  const TransitionControlEngine();
  TransitionControlScoreResult score(DrivePhaseAnalysisResult a) {
    final events = a.events;
    final transitions = <DrivingTransition>[];
    for (var i = 0; i + 2 < events.length; i++) {
      final x = events[i], mid = events[i + 1], target = events[i + 2];
      final type = _type(x, mid, target);
      if (type == null || !_eligible(x, mid, target)) continue;
      transitions.add(
        DrivingTransition(
          type: type,
          sourceEventId: x.id,
          intermediateEventId: mid.id,
          targetEventId: target.id,
          quality: _quality(a, target),
          trafficContext: mid.trafficContext,
        ),
      );
    }
    if (transitions.isEmpty) {
      return const TransitionControlScoreResult(
        totalScore: 0,
        cruiseDecelCruiseScore: 0,
        cruiseCornerCruiseScore: 0,
        accelerationCruiseScore: 0,
        applicable: false,
        sampleSufficient: false,
        analyzedTransitionCount: 0,
        transitionTypeCounts: {},
        transitions: [],
        diagnostics: 'No eligible phase transition.',
      );
    }
    double scoreType(DrivingTransitionType t, double max) {
      final list = transitions.where((x) => x.type == t).toList();
      if (list.isEmpty) {
        return 0;
      }
      return list.map((x) => x.quality).reduce((x, y) => x + y) /
          list.length *
          max;
    }

    final aScore = scoreType(DrivingTransitionType.cruiseDecelCruise, 20),
        cScore = scoreType(DrivingTransitionType.cruiseCornerCruise, 20),
        accScore = scoreType(DrivingTransitionType.accelerationCruise, 10);
    final counts = {
      for (final t in DrivingTransitionType.values)
        t: transitions.where((x) => x.type == t).length,
    };
    return TransitionControlScoreResult(
      totalScore: aScore + cScore + accScore,
      cruiseDecelCruiseScore: aScore,
      cruiseCornerCruiseScore: cScore,
      accelerationCruiseScore: accScore,
      applicable: true,
      sampleSufficient: transitions.length >= 2,
      analyzedTransitionCount: transitions.length,
      transitionTypeCounts: counts,
      transitions: transitions,
      diagnostics:
          'Analyzed ${transitions.length} positive phase transition(s).',
    );
  }

  DrivingTransitionType? _type(DrivingEvent a, DrivingEvent b, DrivingEvent c) {
    if (c.type != DrivingEventType.cruise) {
      return null;
    }
    if (a.type == DrivingEventType.cruise &&
        b.type == DrivingEventType.deceleration) {
      return DrivingTransitionType.cruiseDecelCruise;
    }
    if (a.type == DrivingEventType.cruise &&
        b.type == DrivingEventType.corner) {
      return DrivingTransitionType.cruiseCornerCruise;
    }
    if (a.type == DrivingEventType.acceleration) {
      return DrivingTransitionType.accelerationCruise;
    }
    return null;
  }

  bool _eligible(DrivingEvent a, DrivingEvent b, DrivingEvent c) {
    final traffic = math.max(
      b.trafficContext.denseTrafficConfidence,
      b.trafficContext.stopAndGoConfidence,
    );
    return c.maximumSpeedMps >=
            TransitionControlCalibration.minimumCruiseSpeedMps &&
        traffic < TransitionControlCalibration.trafficExclusionConfidence &&
        b.startTime.difference(a.endTime) <=
            TransitionControlCalibration.maximumGap &&
        c.startTime.difference(b.endTime) <=
            TransitionControlCalibration.maximumGap;
  }

  double _quality(DrivePhaseAnalysisResult a, DrivingEvent target) {
    final f = a.features.sublist(target.startIndex, target.endIndex + 1);
    final mean =
        f.map((x) => x.point.speedMps).reduce((x, y) => x + y) / f.length;
    final v =
        f.fold<double>(
          0,
          (s, x) => s + (x.point.speedMps - mean) * (x.point.speedMps - mean),
        ) /
        f.length;
    return (1 -
            math.sqrt(v) /
                TransitionControlCalibration.targetCruiseVarianceTolerance)
        .clamp(0, 1)
        .toDouble();
  }
}
