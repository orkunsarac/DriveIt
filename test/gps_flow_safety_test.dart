import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/gps_stream_supervisor.dart';
import 'package:driveit_project/services/gps_recording_writer.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_failure.dart';
import 'package:driveit_project/services/canonical_telemetry_pipeline.dart';
import 'package:driveit_project/services/route_service.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/features/my_world/services/gps_route_preprocessor.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:hive/hive.dart';

RawTelemetryInput raw(int second) => RawTelemetryInput(
  latitude: 40 + second * .0001,
  longitude: 29,
  timestamp: DateTime.utc(2026).add(Duration(seconds: second)),
  speedMps: 11,
  headingDegrees: 0,
  altitudeMeters: 50,
  accuracyMeters: 3,
);

class Probe {
  DateTime clock = DateTime.utc(2026);
  bool enabled = true;
  int active = 0, peak = 0;
  final controllers = <StreamController<int>>[];
  final samples = <int>[];
  late final supervisor = GpsStreamSupervisor<int>(
    now: () => clock,
    available: () async => enabled,
    onSample: samples.add,
    onState: (_) {},
    open: () {
      final c = StreamController<int>(
        sync: true,
        onListen: () {
          active++;
          if (active > peak) peak = active;
        },
        onCancel: () => active--,
      );
      controllers.add(c);
      return c.stream;
    },
  );
  void advance(int seconds) => clock = clock.add(Duration(seconds: seconds));
  Future<void> dispose() async {
    await supervisor.close();
    for (final c in controllers) {
      await c.close();
    }
  }
}

class DiskProbe extends GpsSessionStore {
  DiskProbe(super.db);
  bool fail = true;
  final attempted = Completer<void>();
  @override
  Future<int> append(
    String id,
    int sequence,
    CanonicalTelemetryPoint point, {
    Map<String, dynamic>? checkpoint,
  }) {
    if (fail) {
      if (!attempted.isCompleted) attempted.complete();
      return Future.error(GpsFailure(GpsErrorCode.sqliteWrite));
    }
    return super.append(id, sequence, point, checkpoint: checkpoint);
  }
}

