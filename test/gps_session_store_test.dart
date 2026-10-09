import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_recording_writer.dart';
import 'package:driveit_project/services/canonical_telemetry_pipeline.dart';
import 'package:driveit_project/services/gps_failure.dart';

RawTelemetryInput raw(int second) => RawTelemetryInput(
  latitude: 40 + second * 0.00001,
  longitude: 29,
  timestamp: DateTime.utc(2026).add(Duration(seconds: second)),
  speedMps: 2,
  headingDegrees: 0,
  altitudeMeters: 50,
  accuracyMeters: 4,
);
CanonicalTelemetryPoint point(int i) => CanonicalTelemetryPoint(
  latitude: 40 + i * 0.00001,
  longitude: 29,
  timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
  speedMps: 2,
  headingDegrees: 0,
  altitudeMeters: 50,
  accuracyMeters: 4,
  distanceFromPreviousMeters: 1,
  accelerationMps2: 0,
);

class FailingStore extends GpsSessionStore {
  FailingStore(super.db);
  bool fail = true;
  final attempted = Completer<void>();
  @override
  Future<int> append(
    String id,
    int seq,
    CanonicalTelemetryPoint p, {
    Map<String, dynamic>? checkpoint,
  }) async {
    if (fail) {
      if (!attempted.isCompleted) attempted.complete();
      throw StateError('disk-full synthetic');
    }
    return super.append(id, seq, p, checkpoint: checkpoint);
  }
}

class LostAcknowledgementStore extends GpsSessionStore {
  LostAcknowledgementStore(super.db);
  bool loseOnce = true;
  @override
  Future<int> append(
    String id,
    int seq,
    CanonicalTelemetryPoint p, {
    Map<String, dynamic>? checkpoint,
  }) async {
    final result = await super.append(id, seq, p, checkpoint: checkpoint);
    if (loseOnce) {
      loseOnce = false;
      throw StateError('synthetic acknowledgement lost after commit');
    }
    return result;
  }
}

