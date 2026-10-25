import 'package:flutter/foundation.dart';

import '../../models/drive_session.dart';
import 'replay_interpolator.dart';
import 'replay_telemetry_adapter.dart';

class DriveReplayController extends ChangeNotifier {
  final DriveSession drive;
  final ReplayTelemetryData? telemetry;
  late final List<ReplayPoint> timeline;
  late ReplayFrame _frame;

  bool _isPlaying = false;
  bool _isComplete = false;
  double _displayPlaybackSpeed = 1;

  DriveReplayController(this.drive, {this.telemetry}) {
    timeline = ReplayInterpolator.buildTimeline(drive);
    _frame = _frameAt(Duration.zero);
  }

  bool get canReplay =>
      (isCanonical ? telemetry!.samples.length >= 2 : timeline.length >= 2) &&
      totalDuration > Duration.zero;
  bool get isCanonical => telemetry?.source == ReplayTelemetrySource.canonical;
  bool get isPlaying => _isPlaying;
  bool get isComplete => _isComplete;
  double get displayPlaybackSpeed => _displayPlaybackSpeed;
  double get effectivePlaybackMultiplier => switch (_displayPlaybackSpeed) {
    1 => 10,
    2 => 20,
    5 => 50,
    10 => 100,
    _ => 10,
  };
  ReplayFrame get frame => _frame;
  Duration get currentTime => _frame.elapsed;
  Duration get totalDuration => isCanonical
      ? telemetry!.samples.last.elapsed ?? Duration.zero
      : Duration(seconds: drive.durationSeconds);

  ReplayFrame _frameAt(Duration elapsed) => isCanonical
      ? ReplayInterpolator.frameAtTelemetry(telemetry!, elapsed)
      : ReplayInterpolator.frameAt(timeline, elapsed);

  /// The timeline is presented on the 1x preview axis (10x real playback).
  Duration get basePreviewDuration =>
      Duration(microseconds: (totalDuration.inMicroseconds / 10).round());
  Duration get previewTime =>
      Duration(microseconds: (currentTime.inMicroseconds / 10).round());
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
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }

  void setDisplayPlaybackSpeed(double value) {
    if (!const [1.0, 2.0, 5.0, 10.0].contains(value)) return;
    _displayPlaybackSpeed = value;
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
    notifyListeners();
  }

  void advance(Duration realDelta) {
    if (!_isPlaying || !canReplay || realDelta <= Duration.zero) return;
    final playbackDelta = Duration(
      microseconds: (realDelta.inMicroseconds * effectivePlaybackMultiplier)
          .round(),
    );
    final next = _frame.elapsed + playbackDelta;
    if (next >= totalDuration) {
      _frame = _frameAt(totalDuration);
      _isPlaying = false;
      _isComplete = true;
    } else {
      _frame = _frameAt(next);
    }
    notifyListeners();
  }
}
