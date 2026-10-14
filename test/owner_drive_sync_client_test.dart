import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/owner_sync_canonical_json.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/supabase_owner_drive_sync_adapter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _FakeStagedRemote implements OwnerSyncStagedUploadAdapter {
  bool failUploadOnce = false;
  bool loseUploadResponseOnce = false;
  bool loseFinalizeResponseOnce = false;
  int finalizeCalls = 0;
  final Map<String, OwnerSyncUploadDescriptor> descriptors = {};
  final Map<String, List<int>> privateObjects = {};
  final Map<String, OwnerSyncReceipt> receipts = {};
  final Map<String, OwnerSyncMutation> manifests = {};

  @override
  Future<OwnerSyncStagingIntent> beginUpload(
    OwnerSyncUploadDescriptor descriptor,
  ) async {
    final receipt = receipts[descriptor.idempotencyKey];
    if (receipt != null) {
      _checkDescriptor(descriptors[descriptor.idempotencyKey]!, descriptor);
      return OwnerSyncStagingIntent(
        id: descriptor.idempotencyKey,
        state: OwnerSyncStagingState.finalized,
        receipt: receipt,
      );
    }
    final prior = descriptors[descriptor.idempotencyKey];
    if (prior != null) _checkDescriptor(prior, descriptor);
    descriptors.putIfAbsent(descriptor.idempotencyKey, () => descriptor);
    return OwnerSyncStagingIntent(
      id: descriptor.idempotencyKey,
      state: OwnerSyncStagingState.staging,
    );
  }

  @override
  Future<void> uploadPrivateObject({
    required String intentId,
    required List<int> envelopeBytes,
  }) async {
    final descriptor = descriptors[intentId];
    if (descriptor == null) throw const OwnerSyncConflict('intent_missing');
    if (failUploadOnce) {
      failUploadOnce = false;
      throw const OwnerSyncTransportFailure('storage_offline');
    }
    if (envelopeBytes.length != descriptor.objectBytes ||
        sha256.convert(envelopeBytes).toString() != descriptor.objectSha256) {
      throw const OwnerSyncConflict('staging_object_integrity_mismatch');
    }
    final existing = privateObjects[intentId];
    if (existing != null) {
      throw const OwnerSyncStagedObjectAlreadyExists();
    }
    privateObjects[intentId] = List<int>.unmodifiable(envelopeBytes);
    if (loseUploadResponseOnce) {
      loseUploadResponseOnce = false;
      throw const OwnerSyncTransportFailure('storage_response_lost');
    }
  }

  @override
  Future<OwnerSyncReceipt> finalizeUpload(String intentId) async {
    finalizeCalls++;
    final descriptor = descriptors[intentId];
    final bytes = privateObjects[intentId];
    if (descriptor == null || bytes == null) {
      throw const OwnerSyncConflict('staging_object_missing');
    }
    if (bytes.length != descriptor.objectBytes ||
        sha256.convert(bytes).toString() != descriptor.objectSha256) {
      throw const OwnerSyncConflict('staging_object_integrity_mismatch');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const OwnerSyncConflict('envelope_invalid');
    final mutation = OwnerSyncMutation.fromMap(Map.from(decoded));
    if (mutation.ownerId != descriptor.ownerId ||
        mutation.ownerScope != descriptor.ownerScope ||
        mutation.sourceIdentity != descriptor.sourceIdentity ||
        mutation.idempotencyKey != descriptor.idempotencyKey ||
        mutation.payloadFingerprint != descriptor.payloadFingerprint ||
        canonicalOwnerSyncSha256(mutation.payload) !=
            descriptor.payloadFingerprint) {
      throw const OwnerSyncConflict('finalization_claim_mismatch');
    }
    final previous = manifests[intentId];
    if (previous != null &&
        previous.payloadFingerprint != mutation.payloadFingerprint) {
      throw const OwnerSyncConflict('finalization_idempotency_conflict');
    }
    manifests.putIfAbsent(intentId, () => mutation);
    final receipt = OwnerSyncReceipt(
      ownerScope: descriptor.ownerScope,
      idempotencyKey: descriptor.idempotencyKey,
      payloadFingerprint: descriptor.payloadFingerprint,
      remoteId: 'drive:${descriptor.sourceIdentity}',
    );
    receipts.putIfAbsent(intentId, () => receipt);
    if (loseFinalizeResponseOnce) {
      loseFinalizeResponseOnce = false;
      throw const OwnerSyncTransportFailure('finalize_response_lost');
    }
    return receipts[intentId]!;
  }

  void _checkDescriptor(
    OwnerSyncUploadDescriptor previous,
    OwnerSyncUploadDescriptor current,
  ) {
    if (previous.ownerId != current.ownerId ||
        previous.ownerScope != current.ownerScope ||
        previous.sourceIdentity != current.sourceIdentity ||
        previous.idempotencyKey != current.idempotencyKey ||
        previous.payloadFingerprint != current.payloadFingerprint ||
        previous.objectSha256 != current.objectSha256 ||
        previous.objectBytes != current.objectBytes) {
      throw const OwnerSyncConflict('staging_idempotency_conflict');
    }
  }
}

Future<void> _seedVerifiedDrive(
  OwnerScopedLocalStore store, {
  String identity = sourceId,
  bool includeScore = false,
}) async {
  final owner = store.owner;
  final now = DateTime.utc(2026, 10, 12, 9);
  final provenance = DriveSourceProvenance.proven(
    sourceIdentity: identity,
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
      'sourceIdentity': identity,
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
    score: includeScore
        ? DriveScoreRecord(
            driveId: drive.id,
            algorithmVersion: DriveScoreRecord.currentAlgorithmVersion,
            telemetryDataVersion: DriveTelemetryRecord.currentDataVersion,
            calculatedAt: now,
            totalScore: 84,
            overallConfidence: .9,
            categories: const [],
          )
        : null,
    ownerScope: store.scope,
    sourceProvenance: provenance,
  );
  bundle.validate();
  await store.put(owner, 'drives', drive.id, drive);
  await store.put(owner, 'drive_telemetry', drive.id, telemetry);
  if (bundle.score != null) {
    await store.put(
      owner,
      'drive_scores',
      DriveScoreStorageService.keyFor(drive.id, bundle.score!.algorithmVersion),
      bundle.score!,
    );
  }
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
    expect(
      client.readRecord(key)!['lastErrorCode'],
      'drive_deleted_before_sync',
    );
  });

  test('canonical sync JSON is independent of map insertion order', () {
    expect(
      canonicalOwnerSyncJson({
        'z': 1,
        'nested': {
          'b': true,
          'a': [2, 3],
        },
      }),
      canonicalOwnerSyncJson({
        'nested': {
          'a': [2, 3],
          'b': true,
        },
        'z': 1,
      }),
    );
    expect(
      canonicalOwnerSyncSha256({'a': 1, 'b': 2}),
      canonicalOwnerSyncSha256({'b': 2, 'a': 1}),
    );
    const sharedVector = {
      'z': 1,
      'nested': {
        'b': true,
        'a': [2, 3],
      },
      'float': [1.0, -0.0, 1e-6, 1e-7],
    };
    const sharedCanonical =
        '{"float":[1,0,0.000001,1e-7],"nested":{"a":[2,3],"b":true},"z":1}';
    expect(canonicalOwnerSyncJson(sharedVector), sharedCanonical);
    expect(
      canonicalOwnerSyncSha256(sharedVector),
      'bcc86a6ee01fa4497af3c8fc910d12bdfd6d88bfc70604c75398453d609c1633',
    );
    expect(
      canonicalOwnerSyncJson([1.0, -0.0, 1e-6, 1e-7]),
      '[1,0,0.000001,1e-7]',
    );
    expect(
      () => canonicalOwnerSyncJson({'not-finite': double.infinity}),
      throwsFormatException,
    );
    expect(
      () => canonicalOwnerSyncJson({'unsafe': 9007199254740992}),
      throwsFormatException,
    );
    expect(() => canonicalOwnerSyncJson(1e20), throwsFormatException);
    expect(() => canonicalOwnerSyncJson(1e21), throwsFormatException);
  });

  test('upgrade reuses a durable v1 outbox row for the same source', () async {
    await _seedVerifiedDrive(storeA);
    final source = storeA.repositories(ownerA).source('local-drive-1')!;
    final payload = source.toMap()..['roads'] = <dynamic>[];
    final oldFingerprint = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    final oldKey =
        'owner-sync-v1:${sha256.convert(utf8.encode('${storeA.scope}|$accountA|driveUpsert|$sourceId'))}';
    final v1 = OwnerSyncMutation(
      version: 1,
      kind: OwnerSyncMutationKind.driveUpsert,
      ownerScope: storeA.scope,
      ownerId: accountA,
      idempotencyKey: oldKey,
      payloadFingerprint: oldFingerprint,
      sourceIdentity: sourceId,
      payload: payload,
    );
    await storeA.put(ownerA, OwnerDriveSyncClient.boxName, oldKey, {
      'mutation': v1.toMap(),
      'state': 'retryableFailure',
      'attemptCount': 1,
    });

    final client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
    expect(await client.enqueueDrive('local-drive-1'), oldKey);
    expect(storeA.keys(ownerA, OwnerDriveSyncClient.boxName), [oldKey]);
    expect(
      OwnerSyncMutation.fromMap(
        Map.from(client.readRecord(oldKey)!['mutation'] as Map),
      ).version,
      1,
    );
  });

  test(
    'staged upload retries ambiguous Storage/DB boundary idempotently',
    () async {
      await _seedVerifiedDrive(storeA);
      var client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
      final key = await client.enqueueDrive('local-drive-1');
      final mutation = OwnerSyncMutation.fromMap(
        Map.from(client.readRecord(key)!['mutation'] as Map),
      );
      expect(mutation.version, 2);
      final remote = _FakeStagedRemote()
        ..failUploadOnce = true
        ..loseFinalizeResponseOnce = true;

      // The object remains private and no manifest/change is visible on an
      // upload failure.
      expect(await client.sendStaged(key, remote), isFalse);
      expect(client.readRecord(key)!['state'], 'retryableFailure');
      expect(remote.privateObjects, isEmpty);
      expect(remote.manifests, isEmpty);

      // Storage succeeds, DB finalization commits, but its response is lost.
      // Re-entry discovers the durable final receipt by the same key.
      expect(await client.sendStaged(key, remote), isFalse);
      expect(remote.privateObjects, hasLength(1));
      expect(remote.manifests, hasLength(1));
      expect(remote.receipts, hasLength(1));
      expect(client.readRecord(key)!['state'], 'retryableFailure');

      await storeA.close();
      storeA = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
      client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
      expect((client.readRecord(key)!['stagedUpload'] as Map)['intentId'], key);
      expect(await client.sendStaged(key, remote), isTrue);
      expect(await client.sendStaged(key, remote), isTrue);
      expect(remote.finalizeCalls, 1);
      expect(remote.manifests, hasLength(1));
      expect(remote.receipts, hasLength(1));
      expect(client.readRecord(key)!['state'], 'acknowledged');
      expect(
        ((client.readRecord(key)!['stagedUpload'] as Map)['objectSha256']),
        sha256.convert(canonicalOwnerSyncBytes(mutation.toMap())).toString(),
      );
    },
  );

  test(
    'retries after Storage accepted object but upload ACK was lost',
    () async {
      await _seedVerifiedDrive(storeA);
      final client = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
      final key = await client.enqueueDrive('local-drive-1');
      final remote = _FakeStagedRemote()..loseUploadResponseOnce = true;

      // The first response is ambiguous: Storage retained the immutable object,
      // but the client has only a retryable local state.
      expect(await client.sendStaged(key, remote), isFalse);
      expect(remote.privateObjects, hasLength(1));
      expect(remote.manifests, isEmpty);
      expect(client.readRecord(key)!['state'], 'retryableFailure');

      // A retry receives Storage's duplicate response, never overwrites bytes,
      // and relies on the server finalizer to verify the existing object.
      expect(await client.sendStaged(key, remote), isTrue);
      expect(remote.privateObjects, hasLength(1));
      expect(remote.manifests, hasLength(1));
      expect(remote.receipts, hasLength(1));
      expect(client.readRecord(key)!['state'], 'acknowledged');
    },
  );

  test(
    'staged Supabase adapter uploads and same-owner replica downloads',
    () async {
      await _seedVerifiedDrive(storeA, includeScore: true);
      final sender = OwnerDriveSyncClient(store: storeA, requireCurrent: () {});
      final outboxKey = await sender.enqueueDrive('local-drive-1');
      final mutation = OwnerSyncMutation.fromMap(
        Map.from(sender.readRecord(outboxKey)!['mutation'] as Map),
      );
      Map<String, dynamic>? claims;
      final fakeRemote = MockClient((request) async {
        if (request.url.path == '/functions/v1/phase8-drive-begin') {
          claims = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'ok': true, 'intentId': sourceId, 'state': 'staging'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path.startsWith('/storage/v1/object/')) {
          expect(request.headers['x-upsert'], 'false');
          return http.Response(
            jsonEncode({
              'Key': 'phase8-drive-staging/$accountA/$sourceId/envelope.json',
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/functions/v1/phase8-drive-finalize') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'receipt': {
                'ownerScope': _scope(accountA),
                'idempotencyKey': claims!['idempotencyKey'],
                'payloadFingerprint': claims!['payloadFingerprint'],
                'remoteId': 'drive:$sourceId',
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/functions/v1/phase8-drive-download') {
          final downloadRequest =
              jsonDecode(request.body) as Map<String, dynamic>;
          final from = downloadRequest['action'] == 'begin' ? 0 : 1;
          const next = 1;
          return http.Response(
            jsonEncode({
              'ok': true,
              'snapshotId': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
              'from': from,
              'next': next,
              'highWater': 1,
              'nextCursor': base64Url
                  .encode(
                    utf8.encode('dddddddd-dddd-4ddd-8ddd-dddddddddddd:$next'),
                  )
                  .replaceAll('=', ''),
              'hasMore': false,
              'changes': from == 0
                  ? [
                      {'sequence': 1, 'mutation': mutation.toMap()},
                    ]
                  : <Object>[],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        fail('Unexpected fake endpoint ${request.url.path}');
      });
      final supabase = SupabaseClient(
        'https://phase8-client-test.invalid',
        'synthetic-test-key',
        httpClient: fakeRemote,
      );
      addTearDown(supabase.dispose);
      final adapter = SupabaseOwnerDriveSyncAdapter(
        client: supabase,
        ownerId: accountA,
        authenticatedUserId: () => accountA,
        requireCurrent: () {},
      );
      expect(await sender.sendStaged(outboxKey, adapter), isTrue);
      expect(sender.readRecord(outboxKey)!['state'], 'acknowledged');
      expect(claims!['ownerId'], accountA);
      expect(claims!['sourceIdentity'], sourceId);

      final replicaRoot = await Directory.systemTemp.createTemp(
        'driveit_owner_sync_replica_',
      );
      final replica = await OwnerScopedLocalStore.open(
        root: replicaRoot.path,
        owner: ownerA,
      );
      try {
        final receiver = OwnerDriveSyncClient(
          store: replica,
          requireCurrent: () {},
        );
        final result = await receiver.downloadOnce(adapter);
        expect(result.applied, 1);
        final mappedDriveId = 'local-drive-1';
        expect(replica.keys(ownerA, 'drives'), [mappedDriveId]);
        expect(
          replica.read<Map>(
            ownerA,
            OwnerDriveSyncClient.driveIdMapBox,
            sourceId,
          ),
          containsPair('remoteDriveId', 'local-drive-1'),
        );
        expect(
          replica
              .read<DriveTelemetryRecord>(
                ownerA,
                'drive_telemetry',
                mappedDriveId,
              )!
              .points,
          hasLength(2),
        );
        expect(
          replica
              .read<DriveTelemetryRecord>(
                ownerA,
                'drive_telemetry',
                mappedDriveId,
              )!
              .driveSessionId,
          mappedDriveId,
        );
        expect(
          replica
              .read<DriveScoreRecord>(
                ownerA,
                'drive_scores',
                DriveScoreStorageService.keyFor(mappedDriveId, 1),
              )!
              .driveId,
          mappedDriveId,
        );
        final replicaOutboxKey = await receiver.enqueueDrive(mappedDriveId);
        expect(replicaOutboxKey, outboxKey);
        expect(
          receiver.readRecord(
            replicaOutboxKey,
          )!['mutation']['payloadFingerprint'],
          sender.readRecord(outboxKey)!['mutation']['payloadFingerprint'],
        );
        final replay = await receiver.downloadOnce(adapter);
        expect(replay.applied, 0);
        expect(replay.duplicates, 0);
        expect(replica.keys(ownerA, 'drives'), [mappedDriveId]);
        await replica.remove(ownerA, 'drives', mappedDriveId);
        await replica.remove(ownerA, 'drive_telemetry', mappedDriveId);
        await replica.remove(
          ownerA,
          'drive_source_provenance_v1',
          mappedDriveId,
        );
        await replica.remove(
          ownerA,
          'owned_drive_finalization_v1',
          mappedDriveId,
        );
        await replica.remove(
          ownerA,
          'drive_scores',
          DriveScoreStorageService.keyFor(mappedDriveId, 1),
        );
        await replica.put(
          ownerA,
          'local_lifecycle_v1',
          'history:$mappedDriveId',
          {'version': 1, 'state': 'completed'},
        );
        await replica.remove(
          ownerA,
          OwnerDriveSyncClient.downloadStateBox,
          'drive_cursor_v1',
        );
        final afterLocalDelete = await receiver.downloadOnce(adapter);
        expect(afterLocalDelete.applied, 0);
        expect(afterLocalDelete.duplicates, 1);
        expect(replica.keys(ownerA, 'drives'), isEmpty);
        expect(
          replica.read<Map>(
            ownerA,
            OwnerDriveSyncClient.receivedBox,
            outboxKey,
          )?['state'],
          'locally_suppressed',
        );

        final collisionRoot = await Directory.systemTemp.createTemp(
          'driveit_owner_sync_id_collision_',
        );
        final collisionStore = await OwnerScopedLocalStore.open(
          root: collisionRoot.path,
          owner: ownerA,
        );
        try {
          const otherSource = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
          await _seedVerifiedDrive(collisionStore, identity: otherSource);
          final collisionReceiver = OwnerDriveSyncClient(
            store: collisionStore,
            requireCurrent: () {},
          );
          final collisionResult = await collisionReceiver.downloadOnce(adapter);
          expect(collisionResult.applied, 1);
          final collisionMappedId = 'sync_$sourceId';
          expect(
            collisionStore.read<Map>(
              ownerA,
              'drive_source_provenance_v1',
              'local-drive-1',
            )!['sourceIdentity'],
            otherSource,
          );
          expect(collisionStore.keys(ownerA, 'drives').toSet(), {
            'local-drive-1',
            collisionMappedId,
          });
          expect(
            collisionStore.read<Map>(
              ownerA,
              OwnerDriveSyncClient.downloadStateBox,
              'drive_cursor_v1',
            ),
            isNotNull,
          );
        } finally {
          await collisionStore.close();
          await collisionRoot.delete(recursive: true);
        }

        var failedTelemetryFlush = false;
        final crashRoot = await Directory.systemTemp.createTemp(
          'driveit_owner_sync_import_crash_',
        );
        var crashStore = await OwnerScopedLocalStore.open(
          root: crashRoot.path,
          owner: ownerA,
          beforeFlush: (group) async {
            if (group == 'drive_telemetry' && !failedTelemetryFlush) {
              failedTelemetryFlush = true;
              throw StateError('synthetic import interruption');
            }
          },
        );
        try {
          final crashReceiver = OwnerDriveSyncClient(
            store: crashStore,
            requireCurrent: () {},
          );
          await expectLater(
            crashReceiver.downloadOnce(adapter),
            throwsA(isA<StateError>()),
          );
          expect(
            crashStore.read<Map>(
              ownerA,
              'owned_drive_finalization_v1',
              mappedDriveId,
            )?['state'],
            'sync_importing',
          );
          // Reopen the same owner namespace to exercise durable retry state,
          // not merely an in-memory second call after the injected failure.
          await crashStore.close();
          crashStore = await OwnerScopedLocalStore.open(
            root: crashRoot.path,
            owner: ownerA,
          );
          final restartedReceiver = OwnerDriveSyncClient(
            store: crashStore,
            requireCurrent: () {},
          );
          final retried = await restartedReceiver.downloadOnce(adapter);
          expect(retried.applied, 1);
          expect(
            crashStore.read<Map>(
              ownerA,
              'owned_drive_finalization_v1',
              mappedDriveId,
            )?['state'],
            'completed',
          );
        } finally {
          await crashStore.close();
          await crashRoot.delete(recursive: true);
        }

        final ownerBClient = OwnerDriveSyncClient(
          store: storeB,
          requireCurrent: () {},
        );
        var ownerBCalls = 0;
        final ownerBSupabase = SupabaseClient(
          'https://phase8-client-test.invalid',
          'synthetic-test-key',
          httpClient: MockClient((request) async {
            ownerBCalls++;
            return http.Response(
              jsonEncode({'ok': false, 'error_code': 'unauthorized'}),
              403,
              headers: const {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(ownerBSupabase.dispose);
        final ownerBAdapter = SupabaseOwnerDriveSyncAdapter(
          client: ownerBSupabase,
          ownerId: accountB,
          authenticatedUserId: () => accountB,
          requireCurrent: () {},
        );
        await expectLater(
          ownerBClient.downloadOnce(ownerBAdapter),
          throwsA(isA<OwnerSyncConflict>()),
        );
        expect(storeB.keys(ownerB, 'drives'), isEmpty);
        expect(ownerBCalls, 1);
      } finally {
        await replica.close();
        await replicaRoot.delete(recursive: true);
      }
    },
  );
}

String _scope(String ownerId) =>
    '["local_account_store_v1","account","$ownerId"]';
