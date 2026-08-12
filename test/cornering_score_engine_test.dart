import 'package:driveit_project/features/drive_score/models/driving_analysis_models.dart';
import 'package:driveit_project/features/drive_score/services/cornering_score_engine.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CorneringScoreEngine();

  test(
    'wide clean corner retains more speed than an excessive wide slowdown',
    () {
      final clean = engine.score(
        analysisFor(
          speeds: [25, 25, 24.5, 24, 23.5, 24, 24.5, 25],
          headingChange: 30,
          distanceMeters: 180,
        ),
      );
      final excessive = engine.score(
        analysisFor(
          speeds: [25, 25, 23, 20, 15, 18, 22, 24],
          headingChange: 30,
          distanceMeters: 180,
        ),
      );

      expect(
        clean.speedRetentionScore,
        greaterThan(excessive.speedRetentionScore),
      );
    },
  );

  test('sharp corner accounts for geometry before judging speed loss', () {
    final cleanSharp = engine.score(
      analysisFor(
        speeds: [22, 21, 20, 18, 17, 18, 20, 21],
        headingChange: 90,
        distanceMeters: 120,
      ),
    );
    final excessiveSharp = engine.score(
      analysisFor(
        speeds: [22, 22, 21, 15, 4, 8, 15, 18],
        headingChange: 90,
        distanceMeters: 120,
      ),
    );

    expect(
      cleanSharp.speedRetentionScore,
      greaterThan(excessiveSharp.speedRetentionScore),
    );
  });

  test('controlled entry scores higher than a late speed collapse', () {
    final controlled = engine.score(
      analysisFor(speeds: [28, 26, 24, 22, 20, 20, 22, 24]),
    );
    final lateCollapse = engine.score(
      analysisFor(speeds: [28, 28, 28, 27, 16, 15, 18, 22]),
    );

    expect(
      controlled.entryQualityScore,
      greaterThan(lateCollapse.entryQualityScore),
    );
  });

  test('clean exit scores higher than hesitant exit recovery', () {
    final clean = engine.score(
      analysisFor(speeds: [24, 23, 21, 20, 19, 21, 23, 24]),
    );
    final hesitant = engine.score(
      analysisFor(speeds: [24, 23, 21, 20, 19, 18, 19, 20]),
    );

    expect(clean.exitQualityScore, greaterThan(hesitant.exitQualityScore));
  });

  test('stable corner scores higher than oscillating corner speed', () {
    final stable = engine.score(
      analysisFor(speeds: [20, 20, 19.5, 19, 19, 19.5, 20, 20]),
    );
    final unstable = engine.score(
      analysisFor(speeds: [20, 17, 21, 16, 20, 15, 21, 18]),
    );

    expect(stable.stabilityScore, greaterThan(unstable.stabilityScore));
  });

  test('low speed traffic corner is not applicable', () {
    final result = engine.score(
      analysisFor(
        speeds: [6, 6, 5.5, 5, 5, 5, 5.5, 6],
        traffic: const TrafficContext(
          regime: TrafficRegime.stopAndGo,
          confidence: .9,
          denseTrafficConfidence: .8,
          stopAndGoConfidence: .9,
        ),
      ),
    );

    expect(result.applicable, isFalse);
    expect(result.totalScore, 0);
  });

  test('corner context with deceleration overlap remains scoreable', () {
    final result = engine.score(
      analysisFor(
        speeds: [22, 21, 20, 18, 17, 18, 20, 21],
        overlaps: const ['deceleration-1'],
      ),
    );

    expect(result.applicable, isTrue);
    expect(result.contributions.single.overlapEventIds, ['deceleration-1']);
    expect(result.totalScore, inInclusiveRange(0, 150));
  });

  test('no corner is not applicable instead of a zero-point penalty', () {
    final result = engine.score(
      DrivePhaseAnalysisResult(
        driveSessionId: 'empty',
        features: const [],
        phaseTimeline: const [],
        corneringTimeline: const [],
        trafficTimeline: const [],
        events: const [],
      ),
    );

    expect(result.applicable, isFalse);
    expect(result.sampleSufficient, isFalse);
    expect(result.totalScore, 0);
  });

  test('multiple corners aggregate without exceeding the 150 point bound', () {
    final first = analysisFor(speeds: [20, 20, 19, 18, 18, 19, 20, 20]);
    final second = analysisFor(
      speeds: [24, 23, 22, 21, 20, 21, 23, 24],
      eventId: 'corner-2',
    );
    final result = engine.score(
      DrivePhaseAnalysisResult(
        driveSessionId: 'multi',
        features: first.features,
        phaseTimeline: const [],
        corneringTimeline: const [],
        trafficTimeline: first.trafficTimeline,
        events: [...first.events, ...second.events],
      ),
    );

    expect(result.analyzedCornerCount, 2);
    expect(result.sampleSufficient, isTrue);
    expect(result.totalScore, inInclusiveRange(0, 150));
  });

  test('same input produces the same deterministic cornering result', () {
    final analysis = analysisFor(speeds: [22, 21, 20, 18, 17, 18, 20, 22]);

    final first = engine.score(analysis);
    final second = engine.score(analysis);

    expect(first.totalScore, second.totalScore);
    expect(
      first.contributions.single.estimatedRadiusMeters,
      second.contributions.single.estimatedRadiusMeters,
    );
  });
}

