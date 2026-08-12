import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/canonical_telemetry_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 8, 11, 12);

  RawTelemetryInput input({
    required int milliseconds,
    double latitude = 41,
    double longitude = 29,
    double speedMps = 0,
    double accuracy = 5,
    double heading = 0,
    DateTime? timestamp,
  }) => RawTelemetryInput(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? start.add(Duration(milliseconds: milliseconds)),
    speedMps: speedMps,
    headingDegrees: heading,
    altitudeMeters: 100,
    accuracyMeters: accuracy,
  );

  test('rejects missing timestamps without crashing', () {
    final pipeline = CanonicalTelemetryPipeline();

    final result = pipeline.add(
      const RawTelemetryInput(
        latitude: 41,
        longitude: 29,
        timestamp: null,
        speedMps: 0,
        headingDegrees: 0,
        altitudeMeters: 0,
        accuracyMeters: 5,
      ),
    );

    expect(result, isNull);
  });

  test('rejects poor accuracy samples', () {
    final pipeline = CanonicalTelemetryPipeline();

    expect(pipeline.add(input(milliseconds: 0, accuracy: 80)), isNull);
  });

  test('single native speed spike does not change canonical speed', () {
    final pipeline = CanonicalTelemetryPipeline();
    pipeline.add(input(milliseconds: 0));
    pipeline.add(input(milliseconds: 1000));

    final spike = pipeline.add(input(milliseconds: 2000, speedMps: 60));

    expect(spike, isNotNull);
    expect(spike!.speedMps, 0);
    expect(spike.accelerationMps2, 0);
  });

  test('stationary GPS drift does not add distance', () {
    final pipeline = CanonicalTelemetryPipeline();
    pipeline.add(input(milliseconds: 0));

    final drift = pipeline.add(
      input(milliseconds: 1000, latitude: 41.000045, speedMps: 0),
    );

    expect(drift, isNotNull);
    expect(drift!.distanceFromPreviousMeters, 0);
  });

  test('acceleration uses the real timestamp delta', () {
    final pipeline = CanonicalTelemetryPipeline();
    pipeline.add(input(milliseconds: 0));
    final second = pipeline.add(
      input(milliseconds: 1000, latitude: 41.000018, speedMps: 2),
    );
    final third = pipeline.add(
      input(milliseconds: 2000, latitude: 41.000054, speedMps: 4),
    );

    expect(second, isNotNull);
    expect(third, isNotNull);
    expect(second!.accelerationMps2, closeTo(1, .05));
    expect(third!.accelerationMps2, closeTo(1, .05));
  });

  test('low-speed invalid heading keeps the previous stable heading', () {
    final pipeline = CanonicalTelemetryPipeline();
    final first = pipeline.add(input(milliseconds: 0, heading: 42));
    final stopped = pipeline.add(
      input(milliseconds: 1000, heading: double.nan),
    );

    expect(first, isNotNull);
    expect(stopped, isNotNull);
    expect(stopped!.headingDegrees, first!.headingDegrees);
  });

  test('same input produces deterministic canonical output', () {
    List<double> run() {
      final pipeline = CanonicalTelemetryPipeline();
      return [
            input(milliseconds: 0),
            input(
              milliseconds: 1000,
              latitude: 41.000018,
              speedMps: 2,
              heading: 20,
            ),
            input(
              milliseconds: 2000,
              latitude: 41.000054,
              speedMps: 4,
              heading: 30,
            ),
          ]
          .map(pipeline.add)
          .whereType<CanonicalTelemetryPoint>()
          .expand(
            (point) => [
              point.speedMps,
              point.accelerationMps2,
              point.distanceFromPreviousMeters,
              point.headingDegrees,
            ],
          )
          .toList();
    }

    expect(run(), run());
  });
}
