import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';

const accountA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const accountB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const sourceId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

class _FakeRemote implements OwnerSyncRemoteAdapter {
  bool failNext = false;
  bool conflictNext = false;
  int calls = 0;
  final Map<String, OwnerSyncMutation> records = {};

  @override
  Future<OwnerSyncReceipt> apply(OwnerSyncMutation mutation) async {
    calls++;
    if (failNext) {
      failNext = false;
      throw const OwnerSyncTransportFailure('offline');
    }
    if (conflictNext) {
      conflictNext = false;
      throw const OwnerSyncConflict('remote_payload_conflict');
    }
    final previous = records[mutation.idempotencyKey];
    if (previous != null &&
        previous.payloadFingerprint != mutation.payloadFingerprint) {
      throw const OwnerSyncConflict('remote_idempotency_payload_conflict');
    }
    records.putIfAbsent(mutation.idempotencyKey, () => mutation);
    return OwnerSyncReceipt(
      ownerScope: mutation.ownerScope,
      idempotencyKey: mutation.idempotencyKey,
      payloadFingerprint: mutation.payloadFingerprint,
      remoteId: 'remote:${mutation.idempotencyKey}',
    );
  }
}

Future<void> _seedVerifiedDrive(OwnerScopedLocalStore store) async {
  final owner = store.owner;
  final now = DateTime.utc(2026, 10, 12, 9);
  final provenance = DriveSourceProvenance.proven(
    sourceIdentity: sourceId,
    ownerScope: store.scope,
  );
  final drive = DriveSession(
    id: 'local-drive-1',
    date: now,
    distance: 6200,
    durationSeconds: 900,
    averageSpeed: 24.8,
    maxSpeed: 42,
    mapImagePath: '',
    route: [
      RoutePoint(latitude: 40, longitude: 29),
      RoutePoint(latitude: 40.01, longitude: 29.01),
    ],
  );
  final telemetry = DriveTelemetryRecord(
    driveSessionId: drive.id,
    dataVersion: DriveTelemetryRecord.currentDataVersion,
    createdAt: now,
    acquisitionMetadata: {
      'provenanceStatus': 'proven',
      'sourceIdentity': sourceId,
      'sourceIdentityVersion': 1,
      'sourceNamespace': 'drive_source_v1',
    },
    points: [
      CanonicalTelemetryPoint(
        latitude: 40,
        longitude: 29,
        timestamp: now,
        speedMps: 7,
        headingDegrees: 90,
        altitudeMeters: 10,
        accuracyMeters: 4,
        distanceFromPreviousMeters: 0,
        accelerationMps2: 0,
      ),
      CanonicalTelemetryPoint(
        latitude: 40.01,
        longitude: 29.01,
        timestamp: now.add(const Duration(seconds: 10)),
        speedMps: 8,
        headingDegrees: 90,
        altitudeMeters: 11,
        accuracyMeters: 4,
        distanceFromPreviousMeters: 100,
        accelerationMps2: 0,
      ),
    ],
  );
  final bundle = LocalSourceBundle(
    drive: drive,
    telemetry: telemetry,
    ownerScope: store.scope,
    sourceProvenance: provenance,
  );
  bundle.validate();
  await store.put(owner, 'drives', drive.id, drive);
  await store.put(owner, 'drive_telemetry', drive.id, telemetry);
  await store.put(
    owner,
    'drive_source_provenance_v1',
    drive.id,
    provenance.toMap(),
  );
  await store.repositories(owner).prepareSource(bundle);
  await store.put(owner, 'owned_drive_finalization_v1', drive.id, {
    'state': 'completed',
    'derivedReady': true,
  });
}

