import '../../models/canonical_telemetry_point.dart';
import '../../models/drive_session.dart';
import '../../services/drive_time_analysis.dart';
import '../../services/gps_gap_policy.dart';

enum ReplayTelemetrySource { canonical, legacy }

/// Native means GPS-sourced canonical processing, not an untouched sensor value.
enum ReplaySpeedSource { nativeCanonical, geometryEstimate, unavailable }

enum ReplayTelemetryIssue {
  missingRecord,
  unsupportedVersion,
  driveIdMismatch,
  emptyCanonical,
  invalidCoordinate,
  invalidAccuracy,
  nonIncreasingTime,
  invalidSpeed,
  unknownSpeedSource,
  recordedBreak,
  recordedGap,
  sampleGap,
  unreliableInterval,
}

class ReplayTelemetryDiagnostic {
  final ReplayTelemetryIssue issue;
  final int? sourceIndex;

  const ReplayTelemetryDiagnostic(this.issue, [this.sourceIndex]);
}

/// An immutable value snapshot; contains no Hive objects or mutable coordinates.
class ReplayTelemetrySample {
  final int sourceIndex;
  final int segmentId;
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  /// Time from the first accepted GPS sample, including unobserved gaps.
  /// Null for legacy geometry; never derived from the drive summary.
  final Duration? elapsed;
  final double? speedKmh;
  final ReplaySpeedSource speedSource;
  final String? recordedSpeedSource;

  /// Null means the incoming interval is unknown (also true for the first point).
  final double? distanceIncrementMeters;

  /// Sum of accepted increments only, not a claim of full drive coverage.
  final double cumulativeDistanceMeters;
  final bool breakBefore;

  /// Recorded gap duration when present, otherwise the time between accepted
  /// samples at a boundary. Null means no duration is known (legacy included).
  final Duration? gapDuration;
  final List<ReplayTelemetryIssue> boundaryReasons;

  ReplayTelemetrySample({
    required this.sourceIndex,
    required this.segmentId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.elapsed,
    required this.speedKmh,
    required this.speedSource,
    required this.recordedSpeedSource,
    required this.distanceIncrementMeters,
    required this.cumulativeDistanceMeters,
    required this.breakBefore,
    required this.gapDuration,
    required List<ReplayTelemetryIssue> boundaryReasons,
  }) : boundaryReasons = List.unmodifiable(boundaryReasons);
}

class ReplayTelemetryData {
  final ReplayTelemetrySource source;
  final List<ReplayTelemetrySample> samples;
  final List<ReplayTelemetryDiagnostic> diagnostics;

  ReplayTelemetryData({
    required this.source,
    required List<ReplayTelemetrySample> samples,
    required List<ReplayTelemetryDiagnostic> diagnostics,
  }) : samples = List.unmodifiable(samples),
       diagnostics = List.unmodifiable(diagnostics);
}

/// A replay-only speed peak tied to an accepted, timestamped GPS sample.
/// This value is derived from an immutable adapter snapshot and never persisted.
class ReplayMaximumSpeedEvent {
  final int sourceIndex;
  final int segmentId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final Duration elapsed;
  final double speedKmh;
  final ReplaySpeedSource speedSource;
  final List<ReplayTelemetryIssue> quality;

  ReplayMaximumSpeedEvent({
    required this.sourceIndex,
    required this.segmentId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.elapsed,
    required this.speedKmh,
    required this.speedSource,
    required List<ReplayTelemetryIssue> quality,
  }) : quality = List.unmodifiable(quality);

  bool get isEstimated => speedSource == ReplaySpeedSource.geometryEstimate;
}

