import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/legacy_asset_transfer.dart';
import 'package:driveit_project/services/legacy_claim_ledger.dart';
import 'package:driveit_project/services/legacy_account_import.dart';
import 'package:driveit_project/services/legacy_source_writer_fence.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_revision_repository.dart';
import 'package:driveit_project/services/owner_revision_models.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/legacy_import_fixture.dart';

const _ownerA = importA;
const _ownerB = importB;
String _hex64(String value) => List.filled(64, value).join();

class _DomainVerifier implements OwnerRevisionDomainVerifier {
  _DomainVerifier({this.fail = false});
  final bool fail;

  @override
  Future<Map<String, Object?>> verify(
    OwnerRevisionSnapshot snapshot,
    List<OwnerRevisionRecord> plannedRecords,
  ) async {
    if (fail) throw const ImportFailure('synthetic_domain_conflict');
    return {
      'verified': true,
      'relationshipsVerified': true,
      'worldGenerationVerified': true,
      'worldRulesVersion': 6,
      'careerMergeVerified': true,
      'profileMergeVerified': true,
      'planetOutboxVerified': true,
      'posterAssetsVerified': true,
      'recordCount': plannedRecords.length,
    };
  }
}

class _Fence implements RegisteredSourceWriterFence {
  bool paused = false;
  bool failPause = false;
  int pauses = 0;
  int resumes = 0;

  @override
  void requireRegistered() {}

  @override
  Future<void> pauseAndDrain() async {
    if (failPause) throw StateError('synthetic drain failure');
    if (paused) throw StateError('already paused');
    paused = true;
    pauses++;
  }

  @override
  Future<void> resume() async {
    if (!paused) throw StateError('not paused');
    paused = false;
    resumes++;
  }
}

