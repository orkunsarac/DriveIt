// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:js_interop';
import 'world_scoring_adapter.dart' show telemetry, score;
import '../lib/features/drive_score/services/drive_score_calculator.dart';
import '../lib/features/drive_score/services/published_source_score_calculator.dart';

@JS('driveItPlanetDetailScore')
external set detailScore(JSFunction value);
void main() {
  detailScore = ((JSString input) {
    final source = jsonDecode(input.toDart) as Map<String, dynamic>;
    try {
      if (source['schema_version'] == 2) {
        final reliable = calculateReliablePublishedSource(source);
        return jsonEncode({
          ...score(reliable.result),
          'calculationMode': reliable.result.calculationMode,
          'calculationVersion': reliable.result.calculationVersion,
          'reliabilityPolicyVersion': reliable.result.reliabilityPolicyVersion,
          'scoreEligible': reliable.eligible,
        }).toJS;
      }
      if (source['schema_version'] != null && source['schema_version'] != 1) {
        throw const FormatException('Unsupported scoring source');
      }
      return jsonEncode(
        score(
          const DriveScoreCalculator().calculate(
            telemetry: telemetry(source['canonical_telemetry'] as List),
          ),
        ),
      ).toJS;
    } on InsufficientDriveScoreTelemetryException {
      return 'null'.toJS;
    }
  }).toJS;
}
