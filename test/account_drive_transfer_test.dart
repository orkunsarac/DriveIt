import 'dart:io';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/services/account_drive_transfer.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';
import 'package:driveit_project/services/legacy_drive_transfer_source.dart';
import 'local_lifecycle_foundation_test.dart' as data;

const transferA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const transferB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const transferSource = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

Future<void> seedTransferGuest(OwnerScopedLocalStore store) async {
  final original = data.fixture('guest-drive');
  final first = original.drive.route.first;
  original.drive.route[0] = RoutePoint(
    latitude: first.latitude,
    longitude: first.longitude,
    legacyHiveFields: {2: DateTime.utc(2020, 1, 2), 9: 'opaque-route-field'},
  );
  final proof = DriveSourceProvenance.proven(
    sourceIdentity: transferSource,
    ownerScope: store.scope,
  );
  final telemetry = original.telemetry!;
  await store.put(store.owner, 'drives', original.drive.id, original.drive);
  await store.put(
    store.owner,
    'drive_names',
    original.drive.id,
    'Sentetik kayıt adı',
  );
  await store.put(
    store.owner,
    'drive_telemetry',
    original.drive.id,
    DriveTelemetryRecord(
      driveSessionId: original.drive.id,
      dataVersion: 1,
      createdAt: telemetry.createdAt,
      points: telemetry.points,
      acquisitionMetadata: {
        ...telemetry.acquisitionMetadata,
        'provenanceStatus': 'proven',
        'sourceIdentity': transferSource,
        'sourceIdentityVersion': 1,
        'sourceNamespace': 'drive_source_v1',
      },
    ),
  );
  await store.put(
    store.owner,
    'drive_source_provenance_v1',
    original.drive.id,
    proof.toMap(),
  );
  await store.put(
    store.owner,
    'drive_scores',
    DriveScoreStorageService.keyFor(original.drive.id, 1),
    DriveScoreRecord(
      driveId: original.drive.id,
      algorithmVersion: 1,
      telemetryDataVersion: 1,
      calculatedAt: telemetry.createdAt,
      totalScore: 80,
      overallConfidence: .9,
      categories: const [],
    ),
  );
  await store.put(
    store.owner,
    'owned_drive_finalization_v1',
    original.drive.id,
    {'state': 'completed', 'derivedReady': true},
  );
}