/// Resolves native peaks before estimated peaks. Ties retain the earliest
/// accepted sample in recording order, making the result deterministic.
ReplayMaximumSpeedEvent? replayMaximumSpeedEvent(ReplayTelemetryData data) {
  if (data.source != ReplayTelemetrySource.canonical) return null;

  ReplayMaximumSpeedEvent? maximumFor(ReplaySpeedSource source) {
    ReplayMaximumSpeedEvent? maximum;
    for (final sample in data.samples) {
      final speed = sample.speedKmh;
      final time = sample.timestamp;
      final elapsed = sample.elapsed;
      if (sample.speedSource != source ||
          sample.breakBefore ||
          sample.boundaryReasons.isNotEmpty ||
          speed == null ||
          !speed.isFinite ||
          speed <= 0 ||
          time == null ||
          elapsed == null) {
        continue;
      }
      if (maximum == null || speed > maximum.speedKmh) {
        maximum = ReplayMaximumSpeedEvent(
          sourceIndex: sample.sourceIndex,
          segmentId: sample.segmentId,
          latitude: sample.latitude,
          longitude: sample.longitude,
          timestamp: time,
          elapsed: elapsed,
          speedKmh: speed,
          speedSource: source,
          quality: sample.boundaryReasons,
        );
      }
    }
    return maximum;
  }

  return maximumFor(ReplaySpeedSource.nativeCanonical) ??
      maximumFor(ReplaySpeedSource.geometryEstimate);
}

/// Pure conversion only. The caller MUST supply a drive and record read through
/// the same currently authorized owner lease and discard results on revocation.
/// The models contain no owner ID, so ownership cannot be verified here.
/// No storage, journal, recovery, global fallback or interpolation is performed.
/// Input timestamps are already non-null DateTimes. Parsing/defaulting losses
/// in older writers cannot be recovered; only ordering is checked here.
class ReplayTelemetryAdapter {
  const ReplayTelemetryAdapter._();

