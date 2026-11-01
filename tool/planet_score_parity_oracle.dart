// ignore_for_file: avoid_relative_lib_imports, avoid_print
import 'dart:convert';
import 'world_scoring_adapter.dart' show telemetry, score;
import '../lib/features/drive_score/services/drive_score_calculator.dart';

// Synthetic inputs only: the server entrypoint intentionally uses legacy v1,
// not the opt-in local reliable-interval calculator.
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
                seconds: i + (name == 'gap' && i >= 90 ? 120 : 0),
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
  }
  print(jsonEncode(cases));
}
