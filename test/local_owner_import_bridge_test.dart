import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/local_owner_import_bridge.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'support/legacy_import_fixture.dart';

class WriterFence implements LegacySourceWriterFence {
  final entered = Completer<void>();
  final drained = Completer<void>();
  bool paused = false;
  bool resumed = false;
  @override
  Future<void> pauseAndDrain() async {
    paused = true;
    entered.complete();
    await drained.future;
  }

  @override
  Future<void> resume() async {
    resumed = true;
    paused = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late ImportFixture f;
  setUp(() async {
    f = ImportFixture(
      await Directory.systemTemp.createTemp('driveit_5c2_import_'),
      databaseFactoryFfi,
    );
    await f.start();
  });
  tearDown(() async => f.close());
  test(
    'real registered source fence drains file writer before import and resumes',
    () async {
      final fence = LocalSourceWriterFence(
        gate: LocalOwnershipGate.synthetic(),
        gpsBusy: f.runtime.driveInProgress,
        sourceRoots: [f.oldRoot.path, f.documents.path],
        provenCategories: LocalSourceWriterFence.requiredCategories,
      );
      SourceWriterBoundary.installForTesting(fence);
      final entered = Completer<void>(), done = Completer<void>();
      final writing = SourceWriterBoundary.run('poster', () async {
        entered.complete();
        await done.future;
        // Synthetic existing file, unchanged bytes: import fingerprint remains exact.
        await File(
          '${f.documents.path}/map.png',
        ).writeAsBytes(f.png, flush: true);
      }, path: f.documents.path);
      await entered.future;
      final operation = LocalOwnerImportBridge(
        runtime: f.runtime,
        importer: f.importer(),
        writerFence: fence,
      ).approve(source: f.source, consent: f.consent);
      try {
        // Let the owner-operation admission reach the drain without arbitrary delay.
        await Future<void>.value();
        await Future<void>.value();
        expect(await f.ledger.get(f.inventory.namespace), null);
        done.complete();
        await writing;
        final result = await operation;
        f.readers.add(result);
        expect(result.keys('drives'), ['old']);
        expect(fence.paused, false);
        expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
      } finally {
        if (!done.isCompleted) done.complete();
        await writing;
        await SourceWriterBoundary.detachForTesting(fence);
      }
    },
  );
  test('uninstalled real fence never reserves or copies source', () async {
    final fence = LocalSourceWriterFence(
      gate: LocalOwnershipGate.synthetic(),
      gpsBusy: () async => false,
      sourceRoots: [f.oldRoot.path, f.documents.path],
      provenCategories: LocalSourceWriterFence.requiredCategories,
    );
    await expectLater(
      LocalOwnerImportBridge(
        runtime: f.runtime,
        importer: f.importer(),
        writerFence: fence,
      ).approve(source: f.source, consent: f.consent),
      throwsStateError,
    );
    expect(await f.ledger.get(f.inventory.namespace), null);
  });
  test(
    'no reservation or source copy before source writer drain; completed view only',
    () async {
      final fence = WriterFence();
      final bridge = LocalOwnerImportBridge(
        runtime: f.runtime,
        importer: f.importer(),
        writerFence: fence,
      );
      final pending = bridge.approve(source: f.source, consent: f.consent);
      await fence.entered.future;
      expect(await f.ledger.get(f.inventory.namespace), null);
      expect(f.runtime.lease.keys('drives'), isEmpty);
      fence.drained.complete();
      final result = await pending;
      f.readers.add(result);
      expect(result.keys('drives'), ['old']);
      expect(fence.resumed, true);
      expect((await f.ledger.get(f.inventory.namespace))!.completed, true);
      expect(
        f.runtime.lease.drives(),
        isEmpty,
      ); // No unsafe live-store promotion.
    },
  );
  test(
    'Auth invalidates consent during drain, no import; fence is released',
    () async {
      final fence = WriterFence();
      final bridge = LocalOwnerImportBridge(
        runtime: f.runtime,
        importer: f.importer(),
        writerFence: fence,
      );
      final pending = bridge.approve(source: f.source, consent: f.consent);
      final checked = expectLater(pending, throwsStateError);
      await fence.entered.future;
      f.auth.change(importB);
      fence.drained.complete();
      await checked;
      await f.runtime.settled;
      expect(await f.ledger.get(f.inventory.namespace), null);
      expect(fence.resumed, true);
      expect(f.runtime.lease.owner.userId, importB);
    },
  );
  test(
    'interrupted import releases source fence, preserves source and retries',
    () async {
      final fence = WriterFence()..drained.complete();
      final importer = f.importer(
        boundary: (stage) async {
          if (stage == 'record_flushed') {
            throw StateError('controlled interruption');
          }
        },
      );
      await expectLater(
        LocalOwnerImportBridge(
          runtime: f.runtime,
          importer: importer,
          writerFence: fence,
        ).approve(source: f.source, consent: f.consent),
        throwsStateError,
      );
      expect(fence.resumed, true);
      expect((await f.ledger.get(f.inventory.namespace))!.completed, false);
      expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
      final retryFence = WriterFence()..drained.complete();
      final result = await LocalOwnerImportBridge(
        runtime: f.runtime,
        importer: f.importer(),
        writerFence: retryFence,
      ).approve(source: f.source, consent: f.consent);
      f.readers.add(result);
      expect(result.keys('drives'), ['old']);
    },
  );
}
