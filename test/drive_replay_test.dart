import 'package:driveit_project/features/drive_replay/drive_replay_controller.dart';
import 'package:driveit_project/features/drive_replay/replay_interpolator.dart';
import 'package:driveit_project/models/drive_session.dart';
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
    controller.setDisplayPlaybackSpeed(5);
    expect(controller.effectivePlaybackMultiplier, 50);
    controller.setDisplayPlaybackSpeed(10);
    expect(controller.effectivePlaybackMultiplier, 100);
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
    expect(fast.frame.speedKmh, closeTo(normal.frame.speedKmh, 0.000001));
    normal.dispose();
    fast.dispose();
  });

  test('100x effective playback can skip directly to completion safely', () {
    final controller = DriveReplayController(drive());
    controller
      ..setDisplayPlaybackSpeed(10)
      ..play()
      ..advance(const Duration(milliseconds: 100));

    expect(controller.effectivePlaybackMultiplier, 100);
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
}
