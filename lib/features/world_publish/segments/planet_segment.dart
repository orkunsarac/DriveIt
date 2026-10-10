import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_time_analysis.dart';
import '../../../services/gps_session_transfer.dart';
import '../../my_world/config/my_world_rules.dart';
import '../../drive_score/services/drive_score_calculator.dart';

/// Local evidence, NOT provider validation or shared Planet ownership.
class PlanetSegment {
  const PlanetSegment({
    required this.id,
    required this.sourceDriveId,
    required this.order,
    required this.points,
    required this.distanceMeters,
    required this.score,
    required this.reason,
  });
  static const geometryVersion = 1;
  final String id, sourceDriveId;
  final int order;
  final List<CanonicalTelemetryPoint> points;
  final double distanceMeters;
  final int? score;
  final String? reason;
  bool get eligible => reason == null;
  Map<String, dynamic> toMap() => {
    'version': 1,
    'id': id,
    'sourceDriveId': sourceDriveId,
    'order': order,
    'rulesVersion': MyWorldRules.worldRulesVersion,
    'geometryVersion': geometryVersion,
    'distanceMeters': distanceMeters,
    'score': score,
    'reason': reason,
    'validationState': 'localCandidate',
    'timeBoundarySource': 'canonicalSamples',
    'startMicros': points.first.timestamp.microsecondsSinceEpoch,
    'endMicros': points.last.timestamp.microsecondsSinceEpoch,
    'points': points.map(GpsSessionTransfer.pointContent).toList(),
  };
}

class PlanetSegmentPreview {
  const PlanetSegmentPreview(this.segments, this.unavailableReason);
  final List<PlanetSegment> segments;
  final String? unavailableReason;
  Iterable<PlanetSegment> get eligible => segments.where((s) => s.eligible);
  double get eligibleDistance =>
      eligible.fold(0, (sum, s) => sum + s.distanceMeters);
}

class PlanetSegmentBuilder {
  const PlanetSegmentBuilder();
  PlanetSegmentPreview build(String driveId, DriveTelemetryRecord? record) {
    // Legacy route geometry alone cannot prove GPS continuity or timing.
    if (record == null ||
        record.dataVersion != DriveTelemetryRecord.currentDataVersion ||
        record.driveSessionId != driveId ||
        record.acquisitionMetadata['reliabilityPolicyVersion'] != 1) {
      return const PlanetSegmentPreview(
        [],
        'Güvenilir GPS parça metadata’sı bulunamadı.',
      );
    }
    final groups = <List<CanonicalTelemetryPoint>>[];
    if (record.points.any(
          (p) =>
              !p.speedMps.isFinite ||
              !p.headingDegrees.isFinite ||
              !p.altitudeMeters.isFinite ||
              !p.accuracyMeters.isFinite ||
              !p.distanceFromPreviousMeters.isFinite ||
              p.distanceFromPreviousMeters < 0 ||
              !p.accelerationMps2.isFinite ||
              p.gapDurationMicros < 0,
        ) ||
        [
          for (var i = 1; i < record.points.length; i++)
            record.points[i].timestamp.isAfter(record.points[i - 1].timestamp),
        ].contains(false)) {
      return const PlanetSegmentPreview(
        [],
        'GPS metadata’sı doğrulanamadı; yayın hazırlama durduruldu.',
      );
    }
    var current = <CanonicalTelemetryPoint>[];
    void finish() {
      if (current.isNotEmpty) groups.add(current);
      current = [];
    }

    for (final p in record.points) {
      if (!DriveTimeAnalysis.validPoint(p)) {
        finish();
        continue;
      }
      if (current.isNotEmpty &&
          !DriveTimeAnalysis.reliableInterval(current.last, p)) {
        finish();
      }
      current.add(p);
    }
    finish();
    final originalTiming = DriveTimeAnalysis.fromRecord(record).timingKnown;
    final segments = <PlanetSegment>[];
    for (var i = 0; i < groups.length; i++) {
      final points = List<CanonicalTelemetryPoint>.unmodifiable(groups[i]);
      // Segment bounds are observed sample bounds, not inferred drive stop time.
      final analysis = DriveTimeAnalysis.analyze(
        points,
        metadata: originalTiming
            ? {
                'startedAtMicros':
                    points.first.timestamp.microsecondsSinceEpoch,
                'stopRequestedAtMicros':
                    points.last.timestamp.microsecondsSinceEpoch,
              }
            : const {},
      );
      int? score;
      if (analysis.scoreEligible &&
          points.every(
            (p) =>
                p.speedSource != 'legacy' && DriveTimeAnalysis.reliableSpeed(p),
          )) {
        score = const DriveScoreCalculator()
            .calculateReliable(telemetry: points)
            .displayScore;
      }
      final distance = analysis.distanceMeters;
      final reason = points.length < 2
          ? 'Yeterli GPS geometrisi yok.'
          : distance < MyWorldRules.minimumValidDistanceMeters
          ? 'Bu parça minimum 5 km şartını karşılamıyor.'
          : null;
      // Stable identity; payload immutability is independently checked by outbox.
      final contentHash = sha256
          .convert(
            utf8.encode(
              jsonEncode(points.map(GpsSessionTransfer.pointContent).toList()),
            ),
          )
          .toString();
      final id =
          '${Uri.encodeComponent(driveId)}:segment:$i:'
          '${points.first.timestamp.microsecondsSinceEpoch}:'
          '${points.last.timestamp.microsecondsSinceEpoch}:'
          'w${MyWorldRules.worldRulesVersion}:g${PlanetSegment.geometryVersion}:$contentHash';
      segments.add(
        PlanetSegment(
          id: id,
          sourceDriveId: driveId,
          order: i,
          points: points,
          distanceMeters: distance,
          score: score,
          reason: reason,
        ),
      );
    }
    return PlanetSegmentPreview(
      List.unmodifiable(segments),
      segments.isEmpty ? 'Güvenilir GPS geometrisi bulunamadı.' : null,
    );
  }
}
