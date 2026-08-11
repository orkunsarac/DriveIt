import 'package:driveit_project/models/drive_telemetry_sample.dart';
import 'package:driveit_project/services/drive_telemetry_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = DriveTelemetryAnalyzer();
  final start = DateTime(2026, 1, 1, 12);

  DriveTelemetrySample sample(
    int second,
    double speedKmh, {
    double accuracy = 5,
    double heading = 0,
    double altitude = 100,
  }) => DriveTelemetrySample(
    latitude: 41 + second * .00001,
    longitude: 29,
    speedMps: speedKmh / 3.6,
    accuracyMeters: accuracy,
    heading: heading,
    altitudeMeters: altitude,
    timestamp: start.add(Duration(seconds: second)),
  );

  test('calculates acceleration and G from speed difference', () {
    final metrics = analyzer.analyze([
      sample(0, 0),
      sample(1, 7.2),
      sample(2, 14.4),
      sample(3, 21.6),
    ]);

    expect(metrics.maxAccelerationG, closeTo(2 / 9.81, .03));
  });

  test('counts sustained hard acceleration and braking once per event', () {
    final metrics = analyzer.analyze([
      sample(0, 0),
      sample(1, 10.8),
      sample(2, 21.6),
      sample(3, 32.4),
      sample(4, 32.4),
      sample(5, 21.6),
      sample(6, 10.8),
      sample(7, 0),
    ]);

    expect(metrics.hardAccelerationCount, 1);
    expect(metrics.hardBrakeCount, 1);
  });

  test('filters samples with poor GPS accuracy', () {
    final metrics = analyzer.analyze([
      sample(0, 0),
      sample(1, 100, accuracy: 80),
      sample(2, 0),
    ]);

    expect(metrics.maxAccelerationG, 0);
    expect(metrics.bestZeroToHundredSeconds, isNull);
  });

  test('rejects physically impossible speed jumps', () {
    final metrics = analyzer.analyze([
      sample(0, 0),
      sample(1, 180),
      sample(2, 0),
    ]);

    expect(metrics.hardAccelerationCount, 0);
    expect(metrics.bestZeroToHundredSeconds, isNull);
  });

  test('rejects impossible coordinate jumps before altitude analysis', () {
    final jumped = DriveTelemetrySample(
      latitude: 42,
      longitude: 30,
      speedMps: 10,
      accuracyMeters: 5,
      heading: 20,
      altitudeMeters: 900,
      timestamp: start.add(const Duration(seconds: 1)),
    );
    final metrics = analyzer.analyze([
      sample(0, 36, altitude: 100),
      jumped,
      sample(2, 36, altitude: 102),
    ]);

    expect(metrics.maxAltitude, 102);
  });

  test('treats low speed GPS jitter as stationary', () {
    final metrics = analyzer.analyze([
      sample(0, 0),
      sample(1, 2),
      sample(2, 3),
      sample(3, 1),
    ]);

    expect(metrics.maxAccelerationG, 0);
    expect(metrics.hardAccelerationCount, 0);
  });

  test('heading jitter is not counted as a corner', () {
    final metrics = analyzer.analyze([
      sample(0, 40, heading: 10),
      sample(1, 40, heading: 11),
      sample(2, 40, heading: 9),
      sample(3, 40, heading: 11),
    ]);

    expect(metrics.cornerCount, 0);
  });

  test('valid sustained corner is counted once', () {
    final metrics = analyzer.analyze([
      sample(0, 40, heading: 0),
      sample(1, 40, heading: 8),
      sample(2, 40, heading: 17),
      sample(3, 40, heading: 24),
      sample(4, 40, heading: 25),
      sample(5, 40, heading: 25),
    ]);

    expect(metrics.cornerCount, 1);
    expect(metrics.sharpTurnCount, 0);
  });

  test('sharp turn is classified once', () {
    final metrics = analyzer.analyze([
      sample(0, 40, heading: 0),
      sample(1, 40, heading: 20),
      sample(2, 40, heading: 50),
      sample(3, 40, heading: 65),
    ]);

    expect(metrics.cornerCount, 1);
    expect(metrics.sharpTurnCount, 1);
  });

  test('calculates a completed zero to hundred attempt', () {
    final samples = <DriveTelemetrySample>[];
    for (var second = 0; second <= 12; second++) {
      samples.add(sample(second, (second * 10).clamp(0, 110).toDouble()));
    }
    final metrics = analyzer.analyze(samples);

    expect(metrics.bestZeroToHundredSeconds, isNotNull);
    expect(metrics.bestZeroToHundredSeconds!, inInclusiveRange(9, 12));
  });

  test('calculates a completed sixty to hundred attempt', () {
    final samples = <DriveTelemetrySample>[];
    for (var second = 0; second <= 7; second++) {
      samples.add(sample(second, 50 + second * 10));
    }
    final metrics = analyzer.analyze(samples);

    expect(metrics.bestSixtyToHundredSeconds, isNotNull);
    expect(metrics.bestSixtyToHundredSeconds!, inInclusiveRange(3, 6));
  });

  test('keeps acceleration timings nullable when target is not reached', () {
    final metrics = analyzer.analyze([
      sample(0, 0),
      sample(1, 20),
      sample(2, 40),
      sample(3, 60),
    ]);

    expect(metrics.bestZeroToHundredSeconds, isNull);
    expect(metrics.bestSixtyToHundredSeconds, isNull);
  });
}