void main() {
  test('cached duplicate fixes cannot reset silence watchdog', () async {
    var clock = DateTime.utc(2026);
    var last = -1;
    final stream = StreamController<int>(sync: true);
    final samples = <int>[];
    final supervisor = GpsStreamSupervisor<int>(
      now: () => clock,
      open: () => stream.stream,
      available: () async => true,
      onState: (_) {},
      onSample: samples.add,
      isFresh: (sample) {
        if (sample <= last) return false;
        last = sample;
        return true;
      },
    );
    await supervisor.poll();
    stream.add(1);
    clock = clock.add(const Duration(seconds: 16));
    stream.add(1);
    await supervisor.poll();
    expect(supervisor.state, GpsFlowState.waiting);
    expect(samples, [1]);
    await supervisor.close();
    await stream.close();
  });
  test(
    'terminal stream exception reconnects, cancellation prevents duplicates',
    () async {
      final p = Probe();
      await p.supervisor.poll();
      p.controllers.last.add(1);
      p.controllers.last.addError(StateError('synthetic'));
      await p.supervisor.poll();
      expect(p.controllers.length, 1);
      p.advance(3);
      await p.supervisor.poll();
      p.controllers.first.add(99);
      p.controllers.last.add(2);
      expect(p.samples, [1, 2]);
      expect(p.peak, 1);
      await p.dispose();
    },
  );
  for (final seconds in [5, 120]) {
    test(
      'locked/headless service disabled $seconds seconds preserves session flow',
      () async {
        final p = Probe();
        await p.supervisor.poll();
        p.controllers.last.add(1);
        p.enabled = false;
        await p.supervisor.poll();
        expect(p.active, 0);
        expect(p.supervisor.state, GpsFlowState.permissionBlocked);
        p.advance(seconds);
        await p.supervisor.poll();
        expect(p.controllers.length, 1);
        p.enabled = true;
        await p.supervisor.poll();
        p.controllers.last.add(2);
        expect(p.samples, [1, 2]);
        expect(p.supervisor.state, GpsFlowState.recording);
        await p.dispose();
      },
    );
  }
  test(
    'silent tunnel stream becomes waiting then bounded retries; no foreground launch',
    () async {
      final p = Probe();
      await p.supervisor.poll();
      p.controllers.last.add(1);
      p.advance(16);
      await p.supervisor.poll();
      expect(p.supervisor.state, GpsFlowState.waiting);
      p.advance(15);
      await p.supervisor.poll();
      for (var i = 0; i < 120; i++) {
        p.advance(1);
        await p.supervisor.poll();
      }
      expect(p.controllers.length, lessThan(12));
      expect(p.peak, 1);
      await p.dispose();
    },
  );
  test(
    'concurrent polls and close do not reopen or accept late samples',
    () async {
      final p = Probe();
      await Future.wait(List.generate(20, (_) => p.supervisor.poll()));
      expect(p.controllers.length, 1);
      final closing = p.supervisor.close();
      p.controllers.last.add(999);
      await closing;
      await p.supervisor.poll();
      expect(p.samples, isEmpty);
      expect(p.active, 0);
      await p.dispose();
    },
  );
  for (final seconds in [5, 15, 16, 120]) {
    test(
      'gap $seconds sec: retained boundary, no invented long-gap distance/road',
      () {
        final pipeline = CanonicalTelemetryPipeline();
        final route = RouteService();
        final first = pipeline.add(raw(0))!;
        route.addCanonicalPoint(first);
        final resumed = pipeline.add(raw(seconds))!;
        route.addCanonicalPoint(resumed);
        expect(resumed.breakBefore, seconds > 15);
        if (seconds > 15) {
          expect(resumed.distanceFromPreviousMeters, 0);
          expect(route.distance, 0);
          expect(route.routePoints.length, 2);
          expect(route.polylines, isEmpty);
          pipeline.add(raw(seconds + 1));
          final next = pipeline.add(raw(seconds + 2))!;
          route.addCanonicalPoint(next);
          expect(next.breakBefore, false);
          final cleaned = const GpsRoutePreprocessor().clean(
            route.getRouteForSave(),
          );
          expect(cleaned.traces.length, 1);
          expect(cleaned.traces.single.points.first.latitude, resumed.latitude);
        }
      },
    );
  }

  late Directory dir;
  late GpsSessionStore store;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('gps_phase2_');
    store = await GpsSessionStore.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/journal.db',
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test(
    'restart in GPS outage keeps prefix and marks restored boundary',
    () async {
      final session = await store.create();
      final writer = GpsRecordingWriter(store, session.id, onError: (_) {});
      await writer.restore();
      await writer.add(raw(0));
      await writer.add(raw(1));
      await writer.close();
      final restored = GpsRecordingWriter(store, session.id, onError: (_) {});
      await restored.restore();
      await restored.add(raw(121));
      await restored.add(raw(121));
      final points = await store.read(session.id);
      expect(points.map((p) => p.sequence), [1, 2, 3]);
      expect(points.last.point.breakBefore, true);
      expect(points.last.point.gapDurationMicros, 120000000);
      await restored.close();
    },
  );
  test(
    'last callback before producer barrier survives drain, timestamps and finish idempotent',
    () async {
      final session = await store.create();
      final writer = GpsRecordingWriter(store, session.id, onError: (_) {});
      final started = session.startedAt;
      final requested = started.add(const Duration(hours: 2));
      await writer.restore();
      await writer.add(raw(0));
      final finalSample = writer.add(raw(1));
      await store.requestStop(session.id, at: requested);
      await writer.drain();
      await finalSample;
      await store.stop(session.id, expectedSequence: 2);
      await store.stop(session.id, expectedSequence: 2);
      expect((await store.session(session.id))!.stoppedAt, requested);
      expect((await store.read(session.id)).length, 2);
      expect(
        (await store.events(
          session.id,
        )).where((e) => e['kind'] == 'drained').single['sequence'],
        2,
      );
      await expectLater(
        store.stop(session.id, expectedSequence: 3),
        throwsA(isA<GpsFailure>()),
      );
      await writer.close();
    },
  );
  test(
    'write failure during finish remains recoverable, no false stop receipt',
    () async {
      final session = await store.create();
      final disk = DiskProbe(store.db);
      final writer = GpsRecordingWriter(
        disk,
        session.id,
        onError: (_) {},
        retryDelay: const Duration(milliseconds: 2),
      );
      await writer.restore();
      final pending = writer.add(raw(0));
      await disk.attempted.future;
      await store.requestStop(session.id);
      await expectLater(
        store.stop(session.id, expectedSequence: 1),
        throwsA(isA<GpsFailure>()),
      );
      expect((await store.active())!.state, 'recording');
      expect(await store.read(session.id), isEmpty);
      disk.fail = false;
      await writer.drain();
      await pending;
      await store.stop(session.id, expectedSequence: 1);
      expect((await store.read(session.id)).length, 1);
      await writer.close();
    },
  );
  test(
    '2+ hour trip with outages: ordered points, no duplicate, exact final sequence',
    () async {
      final session = await store.create();
      final writer = GpsRecordingWriter(store, session.id, onError: (_) {});
      await writer.restore();
      for (var i = 0; i < 7600; i++) {
        if (i >= 2000 && i < 2120) continue;
        await writer.add(raw(i));
      }
      await writer.drain();
      await store.requestStop(session.id);
      await store.stop(session.id, expectedSequence: 7480);
      final points = await store.read(session.id);
      expect(points.length, 7480);
      expect(points.last.sequence, 7480);
      expect(points.where((p) => p.point.breakBefore).length, 1);
      await writer.close();
    },
  );
  test(
    'Hive telemetry roundtrip preserves break metadata and explicit event times',
    () async {
      final hive = Hive;
      hive.init(dir.path);
      DriveTelemetryHive.registerAdapters(hive);
      final box = await hive.openBox<DriveTelemetryRecord>('roundtrip');
      final pipeline = CanonicalTelemetryPipeline();
      pipeline.add(raw(0));
      final point = pipeline.add(raw(120))!;
      await box.put(
        'new',
        DriveTelemetryRecord(
          driveSessionId: 'new',
          dataVersion: 1,
          createdAt: DateTime.utc(2026),
          points: [point],
          acquisitionMetadata: {'finalSequence': 2},
        ),
      );
      await box.close();
      final read = await hive.openBox<DriveTelemetryRecord>('roundtrip');
      expect(read.get('new')!.points.single.breakBefore, true);
      expect(read.get('new')!.acquisitionMetadata['finalSequence'], 2);
      await hive.close();
    },
  );
}
