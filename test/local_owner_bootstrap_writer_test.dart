import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late TestAuth auth;
  late LocalSourceWriterFence fence;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_owner_test_');
    auth = TestAuth();
    fence = LocalSourceWriterFence(
      gate: LocalOwnershipGate.synthetic(),
      gpsBusy: () async => false,
      sourceRoots: [root.path],
      provenCategories: LocalSourceWriterFence.requiredCategories,
    );
  });
  tearDown(() async {
    await auth.events.close();
    await root.delete(recursive: true);
  });

  Future<ControlledOwnershipRuntime> boot({
    bool busy = false,
    Future<LocalOwnerAuth> Function()? restore,
  }) async {
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    return (await LocalOwnershipBootstrap.run(
      gate: LocalOwnershipGate.synthetic(),
      legacyBootstrap: () async => fail('No shared fallback'),
      controlled: ControlledOwnershipDependencies(
        descriptor: descriptor,
        databaseFactory: databaseFactoryFfiNoIsolate,
        restoreAuth: restore ?? () async => auth,
        producerRunning: () async => busy,
        openStore: (owner) =>
            OwnerScopedLocalStore.open(root: root.path, owner: owner),
        attachForeground: (gps, descriptor) async {
          expect(gps.runtime.state, LocalOwnerState.ready);
          expect(await gps.journal.active(), null);
        },
        detachForeground: (_) async {},
      ),
    ))!;
  }

  test(
    'OFF bootstrap calls only legacy, no controlled dependency access',
    () async {
      var calls = 0;
      expect(
        await LocalOwnershipBootstrap.run(
          gate: LocalOwnershipGate.production,
          legacyBootstrap: () async {
            calls++;
          },
        ),
        null,
      );
      expect(calls, 1);
      expect(await root.list().toList(), isEmpty);
    },
  );
  test('ON without dependencies fails closed', () async {
    await expectLater(
      LocalOwnershipBootstrap.run(
        gate: LocalOwnershipGate.synthetic(),
        legacyBootstrap: () async => fail('fallback'),
      ),
      throwsStateError,
    );
  });
  test('guest bootstrap then account A/B revokes repository leases', () async {
    auth.userId = null;
    final handle = await boot();
    expect(handle.owner.lease.owner.kind, GpsOwnerKind.guest);
    final guest = handle.owner.lease;
    auth.emit(a);
    await handle.owner.settled;
    expect(guest.isCurrent, false);
    final old = handle.owner.lease;
    await old.put('drive_names', 'same', 'A');
    auth.emit(b);
    await handle.owner.settled;
    expect(old.isCurrent, false);
    expect(() => old.read('drive_names', 'same'), throwsStateError);
    expect(handle.owner.lease.read('drive_names', 'same'), null);
    await handle.closeAfterProducerDetached();
  });
  test('failed Auth restore never opens scoped stores or journal', () async {
    await expectLater(
      boot(restore: () async => throw StateError('restore')),
      throwsStateError,
    );
    expect(await Directory('${root.path}/owner_stores_v1').exists(), false);
    expect(await File('${root.path}/gps.db').exists(), false);
  });
  test('unverified native producer cannot open personal view', () async {
    await expectLater(boot(busy: true), throwsStateError);
    expect(await Directory('${root.path}/owner_stores_v1').exists(), false);
  });
  test(
    'native restart decodes descriptor and resolves fixed owner without Auth',
    () async {
      final handle = await boot();
      final session = await handle.gps.start(startNative: (_, _) async {});
      final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
      final recovered = await OwnedForegroundBootstrap.decode(
        descriptor.encode(),
      );
      expect(
        (await recovered.verify(
          databaseFactoryFfiNoIsolate,
          session.id,
        )).owner.userId,
        a,
      );
      await expectLater(
        handle.owner.authorizeIdentityChange(() async => auth.emit(b)),
        throwsStateError,
      );
      // Exercise the REAL public SDK service entry point: fence rejects BEFORE
      // client/session access. No network or Supabase initialization in this test.
      await expectLater(
        SupabaseAccountService.instance.signOut(),
        throwsStateError,
      );
      auth.emit(b);
      await handle.owner.settled;
      expect(handle.owner.state, LocalOwnerState.blocked);
      expect(
        (await recovered.verify(
          databaseFactoryFfiNoIsolate,
          session.id,
        )).owner.userId,
        a,
      );
      await expectLater(handle.gps.transfer(session.id, {}), throwsStateError);
      expect(await handle.gps.journal.session(session.id), isNotNull);
      await handle.closeAfterProducerDetached();
    },
  );
  test('missing sidecar rejects restart; source journal survives', () async {
    final handle = await boot();
    final session = await handle.gps.journal.create();
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    await expectLater(
      descriptor.verify(databaseFactoryFfiNoIsolate, session.id),
      throwsStateError,
    );
    expect(await handle.gps.journal.session(session.id), isNotNull);
    await handle.closeAfterProducerDetached();
  });
  test(
    'actual foreground attach routes DriveStorage save to fixed sink, never shared Hive',
    () async {
      final handle = await boot();
      final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
      const channel = MethodChannel('flutter_foreground_task/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isRunningService');
            return false; // No real native service in this host test.
          });
      ForegroundService.attachForTesting(handle.gps, descriptor);
      try {
        expect(await ForegroundService.journal, same(handle.gps.journal));
        final session = await handle.gps.start(startNative: (_, _) async {});
        await handle.gps.journal.stop(session.id, expectedSequence: 0);
        final drive = DriveSession(
          id: session.id,
          date: DateTime.utc(2026),
          distance: 0,
          durationSeconds: 0,
          averageSpeed: 0,
          maxSpeed: 0,
          mapImagePath: '',
          route: [],
        );
        for (var i = 0; i < 2; i++) {
          await DriveStorageService.saveDrive(
            drive,
            acquisitionMetadata: {'sessionId': session.id},
          );
        }
        expect(handle.owner.lease.keys('drives'), [session.id]);
        expect(
          await handle.gps.ownership.verified(descriptor.journalId, session.id),
          true,
        );
        await ForegroundService.acknowledgeSaved(session.id, session.id);
        await expectLater(
          DriveStorageService.saveDrive(
            drive,
            acquisitionMetadata: {'sessionId': 'wrong'},
          ),
          throwsStateError,
        );
      } finally {
        await ForegroundService.detachForTesting(handle.gps);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await handle.closeAfterProducerDetached();
      }
    },
  );
  test('nested owner operation rejected instead of deadlocking', () async {
    final handle = await boot();
    await expectLater(
      handle.owner.withOwnerOperation(
        (_) => handle.owner.withOwnerOperation((_) async {}),
      ),
      throwsStateError,
    );
    await handle.owner.withOwnerOperation((_) async {});
    await handle.closeAfterProducerDetached();
  });
  test(
    'Auth event during authorized SDK action queues transition safely',
    () async {
      final handle = await boot();
      await handle.owner.authorizeIdentityChange(() async {
        auth.emit(b);
      });
      await handle.owner.settled;
      expect(handle.owner.lease.owner.userId, b);
      await handle.closeAfterProducerDetached();
    },
  );
  test(
    'all writer classes reject new writes while paused and resume',
    () async {
      await fence.pauseAndDrain();
      for (final category in LocalSourceWriterFence.requiredCategories) {
        await expectLater(fence.write(category, () async {}), throwsStateError);
      }
      await fence.resume();
      for (final category in LocalSourceWriterFence.requiredCategories) {
        await fence.write(category, () async {});
      }
    },
  );
  test(
    'started poster operation drains including nested metadata flush; no early resume',
    () async {
      final started = Completer<void>(), complete = Completer<void>();
      final writing = fence.write('poster', () async {
        started.complete();
        await complete.future;
        await fence.write('poster', () async {});
      });
      await started.future;
      final draining = fence.pauseAndDrain();
      await expectLater(fence.resume(), throwsStateError);
      await expectLater(fence.write('profile', () async {}), throwsStateError);
      complete.complete();
      await writing;
      await draining;
      expect(fence.pendingCount, 0);
      await fence.resume();
    },
  );
  test('unknown writer coverage blocks import', () async {
    final incomplete = LocalSourceWriterFence(
      gate: LocalOwnershipGate.synthetic(),
      gpsBusy: () async => false,
      sourceRoots: [root.path],
      provenCategories: {'history'},
    );
    await expectLater(incomplete.pauseAndDrain(), throwsStateError);
    await expectLater(
      incomplete.write('unknown', () async {}),
      throwsStateError,
    );
    expect(incomplete.paused, false);
  });
  test(
    'unawaited background source job stays registered after parent returns',
    () async {
      final done = Completer<void>();
      late Future<void> job;
      await fence.write('history', () async {
        job = fence.write('world_jobs', () => done.future);
        unawaited(job);
      });
      expect(fence.pendingCount, 1);
      final draining = fence.pauseAndDrain();
      expect(fence.paused, true);
      done.complete();
      await job;
      await draining;
      expect(fence.pendingCount, 0);
      await fence.resume();
    },
  );
  test(
    'nested job admitted during drain also completes before import',
    () async {
      final launch = Completer<void>(), done = Completer<void>();
      late Future<void> job;
      final parent = fence.write('history', () async {
        await launch.future;
        job = fence.write('world_jobs', () => done.future);
        unawaited(job);
      });
      final draining = fence.pauseAndDrain();
      launch.complete();
      await parent;
      expect(fence.pendingCount, 1);
      done.complete();
      await job;
      await draining;
      await fence.resume();
    },
  );
  test(
    'active GPS and unreadable producer block import without stopping it',
    () async {
      for (final check in <Future<bool> Function()>[
        () async => true,
        () async => throw StateError('unreadable'),
      ]) {
        final f = LocalSourceWriterFence(
          gate: LocalOwnershipGate.synthetic(),
          gpsBusy: check,
          sourceRoots: [root.path],
          provenCategories: LocalSourceWriterFence.requiredCategories,
        );
        await expectLater(f.pauseAndDrain(), throwsStateError);
        expect(f.paused, false);
        await f.write('history', () async {});
      }
    },
  );
  test('GPS starting during drain blocks import at second check', () async {
    var calls = 0;
    final f = LocalSourceWriterFence(
      gate: LocalOwnershipGate.synthetic(),
      gpsBusy: () async => ++calls > 1,
      sourceRoots: [root.path],
      provenCategories: LocalSourceWriterFence.requiredCategories,
    );
    await expectLater(f.pauseAndDrain(), throwsStateError);
    expect(f.paused, false);
  });
  test(
    'bounded drain timeout releases admission, never declares completion',
    () async {
      final done = Completer<void>();
      final f = LocalSourceWriterFence(
        gate: LocalOwnershipGate.synthetic(),
        gpsBusy: () async => false,
        sourceRoots: [root.path],
        provenCategories: LocalSourceWriterFence.requiredCategories,
        timeout: const Duration(milliseconds: 20),
      );
      final pending = f.write('history', () => done.future);
      await expectLater(f.pauseAndDrain(), throwsA(isA<TimeoutException>()));
      expect(f.paused, false);
      done.complete();
      await pending;
      await f.pauseAndDrain();
      await f.resume();
    },
  );
  test(
    'write/flush failure poisons evidence; cannot import partial source',
    () async {
      await expectLater(
        fence.write('history', () async => throw StateError('flush')),
        throwsStateError,
      );
      await expectLater(fence.pauseAndDrain(), throwsStateError);
      expect(fence.paused, false);
    },
  );
  test('same-writer drain fails fast, no self deadlock', () async {
    await expectLater(
      fence.write('history', fence.pauseAndDrain),
      throwsStateError,
    );
  });
  test(
    'real Hive writer proxy drains put/flush, rejects pause mutations, target unaffected',
    () async {
      final hive = HiveImpl()..init(root.path);
      final raw = await hive.openBox<dynamic>('source');
      SourceWriterBoundary.installForTesting(fence);
      final wrapped = SourceWriterBoundary.box('history', raw);
      await wrapped.put('id', {'value': 1});
      await fence.pauseAndDrain();
      await expectLater(wrapped.put('id', {'value': 2}), throwsStateError);
      expect(raw.get('id'), {'value': 1});
      final target = await Directory.systemTemp.createTemp('driveit_target_');
      await fence.write('scoped', () async {}, path: target.path);
      await target.delete();
      await fence.resume();
      await wrapped.close();
      await SourceWriterBoundary.detachForTesting(fence);
    },
  );
}