class MemoryLegacyTransferSource implements LegacyTransferSource {
  MemoryLegacyTransferSource(this.rows);
  final List<LegacyTransferRow> rows;
  bool failRemoveOnce = false;
  @override
  Future<List<LegacyTransferRow>> read() async => rows.toList();
  @override
  Future<void> remove(LegacyTransferRow expected) async {
    if (failRemoveOnce) {
      failRemoveOnce = false;
      throw StateError('synthetic interrupted source removal');
    }
    rows.removeWhere(
      (r) => r.key == expected.key && r.fingerprint == expected.fingerprint,
    );
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late OwnerScopedLocalStore guest, target;
  String? failGroup;
  bool current = true;
  late AccountDriveTransfer transfer;
  Future<void> open() async {
    guest = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: const GpsOwner.guest(),
    );
    target = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: GpsOwner.account(transferA),
      beforeFlush: (group) async {
        if (failGroup == group) {
          failGroup = null;
          throw StateError('synthetic durability failure');
        }
      },
    );
    transfer = AccountDriveTransfer(
      target: target,
      guest: guest,
      requireCurrent: () {
        if (!current) throw StateError('revoked');
      },
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_transfer_');
    failGroup = null;
    current = true;
    await open();
  });
  tearDown(() async {
    await guest.close();
    await target.close();
    await root.delete(recursive: true);
  });

  test(
    'Guest moves only after verified History projections and durable outbox; retry exactly once',
    () async {
      await seedTransferGuest(guest);
      final result = await transfer.transferGuest();
      expect(result.transferred, 1);
      expect(result.localOnly, 0);
      expect(guest.keys(guest.owner, 'drives'), isEmpty);
      final ids = target.keys(target.owner, 'drives');
      expect(ids, hasLength(1));
      final drive = target.read<DriveSession>(
        target.owner,
        'drives',
        ids.single,
      )!;
      expect(drive.route.first.legacyHiveFields, {
        2: DateTime.utc(2020, 1, 2),
        9: 'opaque-route-field',
      });
      expect(drive.mapImagePath, 'old-unavailable.png');
      expect(
        driveTransferManifest(drive)
          ..remove('id')
          ..remove('mapImagePath'),
        driveTransferManifest(data.fixture('guest-drive').drive)
          ..remove('id')
          ..remove('mapImagePath'),
      );
      expect(
        target
            .read<DriveTelemetryRecord>(
              target.owner,
              'drive_telemetry',
              ids.single,
            )!
            .points,
        hasLength(37),
      );
      expect(
        target
            .read<DriveScoreRecord>(
              target.owner,
              'drive_scores',
              DriveScoreStorageService.keyFor(drive.id, 1),
            )!
            .totalScore,
        80,
      );
      expect(
        target
            .keys(target.owner, 'career_contributions_v1')
            .where((k) => k.toString().startsWith('source:')),
        hasLength(1),
      );
      expect(
        await target.worldSources(target.owner).getPendingJobs(),
        hasLength(1),
      );
      expect(
        OwnerDriveSyncClient(
          store: target,
          requireCurrent: () {},
        ).automaticPendingKeys(),
        hasLength(1),
      );
      expect((await transfer.transferGuest()).transferred, 0);
      expect(target.keys(target.owner, 'drives'), hasLength(1));
      expect(
        await target.worldSources(target.owner).getPendingJobs(),
        hasLength(1),
      );
    },
  );

  for (final group in ['drives', 'owner_sync_outbox_v1']) {
    test(
      'crash at $group preserves Guest and resumes on reopened stores',
      () async {
        await seedTransferGuest(guest);
        failGroup = group;
        await expectLater(transfer.transferGuest(), throwsStateError);
        expect(guest.keys(guest.owner, 'drives'), ['guest-drive']);
        await guest.close();
        await target.close();
        await open();
        expect((await transfer.transferGuest()).transferred, 1);
        expect(guest.keys(guest.owner, 'drives'), isEmpty);
        expect(target.keys(target.owner, 'drives'), hasLength(1));
        expect(
          OwnerDriveSyncClient(
            store: target,
            requireCurrent: () {},
          ).automaticPendingKeys(),
          hasLength(1),
        );
      },
    );
  }

  test(
    'partial A claim cannot be transferred by B; A resumes without duplicate',
    () async {
      await seedTransferGuest(guest);
      failGroup = 'drives';
      await expectLater(transfer.transferGuest(), throwsStateError);
      final other = await OwnerScopedLocalStore.open(
        root: root.path,
        owner: GpsOwner.account(transferB),
      );
      try {
        final b = AccountDriveTransfer(
          target: other,
          guest: guest,
          requireCurrent: () {},
        );
        expect(b.guestIds(), isEmpty);
        expect((await b.transferGuest()).transferred, 0);
        expect(other.keys(other.owner, 'drives'), isEmpty);
      } finally {
        await other.close();
      }
      expect((await transfer.transferGuest()).transferred, 1);
    },
  );

  test(
    'revoked owner cannot read transfer inventory or remove source',
    () async {
      await seedTransferGuest(guest);
      current = false;
      await expectLater(transfer.transferGuest(), throwsStateError);
      expect(guest.keys(guest.owner, 'drives'), ['guest-drive']);
      expect(target.keys(target.owner, 'drives'), isEmpty);
    },
  );

  test('changed source after interruption is never removed', () async {
    await seedTransferGuest(guest);
    failGroup = 'drives';
    await expectLater(transfer.transferGuest(), throwsStateError);
    final raw = driveTransferManifest(data.fixture('guest-drive').drive)
      ..['distance'] = 3000.0;
    await guest.put(
      guest.owner,
      'drives',
      'guest-drive',
      driveFromTransferManifest(raw),
    );
    await expectLater(transfer.transferGuest(), throwsStateError);
    expect(guest.keys(guest.owner, 'drives'), ['guest-drive']);
  });

  test(
    'sub-5km legacy route imports locally without fake telemetry score or World',
    () async {
      final raw = driveTransferManifest(data.fixture('old').drive)
        ..['distance'] = 1200.0;
      final old = driveFromTransferManifest(raw);
      final source = MemoryLegacyTransferSource([
        LegacyTransferRow('old', old, 'legacy-fingerprint'),
      ]);
      final result = await transfer.transferLegacy(source);
      expect(result.transferred, 1);
      expect(result.localOnly, 1);
      expect(source.rows, isEmpty);
      final id = target.keys(target.owner, 'drives').single;
      expect(
        target.read<DriveSession>(target.owner, 'drives', id)!.distance,
        1200,
      );
      expect(target.keys(target.owner, 'drive_telemetry'), isEmpty);
      expect(target.keys(target.owner, 'drive_scores'), isEmpty);
      expect(target.keys(target.owner, 'career_contributions_v1'), isEmpty);
      expect(target.keys(target.owner, 'owner_sync_outbox_v1'), isEmpty);
      expect(await target.worldSources(target.owner).getPendingJobs(), isEmpty);
      expect((await transfer.transferLegacy(source)).transferred, 0);
      await target.repositories(target.owner).deleteHistory(id as String);
      expect(target.keys(target.owner, 'drives'), isEmpty);
    },
  );

  test(
    'legacy removal interruption keeps verified destination and retries once',
    () async {
      final source = MemoryLegacyTransferSource([
        LegacyTransferRow(
          'old',
          data.fixture('old').drive,
          'legacy-fingerprint',
        ),
      ])..failRemoveOnce = true;
      await expectLater(transfer.transferLegacy(source), throwsStateError);
      expect(source.rows, hasLength(1));
      expect(target.keys(target.owner, 'drives'), hasLength(1));
      expect((await transfer.transferLegacy(source)).transferred, 1);
      expect(target.keys(target.owner, 'drives'), hasLength(1));
    },
  );

  test(
    'incompatible cleanup needs explicit consent and removes only selected invalid row',
    () async {
      final invalid = driveFromTransferManifest(
        driveTransferManifest(data.fixture('bad').drive)
          ..['route'] = <dynamic>[],
      );
      final valid = LegacyTransferRow(
        'old',
        data.fixture('old').drive,
        'valid',
      );
      final bad = LegacyTransferRow('bad', invalid, 'invalid');
      final source = MemoryLegacyTransferSource([valid, bad]);
      expect((await transfer.transferLegacy(source)).rejected, 1);
      await expectLater(
        transfer.cleanIncompatible(source, [bad], confirmed: false),
        throwsStateError,
      );
      expect(source.rows, [bad]);
      expect(
        await transfer.cleanIncompatible(source, [bad], confirmed: true),
        1,
      );
      expect(target.keys(target.owner, 'drives'), hasLength(1));
      final source2 = MemoryLegacyTransferSource([valid]);
      await expectLater(
        transfer.cleanIncompatible(source2, [valid], confirmed: true),
        throwsStateError,
      );
      expect(source2.rows, [valid]);
    },
  );

  test(
    'real legacy Hive imports only compatible rows; auth revocation blocks source writes',
    () async {
      final documents = Directory('${root.path}/old-documents')..createSync();
      final hive = HiveImpl()..init(documents.path);
      OwnerScopedLocalStore.register(hive);
      final box = await hive.openBox<DriveSession>('drives');
      final old = data.fixture('old').drive;
      old.route[0] = RoutePoint(
        latitude: old.route.first.latitude,
        longitude: old.route.first.longitude,
        legacyHiveFields: {
          2: DateTime.utc(2020, 1, 2),
          9: 'opaque-route-field',
        },
      );
      await box.put('old', old);
      final bad = driveFromTransferManifest(
        driveTransferManifest(data.fixture('bad').drive)
          ..['route'] = <dynamic>[],
      );
      await box.put('bad', bad);
      await hive.close();
      var authorized = true;
      final source = await LegacyHiveDriveTransferSource.open(
        documentsDirectory: documents,
        requireAccess: () {
          if (!authorized) throw StateError('revoked');
        },
      );
      try {
        final result = await transfer.transferLegacy(source);
        expect(result.transferred, 1);
        expect(result.rejected, 1);
        final imported = target.read<DriveSession>(
          target.owner,
          'drives',
          target.keys(target.owner, 'drives').single,
        )!;
        expect(imported.route.first.legacyHiveFields, {
          2: DateTime.utc(2020, 1, 2),
          9: 'opaque-route-field',
        });
        final rows = await source.read();
        expect(rows.single.key, 'bad');
        authorized = false;
        await expectLater(source.remove(rows.single), throwsStateError);
        authorized = true;
        expect(
          await transfer.cleanIncompatible(source, rows, confirmed: true),
          1,
        );
      } finally {
        await source.close();
      }
      expect(
        await LegacyHiveDriveTransferSource.hasRecords(
          documentsDirectory: documents,
        ),
        isFalse,
      );
      expect(target.keys(target.owner, 'drives'), hasLength(1));
    },
  );

  test(
    'same-process retry reflushed outbox before Guest source removal',
    () async {
      await seedTransferGuest(guest);
      failGroup = 'owner_sync_outbox_v1';
      await expectLater(transfer.transferGuest(), throwsStateError);
      expect(guest.keys(guest.owner, 'drives'), hasLength(1));
      expect((await transfer.transferGuest()).transferred, 1);
      final key = OwnerDriveSyncClient(
        store: target,
        requireCurrent: () {},
      ).automaticPendingKeys().single;
      expect(target.writeDurable(OwnerDriveSyncClient.boxName, key), isTrue);
      final id = target.keys(target.owner, 'drives').single;
      expect(
        target.read<String>(target.owner, 'drive_names', id),
        'Sentetik kayıt adı',
      );
    },
  );

  test(
    'Guest without GPS stays a local account record, no telemetry or Career invented',
    () async {
      final manifest = driveTransferManifest(data.fixture('stationary').drive)
        ..['route'] = <dynamic>[];
      await guest.put(
        guest.owner,
        'drives',
        'stationary',
        driveFromTransferManifest(manifest),
      );
      expect((await transfer.transferGuest()).localOnly, 1);
      expect(guest.keys(guest.owner, 'drives'), isEmpty);
      final id = target.keys(target.owner, 'drives').single;
      expect(
        target.read<DriveSession>(target.owner, 'drives', id)!.route,
        isEmpty,
      );
      expect(target.keys(target.owner, 'drive_telemetry'), isEmpty);
      expect(target.keys(target.owner, 'owner_sync_outbox_v1'), isEmpty);
      expect(target.keys(target.owner, 'career_contributions_v1'), isEmpty);
    },
  );

  test(
    'owner revoked during target write retains Guest and resumes with same identity',
    () async {
      await seedTransferGuest(guest);
      await target.close();
      var revoke = true;
      target = await OwnerScopedLocalStore.open(
        root: root.path,
        owner: GpsOwner.account(transferA),
        beforeFlush: (group) async {
          if (revoke && group == 'drives') current = false;
        },
      );
      transfer = AccountDriveTransfer(
        target: target,
        guest: guest,
        requireCurrent: () {
          if (!current) throw StateError('revoked');
        },
      );
      await expectLater(transfer.transferGuest(), throwsStateError);
      expect(guest.keys(guest.owner, 'drives'), hasLength(1));
      revoke = false;
      current = true;
      expect((await transfer.transferGuest()).transferred, 1);
      expect(target.keys(target.owner, 'drives'), hasLength(1));
    },
  );

  test(
    'valid short Guest drive keeps History and Career without a World job',
    () async {
      await seedTransferGuest(guest);
      final raw = driveTransferManifest(
        guest.read<DriveSession>(guest.owner, 'drives', 'guest-drive')!,
      )..['distance'] = 1200.0;
      await guest.put(
        guest.owner,
        'drives',
        'guest-drive',
        driveFromTransferManifest(raw),
      );
      expect((await transfer.transferGuest()).transferred, 1);
      expect(target.keys(target.owner, 'drives'), hasLength(1));
      expect(
        target
            .keys(target.owner, 'career_contributions_v1')
            .where((k) => k.toString().startsWith('source:')),
        hasLength(1),
      );
      expect(await target.worldSources(target.owner).getPendingJobs(), isEmpty);
    },
  );

  test(
    'M2 destination tombstone prevents an interrupted transfer from resurrecting History',
    () async {
      await seedTransferGuest(guest);
      failGroup = 'owner_sync_outbox_v1';
      await expectLater(transfer.transferGuest(), throwsStateError);
      final id = target.keys(target.owner, 'drives').single;
      await target.put(target.owner, 'local_lifecycle_v1', 'history:$id', {
        'state': 'completed',
      });
      await target.remove(target.owner, 'drives', id);
      await expectLater(transfer.transferGuest(), throwsStateError);
      expect(target.keys(target.owner, 'drives'), isEmpty);
      expect(guest.keys(guest.owner, 'drives'), ['guest-drive']);
    },
  );

  test(
    'crash after Guest removal resumes the durable receipt without losing destination',
    () async {
      await seedTransferGuest(guest);
      await guest.close();
      var failOnce = true;
      guest = await OwnerScopedLocalStore.open(
        root: root.path,
        owner: const GpsOwner.guest(),
        beforeFlush: (group) async {
          if (failOnce && group == 'drives') {
            failOnce = false;
            throw StateError('synthetic source removal crash');
          }
        },
      );
      transfer = AccountDriveTransfer(
        target: target,
        guest: guest,
        requireCurrent: () {},
      );
      await expectLater(transfer.transferGuest(), throwsStateError);
      await guest.close();
      await target.close();
      await open();
      expect(target.keys(target.owner, 'drives'), hasLength(1));
      expect((await transfer.transferGuest()).transferred, 1);
      expect(transfer.guestIds(), isEmpty);
      expect(target.keys(target.owner, 'drives'), hasLength(1));
    },
  );
}