void main() {
  test(
    'filter checkpoint preserves exactly the uninterrupted speed/distance result',
    () {
      final uninterrupted = CanonicalTelemetryPipeline();
      final beforeRestart = CanonicalTelemetryPipeline();
      for (var i = 0; i < 20; i++) {
        uninterrupted.add(raw(i));
        beforeRestart.add(raw(i));
      }
      final restored = CanonicalTelemetryPipeline()
        ..restoreCheckpoint(beforeRestart.checkpoint());
      for (var i = 20; i < 40; i++) {
        expect(
          restored.add(raw(i))!.toMap(),
          uninterrupted.add(raw(i))!.toMap(),
        );
      }
    },
  );
  late Directory dir;
  late String path;
  late GpsSessionStore store;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('gps-journal-');
    path = '${dir.path}/gps.db';
    store = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  test(
    '40 min -> recreated task -> 40 min preserves all 4800 points/order',
    () async {
      final session = await store.create();
      var writer = GpsRecordingWriter(
        store,
        session.id,
        onError: (_) {
          fail('unexpected write failure');
        },
      );
      await writer.restore();
      for (var i = 0; i < 2400; i++) {
        await writer.add(raw(i));
      }
      final prefix = await store.read(session.id);
      await writer.close();
      await store.close();
      store = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect((await store.active())!.id, session.id);
      writer = GpsRecordingWriter(
        store,
        session.id,
        onError: (_) {
          fail('unexpected write failure');
        },
      );
      await writer.restore();
      for (var i = 2400; i < 4800; i++) {
        await writer.add(raw(i));
      }
      final points = await store.read(session.id);
      expect(points.length, 4800);
      expect(points.map((p) => p.sequence), List.generate(4800, (i) => i + 1));
      expect(
        points.take(2400).map((p) => p.toMap()).toList(),
        prefix.map((p) => p.toMap()).toList(),
      );
      expect(points.last.point.timestamp, raw(4799).timestamp);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test(
    'background isolate writes while UI has no consumer; >2h 8000 samples',
    () async {
      final session = await store.create();
      final count = await Isolate.run(() async {
        sqfliteFfiInit();
        final background = await GpsSessionStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: path,
        );
        for (var i = 0; i < 8000; i++) {
          await background.append(session.id, i + 1, point(i));
        }
        await background.close();
        return 8000;
      });
      expect(count, 8000);
      final rows = await store.read(session.id);
      expect(rows.length, 8000);
      expect(rows.last.sequence, 8000);
      expect(
        rows.last.point.timestamp
            .difference(rows.first.point.timestamp)
            .inSeconds,
        7999,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test('GPS gap/re-delivery, filter state restore, sequence cursor', () async {
    final session = await store.create();
    var writer = GpsRecordingWriter(
      store,
      session.id,
      onError: (_) {
        fail('write error');
      },
    );
    await writer.restore();
    await writer.add(raw(0));
    await writer.add(raw(1));
    await writer.close();
    writer = GpsRecordingWriter(
      store,
      session.id,
      onError: (_) {
        fail('write error');
      },
    );
    await writer.restore();
    await writer.add(raw(1));
    await writer.add(raw(123));
    final rows = await store.read(session.id);
    expect(rows.length, 3);
    expect(rows.last.sequence, 3);
    expect((await store.read(session.id, after: 2)).single.sequence, 3);
    expect(
      rows.last.point.timestamp.difference(rows[1].point.timestamp).inSeconds,
      122,
    );
  });
  test(
    'duplicate append idempotent; conflicting sequences rejected; immutable rows',
    () async {
      final s = await store.create();
      expect(await store.append(s.id, 1, point(0)), 1);
      expect(await store.append(s.id, 1, point(0)), 1);
      await expectLater(store.append(s.id, 1, point(1)), throwsStateError);
      await expectLater(store.append(s.id, 3, point(2)), throwsStateError);
      await expectLater(
        store.db.update('points', {'payload': 'changed'}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        store.db.delete('points'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await store.read(s.id)).length, 1);
    },
  );
  test(
    'disk write failure signals warning, holds exact pending sample, retries',
    () async {
      final s = await store.create();
      final faulty = FailingStore(store.db);
      final errors = <bool>[];
      final writer = GpsRecordingWriter(
        faulty,
        s.id,
        onError: errors.add,
        retryDelay: const Duration(milliseconds: 10),
      );
      await writer.restore();
      final first = writer.add(raw(0));
      await faulty.attempted.future;
      await Future<void>.delayed(Duration.zero);
      expect(writer.hasPendingFailure, true);
      expect(errors, contains(true));
      expect(await store.read(s.id), isEmpty);
      final next = writer.add(raw(1));
      faulty.fail = false;
      await first;
      await next;
      expect(errors.last, false);
      expect((await store.read(s.id)).map((p) => p.sequence), [1, 2]);
    },
  );
  test(
    'transaction interruption rolls back, committed points survive reopen',
    () async {
      final s = await store.create();
      await store.append(s.id, 1, point(0));
      await expectLater(
        store.db.transaction((tx) async {
          await tx.insert('points', {
            'session_id': s.id,
            'sequence': 2,
            'timestamp_us': 1,
            'payload': 'uncommitted',
          });
          throw StateError('crash before commit');
        }),
        throwsStateError,
      );
      await store.close();
      store = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect((await store.active())!.id, s.id);
      expect((await store.read(s.id)).length, 1);
      await store.append(s.id, 2, point(1));
    },
  );
  test(
    'commit acknowledgement lost: exact retry creates no duplicate',
    () async {
      final session = await store.create();
      final warnings = <bool>[];
      final writer = GpsRecordingWriter(
        LostAcknowledgementStore(store.db),
        session.id,
        onError: warnings.add,
        retryDelay: const Duration(milliseconds: 1),
      );
      await writer.restore();
      await writer.add(raw(0));
      await writer.add(raw(1));
      expect(warnings, [true, false]);
      expect((await store.read(session.id)).map((p) => p.sequence), [1, 2]);
      await writer.close();
    },
  );
  test('two connections cannot overwrite the same sequence', () async {
    final session = await store.create();
    final other = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    try {
      // FFI no-isolate serializes native calls on one test thread: a competing
      // BEGIN may time out. This is a safe retry, never an overwrite.
      final results = await Future.wait<Object>([
        store
            .append(session.id, 1, point(0))
            .then<Object>((v) => v)
            .catchError((Object error) => error),
        other
            .append(session.id, 1, point(0))
            .then<Object>((v) => v)
            .catchError((Object error) => error),
      ]);
      expect(results.whereType<int>(), isNotEmpty);
      expect(
        results.every(
          (r) =>
              r == 1 || (r is GpsFailure && r.code == GpsErrorCode.sqliteWrite),
        ),
        true,
      );
      await other.append(session.id, 1, point(0));
      expect((await store.read(session.id)).length, 1);
      await expectLater(
        other.append(session.id, 1, point(1)),
        throwsStateError,
      );
      expect(
        (await store.read(session.id)).single.point.toMap(),
        point(0).toMap(),
      );
    } finally {
      await other.close();
    }
  });
  test(
    'new session cannot overwrite/attach old; stopped remains recoverable',
    () async {
      final old = await store.create();
      await store.append(old.id, 1, point(0));
      await expectLater(store.create(), throwsStateError);
      await store.stop(old.id);
      expect((await store.active())!.state, 'stopped');
      await expectLater(store.create(), throwsStateError);
      await store.acknowledgeSaved(old.id, old.id);
      final next = await store.create();
      expect(next.id, isNot(old.id));
      expect(await store.read(next.id), isEmpty);
      await expectLater(store.append(old.id, 2, point(1)), throwsStateError);
      expect((await store.read(old.id)).single.sequence, 1);
    },
  );
  test(
    'unexpected child process death leaves committed prefix and rolls back WAL',
    () async {
      final s = await store.create();
      await store.append(s.id, 1, point(0));
      await store.close();
      var folder = File(Platform.resolvedExecutable).parent;
      String? dart;
      for (var i = 0; i < 8; i++) {
        final candidate =
            '${folder.path}/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
        if (File(candidate).existsSync()) {
          dart = candidate;
          break;
        }
        folder = folder.parent;
      }
      expect(
        dart,
        isNotNull,
        reason: 'Find Dart SDK relative to Flutter test engine',
      );
      final process = await Process.run(dart!, [
        'run',
        'test/support/gps_crash_probe.dart',
        path,
        s.id,
      ]);
      expect(process.exitCode, 73, reason: '${process.stderr}');
      store = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect((await store.read(s.id)).length, 1);
      expect((await store.active())!.id, s.id);
      await store.append(s.id, 2, point(1));
      expect((await store.read(s.id)).last.sequence, 2);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
