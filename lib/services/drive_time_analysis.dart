import '../models/canonical_telemetry_point.dart';
import '../features/drive_score/config/tempo_performance_calibration.dart';
import '../features/drive_score/config/drive_detection_calibration.dart';
import 'canonical_telemetry_pipeline.dart';
import 'gps_gap_policy.dart';

/// Read-only interval accounting. Never changes recorded points or infers
/// session events from DriveSession.date (which is a save date).
class DriveTimeAnalysis {
  const DriveTimeAnalysis({
    required this.totalMicros,
    required this.measuredMicros,
    required this.movingMicros,
    required this.stationaryMicros,
    required this.distanceMeters,
    required this.movingDistanceMeters,
    required this.movingSamples,
    required this.stopCount,
  });
  final int? totalMicros;
  final int measuredMicros, movingMicros, stationaryMicros, movingSamples;
  final int stopCount;
  final double distanceMeters, movingDistanceMeters;
  bool get timingKnown => totalMicros != null && totalMicros! > 0;
  int? get lostMicros => timingKnown ? totalMicros! - measuredMicros : null;
  double? get coverage => timingKnown ? measuredMicros / totalMicros! : null;
  // Integer comparison deliberately avoids rounding 79.99% up to 80%.
  bool get coverageSufficient =>
      timingKnown && measuredMicros * 5 >= totalMicros! * 4;
  bool get movementSufficient =>
      movingSamples >= TempoPerformanceCalibration.minimumReliableSampleCount &&
      movingMicros >=
          TempoPerformanceCalibration.minimumMovingDuration.inMicroseconds;
  bool get scoreEligible => coverageSufficient && movementSufficient;
  bool get partial => timingKnown && measuredMicros < totalMicros!;
  double get averageSpeedKmh =>
      measuredMicros > 0 ? distanceMeters * 3600000 / measuredMicros : 0;
  double get movingAverageSpeedKmh =>
      movingMicros > 0 ? movingDistanceMeters * 3600000 / movingMicros : 0;

  static bool validPoint(CanonicalTelemetryPoint p) =>
      p.hasValidCoordinate &&
      p.accuracyMeters.isFinite &&
      p.accuracyMeters >= 0 &&
      p.accuracyMeters <= CanonicalTelemetryRules.maximumAccuracyMeters;

  static bool reliableSpeed(CanonicalTelemetryPoint p) =>
      p.hasSpeedEvidence &&
      p.speedMps.isFinite &&
      p.speedMps >= 0 &&
      p.speedMps <= CanonicalTelemetryRules.maximumPlausibleSpeedMps;

  static bool reliableInterval(
    CanonicalTelemetryPoint a,
    CanonicalTelemetryPoint b,
  ) {
    final dt = b.timestamp.difference(a.timestamp);
    return validPoint(a) &&
        validPoint(b) &&
        !b.breakBefore &&
        b.gapDurationMicros == 0 &&
        dt.inMicroseconds >=
            (CanonicalTelemetryRules.minimumSampleIntervalSeconds * 1000000)
                .round() &&
        dt <= GpsGapPolicy.breakAfter &&
        b.distanceFromPreviousMeters.isFinite &&
        b.distanceFromPreviousMeters >= 0;
  }

  static bool movingInterval(
    CanonicalTelemetryPoint a,
    CanonicalTelemetryPoint b,
  ) =>
      reliableSpeed(a) &&
      reliableSpeed(b) &&
      a.speedMps > CanonicalTelemetryRules.stationarySpeedMps &&
      b.speedMps > CanonicalTelemetryRules.stationarySpeedMps;

  static bool stationaryInterval(
    CanonicalTelemetryPoint a,
    CanonicalTelemetryPoint b,
  ) =>
      reliableSpeed(a) &&
      reliableSpeed(b) &&
      a.speedMps <= CanonicalTelemetryRules.stationarySpeedMps &&
      b.speedMps <= CanonicalTelemetryRules.stationarySpeedMps;

  static DriveTimeAnalysis fromRecord(DriveTelemetryRecord record) =>
      analyze(record.points, metadata: record.acquisitionMetadata);

  /// Analysis-only boundaries. Preserve every recorded value in storage;
  /// unknown intervals must not bridge derivative/event windows in Score v1.
  static List<CanonicalTelemetryPoint> analysisTimeline(
    List<CanonicalTelemetryPoint> points,
  ) => [
    for (var i = 0; i < points.length; i++)
      if (i == 0 || reliableInterval(points[i - 1], points[i]))
        points[i]
      else
        CanonicalTelemetryPoint(
          latitude: points[i].latitude,
          longitude: points[i].longitude,
          timestamp: points[i].timestamp,
          speedMps: points[i].speedMps,
          headingDegrees: points[i].headingDegrees,
          altitudeMeters: points[i].altitudeMeters,
          accuracyMeters: points[i].accuracyMeters,
          distanceFromPreviousMeters: 0,
          accelerationMps2: 0,
          breakBefore: true,
          gapDurationMicros: points[i].gapDurationMicros,
          speedSource: points[i].speedSource,
          accelerationReliable: false,
        ),
  ];

  static bool continuousSpan(
    int start,
    int end,
    CanonicalTelemetryPoint Function(int) pointAt,
  ) {
    for (var i = start + 1; i <= end; i++) {
      if (!reliableInterval(pointAt(i - 1), pointAt(i)) ||
          !reliableSpeed(pointAt(i - 1)) ||
          !reliableSpeed(pointAt(i))) {
        return false;
      }
    }
    return true;
  }

  static DriveTimeAnalysis analyze(
    List<CanonicalTelemetryPoint> points, {
    Map<String, dynamic> metadata = const {},
  }) {
    final start = metadata['startedAtMicros'];
    final end = metadata['stopRequestedAtMicros'];
    final known = start is int && end is int && end > start;
    var measured = 0, moving = 0, stationary = 0, stops = 0, stopRun = 0;
    var stopRegistered = false;
    var distance = 0.0, movingDistance = 0.0;
    final movingIndices = <int>{};
    var ordered = true;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (!b.timestamp.isAfter(a.timestamp)) ordered = false;
      if (!reliableInterval(a, b) ||
          (known &&
              (a.timestamp.microsecondsSinceEpoch < start ||
                  b.timestamp.microsecondsSinceEpoch > end))) {
        stopRun = 0;
        stopRegistered = false;
        continue;
      }
      final dt = b.timestamp.difference(a.timestamp).inMicroseconds;
      measured += dt;
      distance += b.distanceFromPreviousMeters;
      if (movingInterval(a, b)) {
        moving += dt;
        movingDistance += b.distanceFromPreviousMeters;
        movingIndices.addAll([i - 1, i]);
      }
      if (stationaryInterval(a, b)) {
        stationary += dt;
        stopRun += dt;
        if (!stopRegistered &&
            stopRun >=
                DriveDetectionCalibration
                    .stoppedMinimumDuration
                    .inMicroseconds) {
          stops++;
          stopRegistered = true;
        }
      } else {
        stopRun = 0;
        stopRegistered = false;
      }
    }
    // Non-monotonic input must never claim more coverage than the session.
    final total = known && ordered && measured <= end - start
        ? end - start
        : null;
    return DriveTimeAnalysis(
      totalMicros: total,
      measuredMicros: measured,
      movingMicros: moving,
      stationaryMicros: stationary,
      distanceMeters: distance,
      movingDistanceMeters: movingDistance,
      movingSamples: movingIndices.length,
      stopCount: stops,
    );
  }
}
