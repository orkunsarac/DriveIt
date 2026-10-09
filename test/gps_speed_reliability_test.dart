import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/canonical_telemetry_pipeline.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/features/drive_score/services/drive_phase_analyzer.dart';
import 'package:driveit_project/features/drive_score/services/drive_feature_extractor.dart';
import 'package:driveit_project/features/drive_score/models/driving_analysis_models.dart';
import 'package:driveit_project/models/drive_telemetry_sample.dart';
import 'package:driveit_project/services/drive_telemetry_analyzer.dart';

const metersPerDegree = 111194.92664455874;
final epoch = DateTime.utc(2026, 1, 1);
RawTelemetryInput fix(
  double seconds,
  double meters,
  double native, {
  double accuracy = 5,
  double? speedAccuracy,
}) => RawTelemetryInput(
  latitude: meters / metersPerDegree,
  longitude: 0,
  timestamp: epoch.add(Duration(microseconds: (seconds * 1000000).round())),
  speedMps: native,
  headingDegrees: 0,
  altitudeMeters: 10,
  accuracyMeters: accuracy,
  speedAccuracyMps: speedAccuracy,
);
List<CanonicalTelemetryPoint> timeline(
  List<double> speeds, {
  bool nativeZero = false,
  double dt = 1,
}) {
  final pipeline = CanonicalTelemetryPipeline();
  var meters = 0.0;
  return [
    for (var i = 0; i < speeds.length; i++)
      pipeline.add(
        fix(
          i * dt,
          meters += i == 0 ? 0 : speeds[i] * dt,
          nativeZero ? 0 : speeds[i],
        ),
      )!,
  ];
}

// Frozen Phase 2 speed selection/feedback for a straight, accurate 1 Hz drive.
// Independently reproduces native=0 plus geometry=7 -> all 243 zeros.
List<double> legacySpeeds(int count, double geometrySpeed, double dt) {
  final window = <double>[];
  var previous = 0.0;
  return [
    for (var i = 0; i < count; i++)
      (() {
        var candidate = i == 0
            ? 0.0
            : geometrySpeed > math.max(8, geometrySpeed * .75)
            ? geometrySpeed
            : 0.0;
        window.add(candidate);
        if (window.length > 5) window.removeAt(0);
        final sorted = [...window]..sort();
        var speed = sorted.length.isOdd
            ? sorted[sorted.length ~/ 2]
            : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
        if ((speed - previous).abs() / dt > 8) {
          speed = previous;
          window[window.length - 1] = speed;
        }
        previous = speed;
        return speed;
      })(),
  ];
}