  static ReplayTelemetryData build(
    DriveSession drive,
    DriveTelemetryRecord? record,
  ) {
    final diagnostics = <ReplayTelemetryDiagnostic>[];
    if (record == null) {
      diagnostics.add(
        const ReplayTelemetryDiagnostic(ReplayTelemetryIssue.missingRecord),
      );
    } else if (record.driveSessionId != drive.id) {
      diagnostics.add(
        const ReplayTelemetryDiagnostic(ReplayTelemetryIssue.driveIdMismatch),
      );
    } else if (record.dataVersion != DriveTelemetryRecord.currentDataVersion) {
      diagnostics.add(
        const ReplayTelemetryDiagnostic(
          ReplayTelemetryIssue.unsupportedVersion,
        ),
      );
    } else {
      final samples = <ReplayTelemetrySample>[];
      final pending = <ReplayTelemetryIssue>{};
      DateTime? highestTime;
      DateTime? origin;
      var segment = 0;
      var cumulative = 0.0;
      for (var i = 0; i < record.points.length; i++) {
        final point = record.points[i];
        final reasons = <ReplayTelemetryIssue>{...pending};
        void flag(ReplayTelemetryIssue issue) {
          reasons.add(issue);
          diagnostics.add(ReplayTelemetryDiagnostic(issue, i));
        }

        if (point.breakBefore) flag(ReplayTelemetryIssue.recordedBreak);
        if (point.gapDurationMicros != 0) {
          flag(ReplayTelemetryIssue.recordedGap);
        }
        final invalidTime =
            highestTime != null && !point.timestamp.isAfter(highestTime);
        if (invalidTime) flag(ReplayTelemetryIssue.nonIncreasingTime);
        if (highestTime == null || point.timestamp.isAfter(highestTime)) {
          highestTime = point.timestamp;
        }
        if (!point.hasValidCoordinate) {
          flag(ReplayTelemetryIssue.invalidCoordinate);
        } else if (!DriveTimeAnalysis.validPoint(point)) {
          flag(ReplayTelemetryIssue.invalidAccuracy);
        }
        if (invalidTime || !DriveTimeAnalysis.validPoint(point)) {
          pending.addAll(reasons);
          continue;
        }
        final previous = samples.isEmpty ? null : samples.last;
        final delta = previous == null
            ? null
            : point.timestamp.difference(previous.timestamp!);
        if (delta != null && delta > GpsGapPolicy.shortGap) {
          flag(ReplayTelemetryIssue.sampleGap);
        }
        double? increment;
        if (previous != null && reasons.isEmpty) {
          // Use original adjacency: skipped samples never create new intervals.
          if (previous.sourceIndex == i - 1 &&
              DriveTimeAnalysis.reliableInterval(record.points[i - 1], point)) {
            increment = point.distanceFromPreviousMeters;
            cumulative += increment;
          } else {
            flag(ReplayTelemetryIssue.unreliableInterval);
          }
        }
        if (previous != null && reasons.isNotEmpty) segment++;
        var speedSource = ReplaySpeedSource.unavailable;
        double? speed;
        if (!DriveTimeAnalysis.reliableSpeed(point)) {
          diagnostics.add(
            ReplayTelemetryDiagnostic(ReplayTelemetryIssue.invalidSpeed, i),
          );
        } else if (point.speedSource == 'native') {
          speedSource = ReplaySpeedSource.nativeCanonical;
          speed = point.speedMps * 3.6;
        } else if (point.speedSource == 'geometry_estimate') {
          speedSource = ReplaySpeedSource.geometryEstimate;
          speed = point.speedMps * 3.6;
        } else {
          diagnostics.add(
            ReplayTelemetryDiagnostic(
              ReplayTelemetryIssue.unknownSpeedSource,
              i,
            ),
          );
        }
        origin ??= point.timestamp;
        samples.add(
          ReplayTelemetrySample(
            sourceIndex: i,
            segmentId: segment,
            latitude: point.latitude,
            longitude: point.longitude,
            timestamp: point.timestamp,
            elapsed: point.timestamp.difference(origin),
            speedKmh: speed,
            speedSource: speedSource,
            recordedSpeedSource: point.speedSource,
            distanceIncrementMeters: increment,
            cumulativeDistanceMeters: cumulative,
            breakBefore: reasons.isNotEmpty,
            gapDuration: point.gapDurationMicros > 0
                ? Duration(microseconds: point.gapDurationMicros)
                : (reasons.isNotEmpty && delta != null ? delta : null),
            boundaryReasons: reasons.toList(),
          ),
        );
        pending.clear();
      }
      if (samples.isNotEmpty) {
        return ReplayTelemetryData(
          source: ReplayTelemetrySource.canonical,
          samples: samples,
          diagnostics: diagnostics,
        );
      }
      diagnostics.add(
        const ReplayTelemetryDiagnostic(ReplayTelemetryIssue.emptyCanonical),
      );
    }
    return _legacy(drive, diagnostics);
  }

  static ReplayTelemetryData _legacy(
    DriveSession drive,
    List<ReplayTelemetryDiagnostic> diagnostics,
  ) {
    final samples = <ReplayTelemetrySample>[];
    var segment = 0;
    final pending = <ReplayTelemetryIssue>{};
    for (var i = 0; i < drive.route.length; i++) {
      final point = drive.route[i];
      if (point.breakBefore) pending.add(ReplayTelemetryIssue.recordedBreak);
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180) {
        pending.add(ReplayTelemetryIssue.invalidCoordinate);
        diagnostics.add(
          ReplayTelemetryDiagnostic(ReplayTelemetryIssue.invalidCoordinate, i),
        );
        continue;
      }
      if (samples.isNotEmpty && pending.isNotEmpty) segment++;
      samples.add(
        ReplayTelemetrySample(
          sourceIndex: i,
          segmentId: segment,
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: null,
          elapsed: null,
          speedKmh: null,
          speedSource: ReplaySpeedSource.unavailable,
          recordedSpeedSource: null,
          distanceIncrementMeters: null,
          cumulativeDistanceMeters: 0,
          breakBefore: pending.isNotEmpty,
          gapDuration: null,
          boundaryReasons: pending.toList(),
        ),
      );
      pending.clear();
    }
    return ReplayTelemetryData(
      source: ReplayTelemetrySource.legacy,
      samples: samples,
      diagnostics: diagnostics,
    );
  }
}