void main() {
  late Directory root;
  late OwnerScopedLocalStore storeA;
  late OwnerScopedLocalStore storeB;
  final ownerA = GpsOwner.account(accountA);
  final ownerB = GpsOwner.account(accountB);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_owner_sync_');
    storeA = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
    storeB = await OwnerScopedLocalStore.open(root: root.path, owner: ownerB);
  });

  tearDown(() async {
    await storeA.close();
    await storeB.close();
    await root.delete(recursive: true);
  });

  test(
    'A drive queues offline, retries idempotently, and never leaks to B',
    () async {
      await _seedVerifiedDrive(storeA);
      final clientA = OwnerDriveSyncClient(
        store: storeA,
        requireCurrent: () {},
      );
      final key = await clientA.enqueueDrive('local-drive-1');
      expect(await clientA.enqueueDrive('local-drive-1'), key);
      expect(clientA.pendingKeys(), [key]);
      final queued = OwnerSyncMutation.fromMap(
        Map.from(clientA.readRecord(key)!['mutation'] as Map),
      );
      expect(queued.payload['roads'], isEmpty);

      final remote = _FakeRemote()..failNext = true;
      expect(await clientA.send(key, remote), isFalse);
      expect(remote.records, isEmpty);
      expect(clientA.readRecord(key)!['state'], 'retryableFailure');
      expect(clientA.readRecord(key)!['attemptCount'], 1);

      await storeA.close();
      storeA = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
      final reopened = OwnerDriveSyncClient(
        store: storeA,
        requireCurrent: () {},
      );
      expect(reopened.readRecord(key)!['state'], 'retryableFailure');
      expect(await reopened.send(key, remote), isTrue);
      expect(await reopened.send(key, remote), isTrue);
      expect(remote.records, hasLength(1));
      expect(remote.calls, 2);
      expect(reopened.pendingKeys(), isEmpty);

      final clientB = OwnerDriveSyncClient(
        store: storeB,
        requireCurrent: () {},
      );
      expect(clientB.pendingKeys(), isEmpty);
      expect(() => clientB.enqueueDrive('local-drive-1'), throwsStateError);
      expect(storeB.keys(ownerB, OwnerDriveSyncClient.boxName), isEmpty);
      expect(storeA.keys(ownerA, OwnerDriveSyncClient.boxName), [key]);
    },
  );

  test('guest, legacy, unproven and unfinished drives fail closed', () async {
    final guestStore = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: const GpsOwner.guest(),
    );
    addTearDown(guestStore.close);
    final guestClient = OwnerDriveSyncClient(
      store: guestStore,
      requireCurrent: () {},
    );
    expect(() => guestClient.pendingKeys(), throwsStateError);
    expect(() => guestClient.enqueueDrive('legacy-drive'), throwsStateError);
    expect(
      () => OwnerDriveSyncClient(
        store: storeA,
        requireCurrent: () {},
      ).enqueueDrive('missing'),
      throwsStateError,
    );
  });

  test(
    'existing tombstone without durable sync evidence is not guessed',
    () async {
      await storeA.put(ownerA, 'local_lifecycle_v1', 'history:old', {
        'version': 1,
        'state': 'completed',
      });
      final client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
      await expectLater(client.enqueueTombstone('old'), throwsStateError);
      expect(storeA.keys(ownerA, OwnerDriveSyncClient.boxName), isEmpty);
    },
  );

  test('remote content conflict is durable and not blindly retried', () async {
    await _seedVerifiedDrive(storeA);
    final client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
    final key = await client.enqueueDrive('local-drive-1');
    final remote = _FakeRemote()..conflictNext = true;
    expect(await client.send(key, remote), isFalse);
    expect(client.readRecord(key)!['state'], 'conflict');
    expect(client.pendingKeys(), isEmpty);
    expect(await client.send(key, remote), isFalse);
    expect(remote.calls, 1);
  });

  test('queued upsert is never sent after a local History tombstone', () async {
    await _seedVerifiedDrive(storeA);
    final client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
    final key = await client.enqueueDrive('local-drive-1');
    await storeA.put(ownerA, 'local_lifecycle_v1', 'history:local-drive-1', {
      'version': 1,
      'state': 'completed',
    });
    final remote = _FakeRemote();

    expect(await client.send(key, remote), isFalse);
    expect(remote.calls, 0);
    expect(remote.records, isEmpty);
    expect(client.readRecord(key)!['state'], 'conflict');
    expect(client.readRecord(key)!['lastErrorCode'], 'drive_deleted_before_sync');
  });
}
