import 'package:driveit_project/features/drive_score/models/driving_analysis_models.dart';
import 'package:driveit_project/features/drive_score/services/drive_phase_analyzer.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = DrivePhaseAnalyzer();

  test('stable high-speed drive becomes free-flow cruise', () {
    final result = analyzer.analyze(
      driveSessionId: 'steady',
      telemetry: points(
        List<double>.generate(15, (index) => 22 + (index % 3 - 1) * .2),
      ),
    );

    expect(result.eventsOfType(DrivingEventType.cruise), isNotEmpty);
    expect(result.eventsOfType(DrivingEventType.acceleration), isEmpty);
    expect(result.eventsOfType(DrivingEventType.deceleration), isEmpty);
    expect(result.trafficTimeline.last.regime, TrafficRegime.freeFlow);
  });

  test('clean sustained speed gain creates one acceleration event', () {
    final result = analyzer.analyze(
      driveSessionId: 'accel',
      telemetry: points([5, 7, 9, 11, 13, 15]),
    );

    expect(result.eventsOfType(DrivingEventType.acceleration).length, 1);
    expect(result.eventsOfType(DrivingEventType.cruise), isEmpty);
  });

  test('controlled speed loss creates a deceleration event', () {
    final result = analyzer.analyze(
      driveSessionId: 'decel',
      telemetry: points([20, 18, 16, 14, 12, 10]),
    );

    expect(result.eventsOfType(DrivingEventType.deceleration).length, 1);
  });

  test('deceleration into a confirmed stop creates both events', () {
    final result = analyzer.analyze(
      driveSessionId: 'stop',
      telemetry: points([10, 8, 6, 4, 2, 1, .5, 0, 0, 0, 0]),
    );

    expect(result.eventsOfType(DrivingEventType.deceleration), isNotEmpty);
    expect(result.eventsOfType(DrivingEventType.stop).length, 1);
    expect(
      result.phaseTimeline.any((part) => part.phase == DrivingPhase.stopped),
      isTrue,
    );
  });

  test('stationary GPS drift remains stopped without false motion events', () {
    final telemetry = points(
      [0, .5, .2, .8, 0, .3, 0, 0],
      distances: [0, 0, 0, 0, 0, 0, 0, 0],
    );
    final result = analyzer.analyze(
      driveSessionId: 'drift',
      telemetry: telemetry,
    );

    expect(result.eventsOfType(DrivingEventType.stop).length, 1);
    expect(result.eventsOfType(DrivingEventType.acceleration), isEmpty);
    expect(result.eventsOfType(DrivingEventType.cruise), isEmpty);
  });

  test('repeated low-speed stop-go pattern produces high confidence', () {
    final result = analyzer.analyze(
      driveSessionId: 'traffic',
      telemetry: points([
        0,
        4,
        8,
        3,
        0,
        6,
        1,
        0,
        5,
        0,
        7,
        1,
        0,
      ], secondsBetween: 5),
    );

    expect(result.trafficTimeline.last.regime, TrafficRegime.stopAndGo);
    expect(result.trafficTimeline.last.stopAndGoConfidence, greaterThan(.62));
    expect(result.events.length, lessThan(10));
  });

  test('steady low-speed movement is dense traffic without stop-and-go', () {
    final result = analyzer.analyze(
      driveSessionId: 'dense',
      telemetry: points(List<double>.filled(15, 5.5)),
    );

    expect(result.trafficTimeline.last.regime, TrafficRegime.denseTraffic);
    expect(
      result.trafficTimeline.last.stopAndGoConfidence,
      lessThan(result.trafficTimeline.last.denseTrafficConfidence),
    );
  });

  test('regular heading change creates a corner event', () {
    final result = analyzer.analyze(
      driveSessionId: 'corner',
      telemetry: points(
        List<double>.filled(8, 15),
        headings: [0, 0, 5, 10, 15, 20, 25, 30],
        distances: List<double>.filled(8, 15),
      ),
    );

    final corner = result.eventsOfType(DrivingEventType.corner).single;
    expect(result.corneringTimeline.single.phase, DrivingPhase.cornering);
    expect(
      corner.metadata['totalHeadingChangeDegrees'],
      greaterThanOrEqualTo(15),
    );
  });

  test('a single heading spike does not become a corner', () {
    final result = analyzer.analyze(
      driveSessionId: 'heading-spike',
      telemetry: points(
        List<double>.filled(7, 15),
        headings: [0, 0, 40, 40, 40, 40, 40],
      ),
    );

    expect(result.eventsOfType(DrivingEventType.corner), isEmpty);
  });

  test('corner and deceleration overlap without sharing primary owner', () {
    final result = analyzer.analyze(
      driveSessionId: 'corner-decel',
      telemetry: points(
        [20, 18, 16, 14, 12, 10, 8],
        headings: [0, 5, 10, 15, 20, 25, 30],
        distances: List<double>.filled(7, 15),
      ),
    );

    final corner = result.eventsOfType(DrivingEventType.corner).single;
    final deceleration = result
        .eventsOfType(DrivingEventType.deceleration)
        .single;
    expect(corner.primaryOwner, EventOwnerDomain.cornering);
    expect(deceleration.primaryOwner, EventOwnerDomain.braking);
    expect(corner.overlappingEventIds, contains(deceleration.id));
    expect(deceleration.contextTags, contains(EventContextTag.cornering));
  });

  test('threshold flicker does not split into acceleration events', () {
    final result = analyzer.analyze(
      driveSessionId: 'flicker',
      telemetry: points([10, 10.2, 10.1, 10.3, 10.2, 10.4, 10.3, 10.5]),
    );

    expect(result.eventsOfType(DrivingEventType.acceleration), isEmpty);
    expect(result.eventsOfType(DrivingEventType.deceleration), isEmpty);
  });

  test('same canonical timeline produces identical deterministic result', () {
    final telemetry = points(
      [0, 2, 4, 6, 8, 8, 8, 6, 4, 2, 0, 0, 0, 0],
      headings: [0, 0, 0, 0, 0, 5, 10, 15, 20, 20, 20, 20, 20, 20],
    );
    final first = analyzer.analyze(
      driveSessionId: 'deterministic',
      telemetry: telemetry,
    );
    final second = analyzer.analyze(
      driveSessionId: 'deterministic',
      telemetry: telemetry,
    );

    expect(
      first.events.map((event) => '${event.id}:${event.primaryOwner.name}'),
      second.events.map((event) => '${event.id}:${event.primaryOwner.name}'),
    );
    expect(
      first.phaseTimeline.map(
        (part) => '${part.phase.name}:${part.startIndex}:${part.endIndex}',
      ),
      second.phaseTimeline.map(
        (part) => '${part.phase.name}:${part.startIndex}:${part.endIndex}',
      ),
    );
    expect(
      first.trafficTimeline.map((context) => context.regime),
      second.trafficTimeline.map((context) => context.regime),
    );
  });

  test('incremental collector and offline analysis share the same engine', () {
    final telemetry = points([5, 7, 9, 11, 13, 13, 13, 13, 13, 13, 13]);
    final session = DrivePhaseAnalysisSession(driveSessionId: 'shared');
    for (final point in telemetry) {
      session.add(point);
    }
    final liveResult = session.finish();
    final offlineResult = analyzer.analyze(
      driveSessionId: 'shared',
      telemetry: telemetry,
    );

    expect(
      liveResult.events.map((event) => event.id),
      offlineResult.events.map((event) => event.id),
    );
    expect(
      liveResult.phaseTimeline.map((part) => part.phase),
      offlineResult.phaseTimeline.map((part) => part.phase),
    );
  });
}

List<CanonicalTelemetryPoint> points(
  List<double> speeds, {
  List<double>? headings,
  List<double>? distances,
  int secondsBetween = 1,
}) {
  final start = DateTime.utc(2026, 1, 1, 12);
  return List.generate(speeds.length, (index) {
    final previousSpeed = index == 0 ? speeds[index] : speeds[index - 1];
    final distance =
        distances?[index] ??
        (speeds[index] <= 5 / 3.6 ? 0 : speeds[index] * secondsBetween);
    return CanonicalTelemetryPoint(
      latitude: 41 + index * .00001,
      longitude: 29 + index * .00001,
      timestamp: start.add(Duration(seconds: index * secondsBetween)),
      speedMps: speeds[index],
      headingDegrees: headings?[index] ?? 0,
      altitudeMeters: 10,
      accuracyMeters: 5,
      distanceFromPreviousMeters: index == 0 ? 0 : distance,
      accelerationMps2: index == 0
          ? 0
          : (speeds[index] - previousSpeed) / secondsBetween,
    );
  });
}