DrivePhaseAnalysisResult analysisFor({
  required List<double> speeds,
  double headingChange = 60,
  double distanceMeters = 120,
  TrafficContext traffic = TrafficContext.unknown,
  List<String> overlaps = const [],
  String eventId = 'corner-1',
}) {
  final start = DateTime.utc(2026, 8, 1, 12);
  final distancePerPoint = distanceMeters / (speeds.length - 1);
  final features = List.generate(speeds.length, (index) {
    final heading = headingChange * index / (speeds.length - 1);
    return TelemetryFeature(
      index: index,
      point: CanonicalTelemetryPoint(
        latitude: 41 + index * .0001,
        longitude: 29 + index * .0001,
        timestamp: start.add(Duration(seconds: index)),
        speedMps: speeds[index],
        headingDegrees: heading,
        altitudeMeters: 0,
        accuracyMeters: 5,
        distanceFromPreviousMeters: index == 0 ? 0 : distancePerPoint,
        accelerationMps2: index == 0 ? 0 : speeds[index] - speeds[index - 1],
      ),
      rollingMeanSpeedMps: speeds[index],
      rollingSpeedVariance: 0,
      smoothedAccelerationMps2: index == 0
          ? 0
          : speeds[index] - speeds[index - 1],
      headingDeltaDegrees: index == 0 ? 0 : headingChange / (speeds.length - 1),
      headingChangeRateDegreesPerSecond: index == 0
          ? 0
          : headingChange / (speeds.length - 1),
      rollingLowSpeedRatio: 0,
      stationaryDurationSeconds: 0,
      movingDurationSeconds: index.toDouble(),
    );
  });
  final event = DrivingEvent(
    id: eventId,
    driveSessionId: 'drive',
    type: DrivingEventType.corner,
    startIndex: 0,
    endIndex: speeds.length - 1,
    startTime: start,
    endTime: start.add(Duration(seconds: speeds.length - 1)),
    startSpeedMps: speeds.first,
    endSpeedMps: speeds.last,
    maximumSpeedMps: speeds.reduce((a, b) => a > b ? a : b),
    minimumSpeedMps: speeds.reduce((a, b) => a < b ? a : b),
    distanceMeters: distanceMeters,
    confidence: .9,
    trafficContext: traffic,
    primaryOwner: EventOwnerDomain.cornering,
    ownershipEligibility: const {EventOwnerDomain.cornering},
    contextTags: const {EventContextTag.cornering},
    overlappingEventIds: overlaps,
    metadata: {
      'totalHeadingChangeDegrees': headingChange,
      'apexIndex': (speeds.length ~/ 2).toDouble(),
    },
  );
  return DrivePhaseAnalysisResult(
    driveSessionId: 'drive',
    features: features,
    phaseTimeline: const [],
    corneringTimeline: const [],
    trafficTimeline: List.filled(speeds.length, traffic),
    events: [event],
  );
}
