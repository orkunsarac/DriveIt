// ignore_for_file: avoid_relative_lib_imports, avoid_print
import 'dart:convert';
import 'world_scoring_adapter.dart' show telemetry, score;
import '../lib/features/drive_score/services/drive_score_calculator.dart';

void main() {
  final points = List.generate(
    120,
    (i) => {
      'latitude': 40.0,
      'longitude': 29 + i * .0001,
      'timestamp': DateTime.utc(
        2026,
      ).add(Duration(seconds: i)).toIso8601String(),
      'speed_mps': 10.0,
      'heading_degrees': 90.0,
      'altitude_meters': 50.0,
      'accuracy_meters': 5.0,
      'distance_from_previous_meters': i == 0 ? 0.0 : 10.0,
      'acceleration_mps2': 0.0,
    },
  );
  final result = score(
    const DriveScoreCalculator().calculate(telemetry: telemetry(points)),
  );
  print(
    jsonEncode({
      'displayScore': result['displayScore'],
      'totalScore': result['totalScore'],
      'categories': result['categories'],
    }),
  );
}
