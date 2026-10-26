import 'package:driveit_project/features/drive_replay/drive_replay_controller.dart';
import 'package:driveit_project/features/drive_replay/replay_interpolator.dart';
import 'package:driveit_project/features/drive_replay/replay_telemetry_adapter.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';

DriveSession drive({
  List<RoutePoint>? route,
  int durationSeconds = 10,
  double averageSpeed = 36,
  double maxSpeed = 80,
}) => DriveSession(
  id: 'replay-test',
  date: DateTime(2026),
  distance: 300,
  durationSeconds: durationSeconds,
  averageSpeed: averageSpeed,
  maxSpeed: maxSpeed,
  mapImagePath: '',
  route:
      route ??
      [
        RoutePoint(latitude: 41, longitude: 29),
        RoutePoint(latitude: 41, longitude: 29.001),
        RoutePoint(latitude: 41, longitude: 29.003),
      ],
);

DriveReplayController canonicalController(Duration duration, {int? samples}) {
  final count = samples ?? (duration == Duration.zero ? 1 : 2);
  final start = DateTime.utc(2026);
  final points = List.generate(count, (index) {
    final elapsed = count == 1
        ? Duration.zero
        : Duration(
            microseconds: (duration.inMicroseconds * index / (count - 1))
                .round(),
          );
    return CanonicalTelemetryPoint(
      latitude: 41,
      longitude: 29 + index / 1000,
      timestamp: start.add(elapsed),
      speedMps: 10,
      headingDegrees: 90,
      altitudeMeters: 0,
      accuracyMeters: 3,
      distanceFromPreviousMeters: index == 0 ? 0 : 100,
      accelerationMps2: 0,
      speedSource: 'native',
    );
  });
  final session = drive(durationSeconds: duration.inSeconds);
  final telemetry = ReplayTelemetryAdapter.build(
    session,
    DriveTelemetryRecord(
      driveSessionId: session.id,
      dataVersion: DriveTelemetryRecord.currentDataVersion,
      createdAt: start,
      points: points,
    ),
  );
  return DriveReplayController(session, telemetry: telemetry);
}