OwnerRevisionRecord _record({
  required String group,
  required String key,
  required String provenance,
  required String payload,
  OwnerRevisionOrigin origin = OwnerRevisionOrigin.owner,
  String? namespace,
  String? fingerprint,
  String? tombstoneTarget,
  String? unresolvedCode,
}) => OwnerRevisionRecord(
  group: group,
  logicalKey: key,
  sourceIdentity: provenance,
  origin: origin,
  payload: utf8.encode(payload),
  sourceNamespace: namespace,
  sourceFingerprint: fingerprint,
  tombstoneTargetIdentity: tombstoneTarget,
  unresolvedCode: unresolvedCode,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late ImportFixture fixture;
  late LocalOwnerLifecycle ownerRuntime;
  late LegacyClaimLedger ledger;
  late OwnerRevisionRepository revisions;
  late Directory root;
  late _Fence fence;
  late LocalOwnerLease lease;
  late VerifiedLegacyImport imported;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_owner_revision_');
    fixture = ImportFixture(root, databaseFactoryFfi);
    await fixture.start();
    imported = await fixture
        .run(); // Completed synthetic claim; not a live screen import.
    ownerRuntime = fixture.runtime;
    lease = ownerRuntime.lease;
    ledger = fixture.ledger;
    revisions = OwnerRevisionRepository(
      ledger: ledger,
      gate: LocalOwnershipGate.synthetic(),
      domainVerifier: _DomainVerifier(),
    );
    fence = _Fence();
  });

  tearDown(() async {
    await fixture.close();
  });

  test(
    'legacy claim-ledger v1 upgrades additively and preserves completed claim',
    () async {
      final path = '${root.path}/ledger-v1.sqlite';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE claims (
            source_namespace TEXT PRIMARY KEY,
            version INTEGER NOT NULL,
            fingerprint TEXT NOT NULL,
            owner_uuid TEXT NOT NULL,
            operation_id TEXT NOT NULL UNIQUE,
            state TEXT NOT NULL,
            attempts INTEGER NOT NULL,
            created_us INTEGER NOT NULL,
            updated_us INTEGER NOT NULL,
            completed_us INTEGER,
            evidence TEXT,
            error_code TEXT)''');
            await db.execute('''CREATE TABLE record_receipts (
            operation_id TEXT NOT NULL REFERENCES claims(operation_id),
            source_group TEXT NOT NULL, source_key TEXT NOT NULL,
            target_key TEXT NOT NULL, source_sha TEXT NOT NULL, target_sha TEXT NOT NULL,
            PRIMARY KEY(operation_id,source_group,source_key),
            UNIQUE(operation_id,source_group,target_key))''');
            await db.execute(
              '''CREATE TABLE asset_receipts (
            operation_id TEXT NOT NULL REFERENCES claims(operation_id),
            asset_id TEXT NOT NULL, sha256 TEXT NOT NULL, bytes INTEGER NOT NULL,
            relative_path TEXT NOT NULL, PRIMARY KEY(operation_id,asset_id))''',
            );
            await db.insert('claims', {
              'source_namespace': 'synthetic-legacy-source',
              'version': 1,
              'fingerprint': 'legacy-fingerprint',
              'owner_uuid': _ownerA,
              'operation_id': 'synthetic-operation',
              'state': 'completed',
              'attempts': 1,
              'created_us': 1,
              'updated_us': 2,
              'completed_us': 2,
              'evidence': '{}',
            });
            await db.insert('record_receipts', {
              'operation_id': 'synthetic-operation',
              'source_group': 'drives',
              'source_key': 'drive-old',
              'target_key': 'drive-old',
              'source_sha': _hex64('a'),
              'target_sha': _hex64('a'),
            });
            await db.insert('asset_receipts', {
              'operation_id': 'synthetic-operation',
              'asset_id': 'poster-old',
              'sha256': _hex64('b'),
              'bytes': 123,
              'relative_path': 'posters/poster-old.png',
            });
          },
        ),
      );
      await old.close();
      final upgraded = await LegacyClaimLedger.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      expect(await upgraded.completedForOwner(_ownerA), hasLength(1));
      expect(await upgraded.db.query('record_receipts'), hasLength(1));
      expect(await upgraded.db.query('asset_receipts'), hasLength(1));
      final tables = await upgraded.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      expect(
        tables.map((row) => row['name']),
        containsAll([
          'owner_revisions',
          'owner_revision_records',
          'owner_revision_assets',
          'owner_revision_pointer',
          'import_visibility',
        ]),
      );
      await upgraded.close();
    },
  );

  OwnerRevisionSnapshot snapshot({
    String ownerUuid = _ownerA,
    String? base,
    List<OwnerRevisionRecord> records = const [],
    List<OwnerRevisionAsset> assets = const [],
    String? fingerprint,
  }) => OwnerRevisionSnapshot(
    ownerUuid: ownerUuid,
    expectedBaseRevisionId: base,
    sourceRevision: base ?? 'legacy-owner-baseline-v1',
    sourceFingerprint:
        fingerprint ??
        OwnerRevisionRepository.fingerprintSourceSnapshot(records, assets),
    importNamespace: fixture.inventory.namespace,
    importFingerprint: fixture.inventory.fingerprint,
    coveredGroups: OwnerScopedLocalStore.groups.toSet(),
    records: records,
    assets: assets,
  );

  Future<OwnerRevisionPublication> publish(
    OwnerRevisionSnapshot input, {
    Future<bool> Function()? current,
    Future<void> Function(String)? boundary,
    OwnerRevisionDomainVerifier? verifier,
    Future<bool> Function(OwnerRevisionAsset)? verifyAsset,
  }) =>
      OwnerRevisionRepository(
        ledger: ledger,
        gate: LocalOwnershipGate.synthetic(),
        domainVerifier: verifier ?? _DomainVerifier(),
        verifyAsset: verifyAsset,
        boundary: boundary,
      ).prepareVerifyPublish(
        lease: lease,
        snapshot: input,
        imported: imported,
        writerFence: fence,
        sourceIsCurrent: current ?? () async => true,
      );

  test('stale snapshot fingerprint is rejected before writers pause', () async {
    final record = _record(
      group: 'drives',
      key: 'd',
      provenance: 'source:d',
      payload: 'contents',
    );
    await expectLater(
      publish(snapshot(records: [record], fingerprint: _hex64('f'))),
      throwsA(
        isA<ImportFailure>().having(
          (error) => error.code,
          'code',
          'revision_source_fingerprint_mismatch',
        ),
      ),
    );
    expect(fence.pauses, 0);
    expect(await ledger.db.query('owner_revision_pointer'), isEmpty);
  });

  test(
    'verified revision publishes once and discovery remains owner scoped',
    () async {
      final record = _record(
        group: 'drives',
        key: 'same-drive-id',
        provenance: 'source:legacy-a:drive-1',
        payload: 'canonical-drive-bytes',
      );
      final result = await publish(snapshot(records: [record]));
      expect(result.generation, 1);
      expect(result.idempotent, isFalse);
      expect(
        (await revisions.activePointer(_ownerA))?.revisionId,
        result.revisionId,
      );
      expect(
        (await revisions.visibleRecords(
          lease,
        )).any((r) => r.logicalKey == 'same-drive-id'),
        isTrue,
      );
      expect(result.recordCount, imported.revisionRecords().length + 1);
      expect(await ledger.completedForOwner(_ownerA), hasLength(1));

      final retry = await publish(snapshot(records: [record]));
      expect(retry.revisionId, result.revisionId);
      expect(retry.generation, 1);
      expect(retry.idempotent, isTrue);
      expect((await ledger.db.query('owner_revision_pointer')), hasLength(1));
      expect((await ledger.db.query('import_visibility')), hasLength(1));
    },
  );

  test(
    'different provenance with same logical key remains two records',
    () async {
      final first = _record(
        group: 'drives',
        key: jsonEncode('old'),
        provenance: 'origin:owner',
        payload: 'one',
      );
      final result = await publish(snapshot(records: [first]));
      expect(result.recordCount, imported.revisionRecords().length + 1);
      expect(
        await revisions.visibleRecords(lease),
        hasLength(result.recordCount),
      );
      expect(
        (await revisions.visibleRecords(lease))
            .where(
              (row) =>
                  row.group == 'drives' && row.logicalKey == jsonEncode('old'),
            )
            .length,
        2,
      );
    },
  );

  test('same proven source and bytes are an idempotent duplicate', () async {
    final legacy = imported.revisionRecords().singleWhere(
      (row) => row.group == 'drives' && row.key == 'old',
    );
    final duplicate = OwnerRevisionRecord(
      group: legacy.group,
      logicalKey: jsonEncode(legacy.key),
      sourceIdentity: legacy.sourceIdentity,
      origin: OwnerRevisionOrigin.owner,
      payload: legacy.payload,
    );
    final result = await publish(snapshot(records: [duplicate]));
    expect(result.recordCount, imported.revisionRecords().length);
    expect(
      (await revisions.visibleRecords(lease)).where(
        (row) => row.group == 'drives' && row.logicalKey == jsonEncode('old'),
      ),
      hasLength(1),
    );
  });

  test(
    'same provenance with different content is an explicit conflict',
    () async {
      final legacy = imported.revisionRecords().singleWhere(
        (row) => row.group == 'drives' && row.key == 'old',
      );
      final conflict = OwnerRevisionRecord(
        group: 'drives',
        logicalKey: jsonEncode('old'),
        sourceIdentity: legacy.sourceIdentity,
        origin: OwnerRevisionOrigin.owner,
        payload: utf8.encode('different source bytes'),
      );
      await expectLater(
        publish(snapshot(records: [conflict])),
        throwsA(
          isA<OwnerRevisionConflict>().having(
            (e) => e.codes,
            'codes',
            contains('same_provenance_content_conflict'),
          ),
        ),
      );
      expect(await revisions.activePointer(_ownerA), isNull);
      expect(await ledger.db.query('import_visibility'), isEmpty);
    },
  );

  test(
    'ambiguous records and unresolved cumulative Career block publish',
    () async {
      final ambiguous = _record(
        group: 'drives',
        key: 'd',
        provenance: '',
        payload: 'x',
      );
      await expectLater(
        publish(snapshot(records: [ambiguous])),
        throwsA(isA<OwnerRevisionConflict>()),
      );
      final cumulative = _record(
        group: 'career_totals',
        key: 'baseline',
        provenance: 'legacy:career',
        payload: 'cumulative-only',
        unresolvedCode: 'career_cumulative_provenance_unresolved',
      );
      await expectLater(
        publish(snapshot(records: [cumulative])),
        throwsA(
          isA<OwnerRevisionConflict>().having(
            (e) => e.codes,
            'codes',
            contains('career_cumulative_provenance_unresolved'),
          ),
        ),
      );
    },
  );

  test(
    'exact-source tombstone suppresses source but not same ID other provenance',
    () async {
      final removed = _record(
        group: 'my_world_source_snapshots_v1',
        key: 'd',
        provenance: 'world-source:A',
        payload: 'a',
      );
      final stillOwned = _record(
        group: 'my_world_source_snapshots_v1',
        key: 'd',
        provenance: 'world-source:B',
        payload: 'b',
      );
      final tombstone = _record(
        group: 'local_lifecycle_v1',
        key: 'world:A',
        provenance: 'tombstone:A',
        payload: 'deleted',
        tombstoneTarget: 'world-source:A',
      );
      final result = await publish(
        snapshot(records: [removed, stillOwned, tombstone]),
      );
      final visible = await revisions.visibleRecords(lease);
      expect(result.recordCount, imported.revisionRecords().length + 2);
      expect(visible.map((r) => r.sourceIdentity), contains('world-source:B'));
      expect(
        visible.map((r) => r.sourceIdentity),
        isNot(contains('world-source:A')),
      );
    },
  );

  test('profile and Planet outbox same-key conflicts fail closed', () async {
    for (final group in ['profile', 'planet_segment_outbox_v1']) {
      final a = _record(
        group: group,
        key: 'entry',
        provenance: 'p:a',
        payload: 'first',
      );
      final b = _record(
        group: group,
        key: 'entry',
        provenance: 'p:b',
        payload: 'second',
      );
      await expectLater(
        publish(snapshot(records: [a, b])),
        throwsA(isA<OwnerRevisionConflict>()),
      );
    }
    expect(await ledger.db.query('owner_revision_pointer'), isEmpty);
  });

  test(
    'missing asset verifier and corrupt asset evidence block publish',
    () async {
      final good = OwnerRevisionAsset(
        sourceNamespace: 'placeholder',
        id: 'poster',
        sha256: _hex64('b'),
        bytes: 10,
        relativePath: 'assets/poster.png',
      );
      final bad = OwnerRevisionAsset(
        sourceNamespace: fixture.inventory.namespace,
        id: 'poster',
        sha256: 'x',
        bytes: 10,
        relativePath: '../outside.png',
      );
      await expectLater(
        publish(snapshot(assets: [good])),
        throwsA(isA<OwnerRevisionConflict>()),
      );
      await expectLater(
        publish(snapshot(assets: [bad])),
        throwsA(isA<OwnerRevisionConflict>()),
      );
      final valid = OwnerRevisionAsset(
        sourceNamespace: GpsOwner.account(_ownerA).targetStore,
        id: 'poster',
        sha256: _hex64('b'),
        bytes: 10,
        relativePath: 'assets/poster.png',
      );
      await expectLater(
        publish(snapshot(assets: [valid]), verifyAsset: (_) async => false),
        throwsA(
          isA<ImportFailure>().having(
            (e) => e.code,
            'code',
            'revision_asset_verification_failed',
          ),
        ),
      );
      expect(await ledger.db.query('import_visibility'), isEmpty);
    },
  );

  test(
    'fault before pointer commit leaves old view and verified retry publishes',
    () async {
      final record = _record(
        group: 'drives',
        key: 'd',
        provenance: 'source:stable',
        payload: 'data',
      );
      await expectLater(
        publish(
          snapshot(records: [record]),
          boundary: (stage) async {
            if (stage == 'pointer_write') {
              throw StateError('synthetic interruption');
            }
          },
        ),
        throwsStateError,
      );
      expect(await revisions.activePointer(_ownerA), isNull);
      expect(await revisions.visibleRecords(lease), isEmpty);
      expect(
        (await ledger.db.query('owner_revisions')).single['state'],
        'verified',
      );
      final result = await publish(snapshot(records: [record]));
      expect(result.generation, 1);
      expect(
        await revisions.visibleRecords(lease),
        hasLength(result.recordCount),
      );
    },
  );

  for (final interruptedStage in [
    'record_staged',
    'prepared',
    'verify_after',
  ]) {
    test(
      'restart recovery after $interruptedStage keeps staged rows hidden',
      () async {
        final record = _record(
          group: 'drives',
          key: 'local-drive',
          provenance: 'owner-source:local-drive',
          payload: 'existing-owner-drive',
        );
        await expectLater(
          publish(
            snapshot(records: [record]),
            boundary: (stage) async {
              if (stage == interruptedStage) {
                throw StateError('synthetic process interruption');
              }
            },
          ),
          throwsStateError,
        );
        expect(await revisions.activePointer(_ownerA), isNull);
        expect(await revisions.visibleRecords(lease), isEmpty);
        if (interruptedStage == 'record_staged') {
          expect(await ledger.db.query('owner_revisions'), isEmpty);
        } else {
          final row = (await ledger.db.query('owner_revisions')).single;
          expect(
            row['state'],
            interruptedStage == 'prepared' ? 'preparing' : 'verified',
          );
        }
        final retried = await publish(snapshot(records: [record]));
        expect(retried.generation, 1);
        expect(
          await revisions.visibleRecords(lease),
          hasLength(retried.recordCount),
        );
      },
    );
  }

  test(
    'fault after pointer write rolls back transaction; lost response retries idempotently',
    () async {
      final record = _record(
        group: 'drives',
        key: 'd',
        provenance: 'source:stable',
        payload: 'data',
      );
      await expectLater(
        publish(
          snapshot(records: [record]),
          boundary: (stage) async {
            if (stage == 'pointer_written') {
              throw StateError('rollback transaction');
            }
          },
        ),
        throwsStateError,
      );
      expect(await revisions.activePointer(_ownerA), isNull);
      expect(await ledger.db.query('import_visibility'), isEmpty);
      await expectLater(
        publish(
          snapshot(records: [record]),
          boundary: (stage) async {
            if (stage == 'published_response') {
              throw StateError('response lost');
            }
          },
        ),
        throwsStateError,
      );
      expect((await revisions.activePointer(_ownerA))?.generation, 1);
      final retried = await publish(snapshot(records: [record]));
      expect(retried.idempotent, isTrue);
      expect(retried.generation, 1);
    },
  );

  test(
    'domain verification and changed source stop before pointer publication',
    () async {
      final record = _record(
        group: 'drives',
        key: 'd',
        provenance: 'source:stable',
        payload: 'data',
      );
      await expectLater(
        publish(
          snapshot(records: [record]),
          verifier: _DomainVerifier(fail: true),
        ),
        throwsA(
          isA<ImportFailure>().having(
            (e) => e.code,
            'code',
            'synthetic_domain_conflict',
          ),
        ),
      );
      await expectLater(
        publish(snapshot(records: [record]), current: () async => false),
        throwsA(
          isA<ImportFailure>().having(
            (e) => e.code,
            'code',
            'revision_source_changed',
          ),
        ),
      );
      expect(await revisions.activePointer(_ownerA), isNull);
    },
  );

  test(
    'base generation CAS rejects stale publisher and writer fence resumes',
    () async {
      final record = _record(
        group: 'drives',
        key: 'd',
        provenance: 'source:stable',
        payload: 'data',
      );
      final result = await publish(snapshot(records: [record]));
      expect(result.generation, 1);
      // A different import would be required for another generation; stale base
      // is rejected before any second visibility operation can be committed.
      final stale = snapshot(records: [record], base: 'stale-base');
      await expectLater(publish(stale), throwsA(isA<ImportFailure>()));
      expect(
        (await revisions.activePointer(_ownerA))?.revisionId,
        result.revisionId,
      );
      expect(fence.paused, isFalse);
      expect(fence.pauses, fence.resumes);
    },
  );

  test('lease epoch revocation during verify cannot publish', () async {
    final record = _record(
      group: 'drives',
      key: 'd',
      provenance: 'source:stable',
      payload: 'data',
    );
    await expectLater(
      publish(
        snapshot(records: [record]),
        boundary: (stage) async {
          if (stage == 'verify_after') fixture.auth.change(_ownerB);
        },
      ),
      throwsStateError,
    );
    expect(await revisions.activePointer(_ownerA), isNull);
    expect(fence.paused, isFalse);
  });

  test('owner B cannot read owner A visible pointer', () async {
    final record = _record(
      group: 'drives',
      key: 'd',
      provenance: 'source:stable',
      payload: 'data',
    );
    await publish(snapshot(records: [record]));
    fixture.auth.change(_ownerB);
    final ready = Completer<void>();
    void onOwnerChanged() {
      if (ownerRuntime.state == LocalOwnerState.ready &&
          ownerRuntime.lease.owner.userId == _ownerB &&
          !ready.isCompleted) {
        ready.complete();
      }
    }

    ownerRuntime.addListener(onOwnerChanged);
    onOwnerChanged();
    await ready.future.timeout(const Duration(seconds: 2));
    ownerRuntime.removeListener(onOwnerChanged);
    final bLease = ownerRuntime.lease;
    expect(bLease.owner.userId, _ownerB);
    expect(await revisions.activePointer(_ownerB), isNull);
    expect(await revisions.visibleRecords(bLease), isEmpty);
    expect((await revisions.activePointer(_ownerA))?.generation, 1);
  });

  test('closed gate and incomplete inventory fail closed', () async {
    final record = _record(
      group: 'drives',
      key: 'd',
      provenance: 'source:stable',
      payload: 'data',
    );
    final closed = OwnerRevisionRepository(
      ledger: ledger,
      gate: const LocalOwnershipGate.disabled(),
      domainVerifier: _DomainVerifier(),
    );
    await expectLater(
      closed.prepareVerifyPublish(
        lease: lease,
        snapshot: snapshot(records: [record]),
        imported: imported,
        writerFence: fence,
        sourceIsCurrent: () async => true,
      ),
      throwsA(
        isA<ImportFailure>().having(
          (e) => e.code,
          'code',
          'owner_revision_gate_closed',
        ),
      ),
    );
    final incomplete = OwnerRevisionSnapshot(
      ownerUuid: _ownerA,
      expectedBaseRevisionId: null,
      sourceRevision: 'base',
      sourceFingerprint: 'source-snapshot-fingerprint-c',
      importNamespace: fixture.inventory.namespace,
      importFingerprint: fixture.inventory.fingerprint,
      coveredGroups: const {'drives'},
      records: [record],
      assets: const [],
    );
    await expectLater(
      publish(incomplete),
      throwsA(
        isA<ImportFailure>().having(
          (e) => e.code,
          'code',
          'revision_inventory_incomplete',
        ),
      ),
    );
    expect(await ledger.db.query('owner_revision_pointer'), isEmpty);
  });
}
