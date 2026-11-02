import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_time_analysis.dart';
import '../../world_publish/models/published_drive_source.dart';
import '../models/drive_score_result.dart';
import 'drive_score_calculator.dart';

/// Schema 2 is an explicit mode contract, not a reinterpretation of v1.
({DriveScoreResult result, bool eligible}) calculateReliablePublishedSource(
  Map<String, dynamic> json,
) {
  final source = PublishedDriveSource.fromJson(json);
  if (source.schemaVersion != 2) {
    throw const FormatException('Reliable source required');
  }
  final points = source.canonicalTelemetry
      .map(
        (p) => CanonicalTelemetryPoint(
          latitude: p.latitude,
          longitude: p.longitude,
          timestamp: p.timestamp,
          speedMps: p.speedMps,
          headingDegrees: p.headingDegrees,
          altitudeMeters: p.altitudeMeters,
          accuracyMeters: p.accuracyMeters,
          distanceFromPreviousMeters: p.distanceFromPreviousMeters,
          accelerationMps2: p.accelerationMps2,
          breakBefore: p.breakBefore!,
          gapDurationMicros: p.gapDurationMicros!,
          speedSource: p.speedSource!,
          accelerationReliable: p.accelerationReliable!,
        ),
      )
      .toList(growable: false);
  for (var i = 0; i < points.length; i++) {
    if (json['canonical_telemetry'][i]['timestamp_micros'] !=
        points[i].timestamp.microsecondsSinceEpoch.toString()) {
      throw const FormatException('Timestamp precision evidence mismatch');
    }
  }
  return (
    result: const DriveScoreCalculator().calculateReliable(telemetry: points),
    eligible: DriveTimeAnalysis.analyze(
      points,
      metadata: source.telemetryReliability!,
    ).scoreEligible,
  );
}