void main() {
  test(
    'unknown zero during weak-GPS movement is not scored as a stop or traffic',
    () {
      final pipeline = CanonicalTelemetryPipeline();
      final points = [
        for (var i = 0; i < 60; i++)
          pipeline.add(fix(i.toDouble(), i * 7.0, 0, accuracy: 25))!,
      ];
      final analysis = const DrivePhaseAnalyzer().analyze(
        driveSessionId: 'synthetic',
        telemetry: points,
      );
      expect(
        analysis.events.where((e) => e.type == DrivingEventType.stop),
        isEmpty,
      );
      expect(
        analysis.trafficTimeline
            .take(8)
            .every((t) => t == TrafficContext.unknown),
        isTrue,
      );
    },
  );
  test(
    'bounded evidence recovers movement even when accuracy is 25m and native speed zero',
    () {
      final pipeline = CanonicalTelemetryPipeline();
      final points = [
        for (var i = 0; i < 60; i++)
          pipeline.add(fix(i.toDouble(), i * 7.0, 0, accuracy: 25))!,
      ];
      expect(points.last.speedMps, closeTo(7, .01));
      expect(points.last.speedSource, 'geometry_estimate');
    },
  );
  test(
    'stationary positive native drift of 2m/s is not trusted over fixed positions',
    () {
      final pipeline = CanonicalTelemetryPipeline();
      final points = [
        for (var i = 0; i < 60; i++) pipeline.add(fix(i.toDouble(), 0, 2))!,
      ];
      expect(points.last.speedMps, 0);
      expect(points.last.speedSource, 'unavailable');
    },
  );
  test(
    'unavailable or conflicting native speed at stop cannot retain moving speed forever',
    () {
      for (final native in [double.nan, 50.0]) {
        final pipeline = CanonicalTelemetryPipeline();
        for (var i = 0; i < 20; i++) {
          pipeline.add(fix(i.toDouble(), i * 7.0, 7));
        }
        CanonicalTelemetryPoint? stopped;
        for (var i = 20; i < 50; i++) {
          stopped = pipeline.add(fix(i.toDouble(), 19 * 7.0, native));
        }
        expect(stopped!.speedMps, 0);
        expect(stopped.speedSource, 'unavailable');
        expect(stopped.accelerationReliable, isFalse);
      }
    },
  );
  test('native-zero geometry bootstrap cannot invent a hard launch at 1Hz', () {
    final points = timeline(List.filled(120, 7), nativeZero: true);
    final metrics = const DriveTelemetryAnalyzer().analyze(
      points.map(
        (p) => DriveTelemetrySample(
          latitude: p.latitude,
          longitude: p.longitude,
          speedMps: p.speedMps,
          accuracyMeters: p.accuracyMeters,
          heading: p.headingDegrees,
          altitudeMeters: p.altitudeMeters,
          timestamp: p.timestamp,
          canonicalAccelerationMps2: p.accelerationMps2,
          accelerationReliable: p.accelerationReliable,
          breakBefore: p.breakBefore,
        ),
      ),
    );
    expect(metrics.hardAccelerationCount, 0);
    expect(metrics.hardBrakeCount, 0);
  });
  test(
    'legacy summary consumes canonical derivative once and skips unknown rebaseline',
    () {
      final points = timeline(List.filled(120, 14), nativeZero: true, dt: .2);
      final metrics = const DriveTelemetryAnalyzer().analyze(
        points.map(
          (p) => DriveTelemetrySample(
            latitude: p.latitude,
            longitude: p.longitude,
            speedMps: p.speedMps,
            accuracyMeters: p.accuracyMeters,
            heading: p.headingDegrees,
            altitudeMeters: p.altitudeMeters,
            timestamp: p.timestamp,
            canonicalAccelerationMps2: p.accelerationMps2,
            accelerationReliable: p.accelerationReliable,
            breakBefore: p.breakBefore,
          ),
        ),
      );
      expect(metrics.hardAccelerationCount, 0);
      expect(metrics.hardBrakeCount, 0);
    },
  );
  test(
    '2+ hour moving timeline maintains speed, acceleration and distance without drift',
    () {
      final points = timeline(List.filled(8001, 7), nativeZero: true);
      expect(points.last.speedMps, closeTo(7, .01));
      expect(
        points.skip(10).every((p) => p.accelerationMps2.abs() < .0001),
        isTrue,
      );
      expect(
        points.fold<double>(0, (sum, p) => sum + p.distanceFromPreviousMeters),
        closeTo(8000 * 7, .05),
      );
    },
  );
  test(
    'reproduces both old zero-lock mechanisms independently of new pipeline',
    () {
      expect(legacySpeeds(243, 7, 1).every((s) => s == 0), isTrue);
      expect(legacySpeeds(243, 14, .2).every((s) => s == 0), isTrue);
    },
  );
  test(
    '243 moving fixes with native zero recover from geometry, not a fake native measurement',
    () {
      final points = timeline(List.filled(243, 7), nativeZero: true);
      expect(
        points.skip(10).every((p) => (p.speedMps - 7).abs() < .01),
        isTrue,
      );
      expect(points.last.speedSource, 'geometry_estimate');
      expect(
        points.fold<double>(0, (s, p) => s + p.distanceFromPreviousMeters),
        closeTo(242 * 7, .01),
      );
    },
  );
  test(
    'high-frequency native-zero feedback lock recovers with corroborated evidence',
    () {
      final points = timeline(List.filled(243, 14), nativeZero: true, dt: .2);
      expect(points.last.speedMps, closeTo(14, .01));
      expect(points.every((p) => p.accelerationMps2.abs() <= 8), isTrue);
      expect(
        points.any((p) => !p.accelerationReliable && p.speedMps > 0),
        isTrue,
      );
    },
  );
  test('normal launch 0 -> 50 km/h and braking 50 -> 0 remain measurable', () {
    final points = timeline([
      for (var i = 0; i <= 14; i++) i.toDouble(),
      ...List.filled(10, 14.0),
      for (var i = 13; i >= 0; i--) i.toDouble(),
      ...List.filled(10, 0.0),
    ]);
    expect(points.any((p) => p.speedMps >= 13.8), isTrue);
    expect(points.last.speedMps, 0);
    expect(points.any((p) => p.accelerationMps2 > .8), isTrue);
    expect(points.any((p) => p.accelerationMps2 < -.8), isTrue);
  });
  test('stationary long timeline creates neither speed nor distance', () {
    final points = timeline(List.filled(7200, 0));
    expect(
      points.every(
        (p) =>
            p.speedMps == 0 &&
            p.distanceFromPreviousMeters == 0 &&
            p.accelerationMps2 == 0,
      ),
      isTrue,
    );
  });
  for (final accuracy in [3.0, 5.0, 25.0]) {
    test(
      'stationary 3-10m jitter with accuracy $accuracy has no false motion',
      () {
        final pipeline = CanonicalTelemetryPipeline();
        final points = [
          for (var i = 0; i < 300; i++)
            pipeline.add(
              fix(i.toDouble(), (i % 5 - 2) * 2.5, 0, accuracy: accuracy),
            )!,
        ];
        expect(
          points.every(
            (p) => p.speedMps == 0 && p.distanceFromPreviousMeters == 0,
          ),
          isTrue,
        );
      },
    );
  }
  test('native spike inconsistent with geometry produces no hard events', () {
    final pipeline = CanonicalTelemetryPipeline();
    final points = [
      for (var i = 0; i < 80; i++)
        pipeline.add(fix(i.toDouble(), i * 7.0, i == 30 ? 60 : 7))!,
    ];
    expect(points.skip(10).every((p) => p.speedMps < 8), isTrue);
    final analysis = const DrivePhaseAnalyzer().analyze(
      driveSessionId: 'synthetic',
      telemetry: points.skip(10),
    );
    expect(
      analysis.events.where(
        (e) =>
            e.type == DrivingEventType.acceleration ||
            e.type == DrivingEventType.deceleration,
      ),
      isEmpty,
    );
  });
  test('invalid/missing native speed uses only demonstrated geometry', () {
    for (final native in [double.nan, -1.0, double.infinity]) {
      final pipeline = CanonicalTelemetryPipeline();
      final points = [
        for (var i = 0; i < 30; i++)
          pipeline.add(fix(i.toDouble(), i * 7.0, native))!,
      ];
      expect(points.last.speedMps, closeTo(7, .01));
      expect(points.last.speedSource, 'geometry_estimate');
    }
  });
  test(
    'poor native speed accuracy is rejected without rejecting good coordinates',
    () {
      final pipeline = CanonicalTelemetryPipeline();
      final points = [
        for (var i = 0; i < 30; i++)
          pipeline.add(fix(i.toDouble(), i * 7.0, 50, speedAccuracy: 20))!,
      ];
      expect(points.last.speedMps, closeTo(7, .01));
    },
  );
  test(
    'first reliable native observation need not start at fabricated zero',
    () {
      final point = CanonicalTelemetryPipeline().add(
        fix(0, 0, 14, speedAccuracy: .5),
      )!;
      expect(point.speedMps, 14);
      expect(point.accelerationReliable, isFalse);
      expect(point.accelerationMps2, 0);
    },
  );
  test(
    '17s / 310m gap does not become instantaneous speed, acceleration or distance',
    () {
      final pipeline = CanonicalTelemetryPipeline();
      for (var i = 0; i < 20; i++) {
        pipeline.add(fix(i.toDouble(), i * 7.0, 7));
      }
      final after = pipeline.add(fix(36, 19 * 7 + 310, 0))!;
      expect(after.breakBefore, isTrue);
      expect(after.gapDurationMicros, 17000000);
      expect(after.distanceFromPreviousMeters, 0);
      expect(after.speedMps, 0);
      expect(after.accelerationReliable, isFalse);
      for (var i = 1; i < 12; i++) {
        pipeline.add(fix(36 + i.toDouble(), 19 * 7 + 310 + i * 7, 0));
      }
      final next = pipeline.add(fix(49, 19 * 7 + 310 + 13 * 7, 0))!;
      expect(next.speedMps, closeTo(7, .01));
    },
  );
  test(
    'JSON checkpoint restores evidence/median exactly across repeated restarts',
    () {
      final uninterrupted = CanonicalTelemetryPipeline();
      var restarting = CanonicalTelemetryPipeline();
      for (var i = 0; i < 1500; i++) {
        final raw = fix(i * .2, i * 2.8, i % 7 == 0 ? double.nan : 0);
        final expected = uninterrupted.add(raw)!.toMap();
        final actual = restarting.add(raw)!.toMap();
        expect(actual, expected);
        if (i % 17 == 0) {
          restarting = CanonicalTelemetryPipeline()
            ..restoreCheckpoint(
              jsonDecode(jsonEncode(restarting.checkpoint()))
                  as Map<String, dynamic>,
            );
        }
      }
    },
  );
  test('version 1 checkpoint remains readable without rewriting old data', () {
    final pipeline = CanonicalTelemetryPipeline()..add(fix(0, 0, 0));
    final old = pipeline.checkpoint()
      ..['version'] = 1
      ..remove('motionWindow');
    final restored = CanonicalTelemetryPipeline()..restoreCheckpoint(old);
    expect(restored.add(fix(1, 7, 7)), isNotNull);
  });
  test(
    'duplicate, reverse and too-close timestamps do not contaminate checkpoint',
    () {
      final pipeline = CanonicalTelemetryPipeline()..add(fix(1, 7, 7));
      final before = jsonEncode(pipeline.checkpoint());
      for (final seconds in [1.0, .9, 1.1]) {
        expect(pipeline.add(fix(seconds, 100, 60)), isNull);
        expect(jsonEncode(pipeline.checkpoint()), before);
      }
    },
  );
  test('real hard acceleration and braking survive median filtering', () {
    final points = timeline([
      0,
      5,
      10,
      15,
      20,
      25,
      30,
      ...List.filled(12, 30.0),
      25,
      20,
      15,
      10,
      5,
      0,
      ...List.filled(12, 0.0),
    ]);
    expect(
      points.any((p) => p.accelerationReliable && p.accelerationMps2 >= 4.9),
      isTrue,
    );
    expect(
      points.any((p) => p.accelerationReliable && p.accelerationMps2 <= -4.9),
      isTrue,
    );
    final events = const DrivePhaseAnalyzer()
        .analyze(driveSessionId: 'synthetic', telemetry: points)
        .events;
    expect(events.any((e) => e.type == DrivingEventType.acceleration), isTrue);
    expect(events.any((e) => e.type == DrivingEventType.deceleration), isTrue);
  });
  test(
    'Hive quality metadata survives without changing any point field IDs',
    () {
      final points = timeline(List.filled(20, 7), nativeZero: true);
      final hive = HiveImpl();
      DriveTelemetryHive.registerAdapters(hive);
      final record = DriveTelemetryRecord(
        driveSessionId: 'synthetic',
        dataVersion: 1,
        createdAt: epoch,
        points: points,
      );
      final writer = BinaryWriterImpl(hive)..write(record);
      final read =
          BinaryReaderImpl(writer.toBytes(), hive).read()
              as DriveTelemetryRecord;
      expect(
        read.points.map((p) => p.toMap()).toList(),
        points.map((p) => p.toMap()).toList(),
      );
      expect(read.acquisitionMetadata['canonicalQualityV1'], isNotEmpty);
    },
  );
  test(
    'unmeasured derivative resets feature smoothing, not category rules',
    () {
      final points = timeline([0, 5, 10, 15, 20]);
      final last = points.last;
      final unknown = CanonicalTelemetryPoint.fromMap({
        ...last.toMap(),
        'time': last.timestamp
            .add(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
        'accelerationReliable': false,
        'acceleration': 0,
      })!;
      final features = const DriveFeatureExtractor().extract([
        ...points,
        unknown,
      ]);
      expect(features.last.smoothedAccelerationMps2, 0);
    },
  );
}