void main() {
  test('interpolates coordinates between route points', () {
    const points = [
      ReplayPoint(
        latitude: 40,
        longitude: 28,
        elapsed: Duration.zero,
        distanceMeters: 0,
        speedKmh: 20,
        heading: 90,
      ),
      ReplayPoint(
        latitude: 42,
        longitude: 30,
        elapsed: Duration(seconds: 10),
        distanceMeters: 100,
        speedKmh: 40,
        heading: 90,
      ),
    ];

    final frame = ReplayInterpolator.frameAt(
      points,
      const Duration(seconds: 5),
    );

    expect(frame.latitude, closeTo(41, 0.000001));
    expect(frame.longitude, closeTo(29, 0.000001));
    expect(frame.distanceMeters, closeTo(50, 0.001));
  });

  test('interpolates heading across north by the shortest angle', () {
    final heading = ReplayInterpolator.interpolateHeading(350, 10, 0.5);
    expect(heading, closeTo(0, 0.000001));
  });

  test('seek is based on elapsed time rather than route index', () {
    final controller = DriveReplayController(drive());

    controller.seek(0.5);

    expect(controller.currentTime, const Duration(seconds: 5));
    // The middle coordinate is reached around one third of the total route
    // distance, so a time-based 50% seek must already be beyond it.
    expect(controller.frame.longitude, greaterThan(29.001));
    expect(controller.frame.longitude, lessThan(29.003));
    controller.dispose();
  });

  test('display speeds map to accelerated replay multipliers', () {
    final controller = DriveReplayController(drive());

    expect(controller.displayPlaybackSpeed, 1);
    expect(controller.effectivePlaybackMultiplier, 10);
    controller.setDisplayPlaybackSpeed(2);
    expect(controller.effectivePlaybackMultiplier, 20);
    controller.setDisplayPlaybackSpeed(3);
    expect(controller.effectivePlaybackMultiplier, 30);
    controller.setDisplayPlaybackSpeed(5);
    expect(controller.effectivePlaybackMultiplier, 50);
    controller.setDisplayPlaybackSpeed(10);
    expect(controller.effectivePlaybackMultiplier, 50);
    controller.dispose();
  });

  test('timeline displays the fixed 1x preview axis', () {
    final controller = DriveReplayController(drive(durationSeconds: 100));
    expect(controller.basePreviewDuration, const Duration(seconds: 10));
    controller.seek(.5);
    expect(controller.previewTime, const Duration(seconds: 5));
    controller.setDisplayPlaybackSpeed(10);
    expect(controller.basePreviewDuration, const Duration(seconds: 10));
    controller.dispose();
  });

  test('accelerated playback does not multiply telemetry speed', () {
    final normal = DriveReplayController(drive());
    final fast = DriveReplayController(drive());
    normal
      ..play()
      ..advance(const Duration(milliseconds: 500));
    fast
      ..setDisplayPlaybackSpeed(5)
      ..play()
      ..advance(const Duration(milliseconds: 100));

    expect(fast.currentTime, normal.currentTime);
    expect(fast.frame.speedKmh, closeTo(normal.frame.speedKmh!, 0.000001));
    normal.dispose();
    fast.dispose();
  });

  test('50x effective playback can skip directly to completion safely', () {
    final controller = DriveReplayController(drive());
    controller
      ..setDisplayPlaybackSpeed(5)
      ..play()
      ..advance(const Duration(milliseconds: 250));

    expect(controller.effectivePlaybackMultiplier, 50);
    expect(controller.currentTime, controller.totalDuration);
    expect(controller.isComplete, isTrue);
    expect(controller.isPlaying, isFalse);
    controller.dispose();
  });

  test('pause freezes replay state', () {
    final controller = DriveReplayController(drive());
    controller
      ..play()
      ..advance(const Duration(milliseconds: 100))
      ..pause();
    final pausedAt = controller.currentTime;

    controller.advance(const Duration(milliseconds: 300));

    expect(controller.currentTime, pausedAt);
    controller.dispose();
  });

  test('changing playback mode preserves the current playhead', () {
    final controller = DriveReplayController(drive());
    controller.play();
    controller.advance(const Duration(milliseconds: 500));
    final beforeChange = controller.currentTime;

    controller.setDisplayPlaybackSpeed(3);
    expect(controller.currentTime, beforeChange);
    expect(controller.effectivePlaybackMultiplier, 30);

    controller.advance(const Duration(milliseconds: 100));
    expect(controller.currentTime, beforeChange + const Duration(seconds: 3));
    controller.dispose();
  });

  test('replay completes and pauses at final timestamp', () {
    final controller = DriveReplayController(drive());
    controller
      ..play()
      ..advance(const Duration(seconds: 20));

    expect(controller.currentTime, controller.totalDuration);
    expect(controller.isComplete, isTrue);
    expect(controller.isPlaying, isFalse);
    controller.dispose();
  });

  test('empty and one-point routes cannot start replay', () {
    final empty = DriveReplayController(drive(route: []));
    final single = DriveReplayController(
      drive(route: [RoutePoint(latitude: 41, longitude: 29)]),
    );

    empty.play();
    single.play();

    expect(empty.canReplay, isFalse);
    expect(single.canReplay, isFalse);
    expect(empty.isPlaying, isFalse);
    expect(single.isPlaying, isFalse);
    empty.dispose();
    single.dispose();
  });

  test(
    'canonical controller uses GPS duration and shared frame for all controls',
    () {
      final session = drive(durationSeconds: 900);
      final base = DateTime.utc(2026);
      CanonicalTelemetryPoint sample(int seconds, double longitude) =>
          CanonicalTelemetryPoint(
            latitude: 41,
            longitude: longitude,
            timestamp: base.add(Duration(seconds: seconds)),
            speedMps: 10,
            headingDegrees: 90,
            altitudeMeters: 0,
            accuracyMeters: 3,
            distanceFromPreviousMeters: seconds == 0 ? 0 : 10,
            accelerationMps2: 0,
            speedSource: 'native',
          );
      final telemetry = ReplayTelemetryAdapter.build(
        session,
        DriveTelemetryRecord(
          driveSessionId: session.id,
          dataVersion: DriveTelemetryRecord.currentDataVersion,
          createdAt: base,
          points: [
            sample(0, 29),
            sample(5, 29.001),
            sample(10, 29.002),
            sample(15, 29.003),
            sample(20, 29.004),
          ],
        ),
      );
      final controller = DriveReplayController(session, telemetry: telemetry);
      expect(controller.canReplay, isTrue);
      expect(controller.totalDuration, const Duration(seconds: 20));
      expect(controller.frame.speedKmh, 36);
      controller.setDisplayPlaybackSpeed(5);
      controller.play();
      controller.advance(const Duration(milliseconds: 100));
      expect(controller.currentTime, const Duration(seconds: 5));
      expect(controller.frame.speedKmh, 36);
      controller.pause();
      final paused = controller.frame;
      controller.advance(const Duration(seconds: 5));
      expect(controller.frame, same(paused));
      controller.seek(.5);
      expect(controller.currentTime, const Duration(seconds: 10));
      expect(controller.frame.latitude, closeTo(41, .000001));
      controller.seek(1);
      expect(controller.isComplete, isTrue);
      controller.play();
      expect(controller.currentTime, Duration.zero);
      controller.dispose();
    },
  );

  test('canonical replay with unavailable speed keeps null in the frame', () {
    final session = drive();
    final base = DateTime.utc(2026);
    final points = [0, 2]
        .map(
          (second) => CanonicalTelemetryPoint(
            latitude: 41,
            longitude: 29 + second / 1000,
            timestamp: base.add(Duration(seconds: second)),
            speedMps: 0,
            headingDegrees: 0,
            altitudeMeters: 0,
            accuracyMeters: 3,
            distanceFromPreviousMeters: 10,
            accelerationMps2: 0,
            speedSource: 'unavailable',
          ),
        )
        .toList();
    final telemetry = ReplayTelemetryAdapter.build(
      session,
      DriveTelemetryRecord(
        driveSessionId: session.id,
        dataVersion: DriveTelemetryRecord.currentDataVersion,
        createdAt: base,
        points: points,
      ),
    );
    final controller = DriveReplayController(session, telemetry: telemetry);
    controller.seek(.5);
    expect(controller.frame.speedKmh, isNull);
    controller.dispose();
  });

  test('canonical base multiplier caps base preview at thirty seconds', () {
    final cases = <({Duration drive, double multiplier, Duration preview})>[
      (
        drive: const Duration(minutes: 2),
        multiplier: 10,
        preview: const Duration(seconds: 12),
      ),
      (
        drive: const Duration(minutes: 5),
        multiplier: 10,
        preview: const Duration(seconds: 30),
      ),
      (
        drive: const Duration(minutes: 20),
        multiplier: 40,
        preview: const Duration(seconds: 30),
      ),
      (
        drive: const Duration(minutes: 92, seconds: 14),
        multiplier: (92 * 60 + 14) / 30,
        preview: const Duration(seconds: 30),
      ),
      (
        drive: const Duration(days: 365),
        multiplier: (365 * 24 * 60 * 60) / 30,
        preview: const Duration(seconds: 30),
      ),
    ];
    for (final testCase in cases) {
      final controller = canonicalController(testCase.drive);
      expect(controller.isCanonical, isTrue);
      expect(
        controller.basePlaybackMultiplier,
        closeTo(testCase.multiplier, 1e-9),
      );
      expect(
        controller.effectivePlaybackMultiplier,
        closeTo(testCase.multiplier, 1e-9),
      );
      expect(controller.basePreviewDuration, testCase.preview);
      controller.dispose();
    }
  });

  test('canonical selected speeds are relative to the adaptive base', () {
    final controller = canonicalController(const Duration(minutes: 20));
    final expectedDurations = [
      const Duration(seconds: 30),
      const Duration(seconds: 15),
      const Duration(seconds: 10),
      const Duration(seconds: 6),
    ];
    for (final (index, speed) in [1.0, 2.0, 3.0, 5.0].indexed) {
      controller.setDisplayPlaybackSpeed(speed);
      expect(controller.effectivePlaybackMultiplier, 40 * speed);
      expect(controller.selectedPreviewDuration, expectedDurations[index]);
    }
    controller
      ..setDisplayPlaybackSpeed(5)
      ..seek(.5);
    expect(controller.selectedPreviewTime, const Duration(seconds: 3));
    controller.dispose();
  });

  test('canonical very short and zero-duration timelines stay safe', () {
    final veryShort = canonicalController(const Duration(microseconds: 1));
    expect(veryShort.isCanonical, isTrue);
    expect(veryShort.canReplay, isTrue);
    expect(veryShort.basePlaybackMultiplier, 10);
    expect(veryShort.basePreviewDuration, const Duration(microseconds: 1));
    veryShort
      ..play()
      ..advance(const Duration(microseconds: 1));
    expect(veryShort.isComplete, isTrue);
    veryShort.dispose();

    final zero = canonicalController(Duration.zero);
    expect(zero.isCanonical, isTrue);
    expect(zero.canReplay, isFalse);
    expect(zero.basePlaybackMultiplier, 10);
    expect(zero.basePreviewDuration, Duration.zero);
    zero
      ..play()
      ..advance(const Duration(seconds: 1));
    expect(zero.isPlaying, isFalse);
    expect(zero.isComplete, isFalse);
    zero.dispose();
  });

  test(
    'invalid legacy duration remains unavailable without negative preview',
    () {
      final invalid = DriveReplayController(drive(durationSeconds: -1));
      expect(invalid.isCanonical, isFalse);
      expect(invalid.canReplay, isFalse);
      expect(invalid.basePlaybackMultiplier, 10);
      expect(invalid.basePreviewDuration, Duration.zero);
      expect(invalid.previewTime, Duration.zero);
      invalid.dispose();
    },
  );

  test('canonical large timer delta completes without duration overflow', () {
    final controller = canonicalController(const Duration(days: 365));
    controller
      ..play()
      ..advance(const Duration(days: 100));
    expect(controller.currentTime, controller.totalDuration);
    expect(controller.isComplete, isTrue);
    expect(controller.isPlaying, isFalse);
    controller.dispose();
  });

  test('legacy durations and preview speed mapping remain unchanged', () {
    final controller = DriveReplayController(drive(durationSeconds: 1200));
    expect(controller.isCanonical, isFalse);
    expect(controller.basePlaybackMultiplier, 10);
    expect(controller.basePreviewDuration, const Duration(minutes: 2));
    for (final (speed, effective) in [
      (1.0, 10.0),
      (2.0, 20.0),
      (3.0, 30.0),
      (5.0, 50.0),
    ]) {
      controller.setDisplayPlaybackSpeed(speed);
      expect(controller.effectivePlaybackMultiplier, effective);
    }
    controller.dispose();
  });
}
