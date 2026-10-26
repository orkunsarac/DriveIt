import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/drive_session.dart';
import 'replay_interpolator.dart';
import 'replay_telemetry_adapter.dart';

class DriveReplayController extends ChangeNotifier {
  static const Duration canonicalPreviewTarget = Duration(seconds: 30);
  static const double _minimumBasePlaybackMultiplier = 10;

  final DriveSession drive;
  final ReplayTelemetryData? telemetry;
  late final ReplayMaximumSpeedEvent? maximumSpeedEvent;
  late final List<ReplayPoint> timeline;
  late ReplayFrame _frame;

  /// Changes only on explicit controls or playback completion. The map keeps
  /// listening to frame notifications; the HUD uses this plus its 250 ms poll.
  final ValueNotifier<int> hudRevision = ValueNotifier<int>(0);

  bool _isPlaying = false;
  bool _isComplete = false;
  double _displayPlaybackSpeed = 1;

  DriveReplayController(this.drive, {this.telemetry}) {
    timeline = ReplayInterpolator.buildTimeline(drive);
    maximumSpeedEvent = isCanonical
        ? replayMaximumSpeedEvent(telemetry!)
        : null;
    _frame = _frameAt(Duration.zero);
  }

  bool get canReplay =>
      (isCanonical ? telemetry!.samples.length >= 2 : timeline.length >= 2) &&
      totalDuration > Duration.zero;
  bool get isCanonical => telemetry?.source == ReplayTelemetrySource.canonical;
  bool get isPlaying => _isPlaying;
  bool get isComplete => _isComplete;
  double get displayPlaybackSpeed => _displayPlaybackSpeed;
  double get basePlaybackMultiplier {
    if (!isCanonical || totalDuration <= Duration.zero) {
      return _minimumBasePlaybackMultiplier;
    }
    final durationMicros = totalDuration.inMicroseconds.toDouble();
    final targetMicros = canonicalPreviewTarget.inMicroseconds.toDouble();
    final previewMultiplier = durationMicros / targetMicros;
    if (!previewMultiplier.isFinite) {
      return _minimumBasePlaybackMultiplier;
    }
    return math
        .max(_minimumBasePlaybackMultiplier, previewMultiplier)
        .toDouble();
  }

  double get effectivePlaybackMultiplier =>
      basePlaybackMultiplier * _displayPlaybackSpeed;
  ReplayFrame get frame => _frame;
  Duration get currentTime => _frame.elapsed;
  Duration get totalDuration => isCanonical
      ? telemetry!.samples.last.elapsed ?? Duration.zero
      : Duration(seconds: drive.durationSeconds);

  ReplayFrame _frameAt(Duration elapsed) => isCanonical
      ? ReplayInterpolator.frameAtTelemetry(telemetry!, elapsed)
      : ReplayInterpolator.frameAt(timeline, elapsed);

  /// The preview axis is distinct from recorded GPS time. Canonical drives
  /// target 30 seconds at the base rate, without ever slowing below the
  /// existing 10x baseline. Legacy drives retain their fixed 10x baseline.
  Duration get basePreviewDuration =>
      _durationOnPreviewAxis(totalDuration.inMicroseconds);
  Duration get previewTime =>
      _durationOnPreviewAxis(currentTime.inMicroseconds);
  Duration get selectedPreviewDuration => _durationAtMultiplier(
    totalDuration.inMicroseconds,
    effectivePlaybackMultiplier,
  );
  Duration get selectedPreviewTime => _durationAtMultiplier(
    currentTime.inMicroseconds,
    effectivePlaybackMultiplier,
  );

  Duration _durationOnPreviewAxis(int recordedMicros) {
    return _durationAtMultiplier(recordedMicros, basePlaybackMultiplier);
  }

  Duration _durationAtMultiplier(int recordedMicros, double multiplier) {
    if (recordedMicros <= 0) return Duration.zero;
    final scaled = (recordedMicros / multiplier).round();
    return Duration(microseconds: scaled.clamp(1, recordedMicros).toInt());
  }

  double get progress {
    final total = totalDuration.inMicroseconds;
    return total <= 0
        ? 0
        : (_frame.elapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }

  void play() {
    if (!canReplay) return;
    if (_isComplete) seek(0);
    _isPlaying = true;
    _isComplete = false;
    _refreshHudImmediately();
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _refreshHudImmediately();
    notifyListeners();
  }

  void setDisplayPlaybackSpeed(double value) {
    if (!const [1.0, 2.0, 3.0, 5.0].contains(value)) return;
    _displayPlaybackSpeed = value;
    _refreshHudImmediately();
    notifyListeners();
  }

  void seek(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final target = Duration(
      microseconds: (totalDuration.inMicroseconds * clamped).round(),
    );
    _frame = _frameAt(target);
    _isComplete = clamped >= 1;
    if (_isComplete) _isPlaying = false;
    _refreshHudImmediately();
    notifyListeners();
  }

  void advance(Duration realDelta) {
    if (!_isPlaying || !canReplay || realDelta <= Duration.zero) return;
    final totalMicros = totalDuration.inMicroseconds;
    final currentMicros = _frame.elapsed.inMicroseconds;
    final remainingMicros = totalMicros - currentMicros;
    if (remainingMicros <= 0) {
      _completeAtEnd();
      return;
    }

    final scaledMicros =
        realDelta.inMicroseconds.toDouble() * effectivePlaybackMultiplier;
    if (!scaledMicros.isFinite || scaledMicros >= remainingMicros.toDouble()) {
      _completeAtEnd();
      return;
    }
    final deltaMicros = scaledMicros.round();
    if (deltaMicros <= 0) return;
    final nextMicros = currentMicros + deltaMicros;
    if (nextMicros >= totalMicros) {
      _completeAtEnd();
    } else {
      _frame = _frameAt(Duration(microseconds: nextMicros));
      notifyListeners();
    }
  }

  void _completeAtEnd() {
    _frame = _frameAt(totalDuration);
    _isPlaying = false;
    _isComplete = true;
    _refreshHudImmediately();
    notifyListeners();
  }

  void _refreshHudImmediately() => hudRevision.value++;

  @override
  void dispose() {
    hudRevision.dispose();
    super.dispose();
  }
}
