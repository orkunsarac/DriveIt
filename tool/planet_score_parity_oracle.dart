// ignore_for_file: avoid_relative_lib_imports, avoid_print
import 'dart:convert';
import 'world_scoring_adapter.dart' show telemetry, score;
import '../lib/features/drive_score/services/drive_score_calculator.dart';
import '../lib/features/world_publish/models/published_drive_source.dart';
import '../lib/services/drive_time_analysis.dart';
import '../lib/models/canonical_telemetry_point.dart';

// Synthetic inputs: legacy v1 and explicit reliable schema 2 stay distinct.
void main() {
  final cases = <Map<String, dynamic>>[];
  for (final name in [
    'steady',
    'stop-start',
    'braking',
    'cornering',
    'gap',
    'microseconds',
    'long',
    'single',
    'empty',
    'unavailable',
    'segments',
    'short-gap',
  ]) {
    final count = name == 'long'
        ? 3600
        : name == 'single'
        ? 1
        : name == 'empty'
        ? 0
        : 180;
    final points = List.generate(count, (i) {
      final speed = switch (name) {
        'stop-start' =>
          i % 60 < 20 ? 0.0 : (i % 60 < 35 ? (i % 60 - 20) * .8 : 12.0),
        'braking' => (18 - (i % 60) * .5).clamp(0.0, 18.0),
        _ => 10.0,
      };
      return {
        'latitude': 40.0,
        'longitude': 29 + i * .00001,
        'timestamp': DateTime.utc(2026)
            .add(
              Duration(
                seconds:
                    i +
                    (name == 'gap' && i >= 90
                        ? 120
                        : (name == 'segments' || name == 'short-gap') && i >= 90
                        ? 10
                        : 0),
                microseconds: name == 'microseconds' ? i * 37 : 0,
              ),
            )
            .toIso8601String(),
        'speed_mps': speed,
        'heading_degrees': name == 'cornering' ? (i % 90) * 3.0 : 90.0,
        'altitude_meters': 50.0,
        'accuracy_meters': 5.0,
        'distance_from_previous_meters': i == 0 ? 0.0 : speed,
        'acceleration_mps2': name == 'braking'
            ? -.5
            : name == 'stop-start' && i % 60 >= 20 && i % 60 < 35
            ? .8
            : 0.0,
      };
    });
    Object? expected;
    try {
      expected = score(
        const DriveScoreCalculator().calculate(telemetry: telemetry(points)),
      );
    } on InsufficientDriveScoreTelemetryException {
      expected = null;
    }
    Object? reliable;
    try {
      reliable = score(
        const DriveScoreCalculator().calculateReliable(
          telemetry: telemetry(points),
        ),
      );
    } on InsufficientDriveScoreTelemetryException {
      reliable = null;
    }
    cases.add({
      'name': name,
      'input': {'canonical_telemetry': points},
      'expected': expected,
      'localReliableDiffers': jsonEncode(reliable) != jsonEncode(expected),
      'localReliableExpected': reliable,
    });
    if (points.length >= 2) {
      final canonical = telemetry(points).asMap().entries.map((entry) {
        final p = entry.value, i = entry.key;
        final unknown = name == 'unavailable' && i >= 60 && i < 70;
        final boundary = name == 'segments' && i == 90;
        return CanonicalTelemetryPoint(
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: p.timestamp,
          speedMps: p.speedMps,
          headingDegrees: p.headingDegrees,
          altitudeMeters: p.altitudeMeters,
          accuracyMeters: p.accuracyMeters,
          distanceFromPreviousMeters: p.distanceFromPreviousMeters,
          accelerationMps2: p.accelerationMps2,
          speedSource: unknown ? 'unavailable' : 'native',
          accelerationReliable: !unknown && !boundary,
          breakBefore: boundary,
          gapDurationMicros: boundary ? 10000000 : 0,
        );
      }).toList();
      final reliableScore = score(
        const DriveScoreCalculator().calculateReliable(telemetry: canonical),
      );
      final start = canonical.first.timestamp;
      final end = canonical.last.timestamp;
      final metadata = {
        'reliabilityPolicyVersion': 1,
        'startedAtMicros': start.microsecondsSinceEpoch,
        'stopRequestedAtMicros': end.microsecondsSinceEpoch,
      };
      final source = PublishedDriveSource(
        schemaVersion: 2,
        publishId: 'synthetic',
        localDriveId: 'synthetic',
        telemetryVersion: 1,
        driveScoreAlgorithmVersion: 1,
        worldRulesVersion: 6,
        startedAt: start,
        endedAt: end,
        recordedDistanceMeters: 10000,
        calculationMode: 'reliable_intervals',
        calculationVersion: 1,
        telemetryReliability: metadata,
        rawRoute: [
          const PublishedRoutePoint(
            latitude: 40,
            longitude: 29,
            breakBefore: false,
          ),
          const PublishedRoutePoint(
            latitude: 40,
            longitude: 29.01,
            breakBefore: false,
          ),
        ],
        canonicalTelemetry: canonical
            .map(
              (p) => PublishedTelemetryPoint(
                latitude: p.latitude,
                longitude: p.longitude,
                timestamp: p.timestamp,
                speedMps: p.speedMps,
                headingDegrees: p.headingDegrees,
                altitudeMeters: p.altitudeMeters,
                accuracyMeters: p.accuracyMeters,
                distanceFromPreviousMeters: p.distanceFromPreviousMeters,
                accelerationMps2: p.accelerationMps2,
                speedSource: p.speedSource,
                breakBefore: p.breakBefore,
                gapDurationMicros: p.gapDurationMicros,
                accelerationReliable: p.accelerationReliable,
              ),
            )
            .toList(),
      );
      cases.add({
        'name': 'reliable-$name',
        'input': source.toJson(),
        'expected': {
          ...reliableScore,
          'calculationMode': 'reliable_intervals',
          'calculationVersion': 1,
          'reliabilityPolicyVersion': 1,
          'scoreEligible': DriveTimeAnalysis.analyze(
            canonical,
            metadata: metadata,
          ).scoreEligible,
        },
        'localReliableDiffers': false,
      });
    }
  }
  print(jsonEncode(cases));
}
