import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/legacy_asset_transfer.dart';
import 'package:driveit_project/services/legacy_claim_ledger.dart';
import 'package:driveit_project/services/legacy_import_inventory.dart';
import 'support/legacy_import_fixture.dart';

Matcher fails(String code) =>
    throwsA(isA<ImportFailure>().having((e) => e.code, 'code', code));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late ImportFixture f;
  setUp(() async {
    f = ImportFixture(
      await Directory.systemTemp.createTemp('driveit_import_synthetic_'),
      databaseFactoryFfi,
    );
    await f.start();
  });
  tearDown(() async => f.close());
  test(
    'poster/map/background/score/telemetry/World/Career preserved; source unchanged',
    () async {
      final result = await f.run();
      final drive = result.read<DriveSession>('drives', 'old')!;
      expect(drive.mapImagePath, isNot('${f.documents.path}/map.png'));
      expect(
        await (await result.file(drive.mapImagePath)).readAsBytes(),
        f.png,
      );
      expect(await (await result.posterFile('poster')).readAsBytes(), f.png);
      final poster = result.read<Map>('drive_posters', 'poster')!;
      expect(
        await (await result.file(poster['backgroundReference'])).readAsBytes(),
        f.png,
      );
      expect(poster['themeId'], 'blackout');
      expect(poster['fileName'], poster['exportedPosterPath']);
      expect(drive.route.last.legacyHiveFields[2], DateTime.utc(2025, 9, 28));
      expect(
        result.read<DriveScoreRecord>('drive_scores', 'old:v1')!.totalScore,
        700,
      );
      expect(
        result
            .read<DriveTelemetryRecord>('drive_telemetry', 'old')!
            .points
            .length,
        37,
      );
      final world = jsonDecode(
        result.read<Map>('my_world_source_snapshots_v1', 'old')!['payload'],
      );
      expect(world['ownerScope'], GpsOwner.account(importA).targetStore);
      expect(result.keys('career_contributions_v1'), contains('drive:old'));
      expect(result.keys('planet_segment_outbox_v1'), [
        jsonEncode([GpsOwner.account(importA).targetStore, 'segment']),
      ]);
      expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
      expect(
        f.old.box<DriveSession>('drives').get('old')!.mapImagePath,
        '${f.documents.path}/map.png',
      );
      expect((await f.ledger.get(f.inventory.namespace))!.completed, true);
      expect(
        f.runtime.lease.drives(),
        isEmpty,
      ); // Not prematurely promoted into live boxes.
    },
  );
  test(
    'completed retry is idempotent and read-only receipts cannot change',
    () async {
      await f.run();
      await f.closeReaders();
      final claim = (await f.ledger.get(f.inventory.namespace))!;
      final again = await f.run();
      expect(again.keys('drives'), ['old']);
      expect(
        (await f.ledger.get(f.inventory.namespace))!.operationId,
        claim.operationId,
      );
      expect((await f.ledger.get(f.inventory.namespace))!.row['attempts'], 1);
      await expectLater(
        f.ledger.db.delete('asset_receipts'),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        f.ledger.db.delete('claims'),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
  for (final stage in [
    'record_flushed',
    'file_flushed',
    'verified',
    'before_ledger_commit',
  ]) {
    test(
      'controlled interruption $stage: invisible then same-owner recovery',
      () async {
        await expectLater(
          f.run(
            f.importer(
              boundary: (s) async {
                if (s == stage) throw StateError('synthetic interruption');
              },
            ),
          ),
          throwsStateError,
        );
        final claim = (await f.ledger.get(f.inventory.namespace))!;
        expect(claim.completed, false);
        expect(await f.ledger.db.query('record_receipts'), isEmpty);
        await expectLater(
          f.importer().openVerified(
            namespace: claim.namespace,
            lease: f.runtime.lease,
          ),
          fails('import_not_visible'),
        );
        final recovered = await f.run();
        expect(recovered.keys('drives'), ['old']);
        expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
      },
    );
  }
  test('response lost after commit: retry uses completed result', () async {
    await expectLater(
      f.run(
        f.importer(
          boundary: (s) async {
            if (s == 'ledger_committed') throw StateError('lost response');
          },
        ),
      ),
      throwsStateError,
    );
    expect((await f.ledger.get(f.inventory.namespace))!.completed, true);
    expect((await f.run()).keys('drives'), ['old']);
  });
  test('flush error leaves source intact and retry completes', () async {
    await expectLater(
      f.run(
        f.importer(
          beforeFlush: (g) async {
            if (g == 'drives') throw StateError('flush');
          },
        ),
      ),
      throwsStateError,
    );
    expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
    expect((await f.run()).keys('drives'), ['old']);
  });
  test('disk insufficient does not mark completed', () async {
    f.disk.free = 0;
    await expectLater(f.run(), fails('insufficient_disk_space'));
    expect((await f.ledger.get(f.inventory.namespace))!.completed, false);
    f.disk.free = 1 << 40;
    await f.run();
  });
  test('native durability failure never produces visible import', () async {
    f.disk.failSync = true;
    await expectLater(f.run(), fails('synthetic_fsync_failed'));
    expect((await f.ledger.get(f.inventory.namespace))!.completed, false);
  });
  test(
    'missing selected background fails before reserving ownership',
    () async {
      await File('${f.documents.path}/posters/background.png').delete();
      await expectLater(f.run(), fails('source_file_missing'));
      expect(await f.ledger.get(f.inventory.namespace), null);
    },
  );
  for (final path in [
    'content://synthetic/unavailable',
    '../outside.png',
    '/not-accessible-private-image.png',
  ]) {
    test('inaccessible or unsafe path rejected: $path', () async {
      final drive = f.old.box<DriveSession>('drives').get('old')!;
      drive.mapImagePath = path;
      await f.old.box<DriveSession>('drives').put('old', drive);
      await expectLater(f.source.survey(), throwsA(isA<ImportFailure>()));
      expect(await f.ledger.get(f.inventory.namespace), null);
    });
  }
  test('conflicting saved poster aliases rejected', () async {
    final row = Map.from(f.old.box<dynamic>('drive_posters').get('poster'));
    row['exportedPosterPath'] = 'background.png';
    await f.old.box<dynamic>('drive_posters').put('poster', row);
    await f.approve();
    await expectLater(f.run(), fails('poster_alias_conflict'));
  });
  test('owner change invalidates approval and completed reader', () async {
    final reader = await f.run();
    f.auth.change(importB);
    await f.runtime.settled;
    expect(() => reader.read('drives', 'old'), throwsStateError);
    await expectLater(
      f.importer().openVerified(
        namespace: f.inventory.namespace,
        lease: f.runtime.lease,
      ),
      fails('import_not_visible'),
    );
    await f.approve();
    await expectLater(f.run(), fails('legacy_claim_conflict'));
  });
  test('approval expires during copying; reservation remains A', () async {
    await expectLater(
      f.run(
        f.importer(
          boundary: (s) async {
            if (s == 'file_flushed') {
              f.auth.change(importB);
              await f.runtime.settled;
            }
          },
        ),
      ),
      throwsStateError,
    );
    final claim = (await f.ledger.get(f.inventory.namespace))!;
    expect(claim.owner.userId, importA);
    expect(claim.completed, false);
    f.auth.change(importA);
    await f.runtime.settled;
    await f.approve();
    await f.run();
  });
  test(
    'independent SQLite connections race A/B; durable single winner',
    () async {
      final second = await LegacyClaimLedger.open(
        factory: databaseFactoryFfi,
        path: '${f.root.path}/claims.sqlite',
      );
      Future<Object> reserve(LegacyClaimLedger l, String owner) async {
        try {
          return await l.reserve(
            'race',
            'fingerprint',
            GpsOwner.account(owner),
          );
        } catch (e) {
          return e;
        }
      }

      try {
        final results = await Future.wait([
          reserve(f.ledger, importA),
          reserve(second, importB),
        ]);
        expect(results.whereType<LegacyClaim>().length, 1);
        final winner = (await second.get('race'))!;
        expect(
          results.where((r) => r is! LegacyClaim).single,
          anyOf(isA<DatabaseException>(), isA<ImportFailure>()),
        );
        await expectLater(
          second.reserve(
            'race',
            'fingerprint',
            GpsOwner.account(
              winner.owner.userId == importA ? importB : importA,
            ),
          ),
          fails('legacy_claim_conflict'),
        );
        await expectLater(
          second.db.update(
            'claims',
            {'owner_uuid': winner.owner.userId == importA ? importB : importA},
            where: 'source_namespace=?',
            whereArgs: ['race'],
          ),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await second.close();
      }
    },
  );
  test(
    'large asset streams bounded chunks; partial file recovers without overwrite',
    () async {
      final large = File('${f.documents.path}/posters/background.png');
      final output = await large.open(mode: FileMode.write);
      final block = Uint8List(65536)..fillRange(0, 65536, 17);
      for (var i = 0; i < 161; i++) {
        await output.writeFrom(block);
      }
      await output.flush();
      await output.close();
      await f.approve();
      var maximum = 0;
      var stop = true;
      await expectLater(
        f.run(
          f.importer(
            onChunk: (n) async {
              maximum = n > maximum ? n : maximum;
              if (n >= 65536 && stop) {
                stop = false;
                throw StateError('disk interrupted');
              }
            },
          ),
        ),
        throwsStateError,
      );
      final assets = f.inventory.assets;
      final root = Directory('${f.root.path}/direct');
      await root.create();
      final copier = OwnerAssetTransfer(root: root, disk: f.disk);
      final canonical = await large.resolveSymbolicLinks();
      final asset = assets.singleWhere((a) => a.sourcePath == canonical);
      await copier.copy(asset);
      expect(copier.largestChunk, lessThanOrEqualTo(65536));
      await f.run();
      expect(maximum, 65536);
      expect(await large.length(), 161 * 65536);
      final target = await copier.fileFor(asset);
      await target.writeAsBytes([9], flush: true);
      await expectLater(copier.copy(asset), fails('file_hash_mismatch'));
      expect(await target.readAsBytes(), [9]);
    },
  );
  test('source hash change while copying rejects completion', () async {
    var changed = false;
    await expectLater(
      f.run(
        f.importer(
          boundary: (s) async {
            if (s == 'capacity_verified' && !changed) {
              changed = true;
              await File(
                '${f.documents.path}/map.png',
              ).writeAsBytes([1, 2], flush: true);
            }
          },
        ),
      ),
      throwsA(isA<ImportFailure>()),
    );
    expect((await f.ledger.get(f.inventory.namespace))!.completed, false);
  });
  test('broken Drive/Poster relationship rejected', () async {
    final row = Map.from(f.old.box<dynamic>('drive_posters').get('poster'));
    row['driveId'] = 'missing';
    await f.old.box<dynamic>('drive_posters').put('poster', row);
    await f.approve();
    await expectLater(f.run(), fails('poster_drive_relation_missing'));
  });
  test(
    'single oversized record fails closed without flattening everything',
    () async {
      final bounded = LegacyImportSource(
        hive: f.old,
        hiveRoot: f.oldRoot,
        documents: f.documents,
        allowedFileRoots: [f.documents],
        groups: f.source.groups,
        maxRecordBytes: 32,
      );
      await expectLater(bounded.survey(), fails('record_too_large'));
    },
  );
  test('production gate remains OFF: no claim or file copy', () async {
    await expectLater(
      f.run(f.importer(gate: LocalOwnershipGate.production)),
      fails('ownership_disabled'),
    );
    expect(await f.ledger.db.query('claims'), isEmpty);
    expect(await Directory('${f.root.path}/imports').exists(), false);
  });
  test(
    'quarantine origin is not guessed as a second claim namespace',
    () async {
      final marker = await f.old.openBox<dynamic>('owner_manifest_v1');
      await marker.put('identity', {
        'scope': const GpsOwner.legacy().targetStore,
      });
      await expectLater(f.source.survey(), fails('source_origin_unproven'));
    },
  );
  test('unreviewed persisted box refuses incomplete inventory', () async {
    final unknown = await f.old.openBox<dynamic>('future_unknown');
    await unknown.put('id', {'data': 'synthetic'});
    await expectLater(f.source.survey(), fails('unreviewed_box_on_disk'));
  });
  test('file descriptor cannot escape the owner directory', () async {
    final root = await Directory('${f.root.path}/private').create();
    final asset = f.inventory.assets.first;
    final evil = ImportAsset(
      id: asset.id,
      sourcePath: asset.sourcePath,
      hash: asset.hash,
      bytes: asset.bytes,
      extension: 'png/../../../escaped',
    );
    await expectLater(
      OwnerAssetTransfer(root: root, disk: f.disk).copy(evil),
      fails('unsafe_asset_descriptor'),
    );
    expect(await File('${f.root.path}/escaped').exists(), false);
  });
  test(
    'many independent records retain counts/order with bounded record payload',
    () async {
      for (var i = 0; i < 500; i++) {
        await f.old.box<dynamic>('drive_names').put('synthetic:$i', 'name:$i');
      }
      await f.approve();
      final reader = await f.run();
      expect(reader.keys('drive_names').length, 501);
      expect(
        reader.keys('drive_names'),
        f.old.box<dynamic>('drive_names').keys.toList(),
      );
      expect(f.source.largestRecord, lessThan(64 * 1024));
      expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
    },
  );
}
