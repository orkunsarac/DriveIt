import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/supabase_owner_drive_sync_adapter.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const sourceId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const snapshot = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const url = 'https://arwnbogcswisfesayosy.supabase.co';
String cursor(int n) =>
    base64Url.encode(utf8.encode('$snapshot:$n')).replaceAll('=', '');
Future<void> _seedVerifiedDrive(
  OwnerScopedLocalStore store, {
  String identity = sourceId,
  String driveId = 'local-drive-1',
  bool includeScore = false,
  bool emptyTelemetry = false,
}) async {
  final owner = store.owner;
  final now = DateTime.utc(2026, 10, 12, 9);
  final provenance = DriveSourceProvenance.proven(
    sourceIdentity: identity,
    ownerScope: store.scope,
  );
  final drive = DriveSession(
    id: driveId,
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
    points: emptyTelemetry
        ? []
        : [
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SupabaseClient sdk;
  late List<OwnerSyncMutation> mutations;
  late List<LocalOwnerLifecycle> runtimes;
  late Map<String, OwnerScopedLocalStore> stores;
  var uid = a;
  var token = 'synthetic-a';
  var offline = false;
  var corrupt = false;
  var hold = false;
  late Completer<void> entered;
  late Completer<void> release;
  late List<String?> credentials;
  late List<int> cursors;
  late http.Client transport;
  Map<String, dynamic>? uploadClaims;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_download_sdk_');
    runtimes = [];
    stores = {};
    uploadClaims = null;
    uid = a;
    token = 'synthetic-a';
    offline = false;
    corrupt = false;
    hold = false;
    entered = Completer<void>();
    release = Completer<void>();
    credentials = [];
    cursors = [];
    sdk = SupabaseClient(
      url,
      'sb_publishable_synthetic',
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'synthetic',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': uid,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await sdk.auth.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic',
    );
    final source = await OwnerScopedLocalStore.open(
      root: '${root.path}/source',
      owner: GpsOwner.account(a),
    );
    mutations = [];
    try {
      for (var i = 0; i < 2; i++) {
        await _seedVerifiedDrive(
          source,
          driveId: 'drive-$i',
          identity: i == 0 ? sourceId : 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          includeScore: true,
        );
        final sync = OwnerDriveSyncClient(store: source, requireCurrent: () {});
        final key = await sync.enqueueDrive('drive-$i');
        mutations.add(
          OwnerSyncMutation.fromMap(
            Map.from(sync.readRecord(key)!['mutation'] as Map),
          ),
        );
      }
    } finally {
      await source.close();
    }
    transport = MockClient((r) async {
      credentials.add(r.headers['authorization']);
      if (r.url.path.startsWith('/storage/')) {
        return http.Response(
          '{"Key":"synthetic"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      final body = jsonDecode(r.body) as Map;
      if (r.url.path.endsWith('phase8-drive-finalize')) {
        return http.Response(
          jsonEncode({
            'ok': true,
            'receipt': {
              'ownerScope': uploadClaims!['ownerScope'],
              'idempotencyKey': uploadClaims!['idempotencyKey'],
              'payloadFingerprint': uploadClaims!['payloadFingerprint'],
              'remoteId': 'synthetic-upload',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.url.path.endsWith('phase8-drive-begin') &&
          body['action'] != 'capabilities') {
        uploadClaims = Map<String, dynamic>.from(body);
        return http.Response(
          jsonEncode({'ok': true, 'intentId': snapshot, 'state': 'staging'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.url.path.endsWith('phase8-drive-begin')) {
        return http.Response(
          jsonEncode({
            'ok': true,
            'contractVersion': 2,
            'schemaRevision': '202610150001',
            'ownerScope': jsonEncode(['local_account_store_v1', 'account', a]),
            'driveUpload': true,
            'driveDownload': true,
            'deleteSync': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(r.url.path.endsWith('phase8-drive-download'), isTrue);
      final from = body['cursor'] == null
          ? 0
          : int.parse(
              utf8
                  .decode(
                    base64Url.decode(
                      base64Url.normalize(body['cursor'] as String),
                    ),
                  )
                  .split(':')
                  .last,
            );
      cursors.add(from);
      if (hold) {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      }
      if (offline) return http.Response('{"error_code":"offline"}', 503);
      final next = (from + 1).clamp(0, 2);
      return http.Response(
        jsonEncode({
          'ok': true,
          'snapshotId': snapshot,
          'from': from,
          'next': next,
          'highWater': 2,
          'nextCursor': cursor(next),
          'hasMore': next < 2,
          'changes': from < 2
              ? [
                  {
                    'sequence': next,
                    'mutation': corrupt
                        ? {'invalid': true}
                        : mutations[from].toMap(),
                  },
                ]
              : [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });
  tearDown(() async {
    if (!release.isCompleted) release.complete();
    for (final r in runtimes) {
      await r.close();
      r.dispose();
    }
    await sdk.dispose();
    await root.delete(recursive: true);
  });
  Future<LocalOwnerLifecycle> device(
    String name, {
    String project = url,
  }) async {
    final runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (o) async {
        final store = await OwnerScopedLocalStore.open(
          root: '${root.path}/$name',
          owner: o,
        );
        stores[name] = store;
        return store;
      },
      driveInProgress: () async => false,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
      accountSyncAdapter: (lease) => SupabaseOwnerDriveSyncAdapter(
        client: sdk,
        ownerId: lease.owner.userId!,
        requireCurrent: lease.requireCurrent,
        uploadGateway: OwnerProfileGateway(
          authClient: sdk,
          url: project,
          publicKey: 'sb_publishable_synthetic',
          applicationId: 'com.osaracx.driveit',
          approvedOwner: () => lease.owner.userId,
          approvedEpoch: () => lease.epoch,
          isLeaseCurrent: (e) => lease.isCurrent && e == lease.epoch,
          transport: transport,
        ),
      ),
    );
    runtimes.add(runtime);
    await runtime.start();
    return runtime;
  }

  test(
    'real SDK/lifecycle restores paged drives on two devices without duplicates',
    () async {
      final first = await device('one');
      final pages = await first.lease.downloadAutomaticCloudPages(pageSize: 1);
      expect(pages.length, 2);
      expect(cursors, [0, 1]);
      expect(first.lease.keys('drives').toSet(), {'drive-0', 'drive-1'});
      expect(
        first.lease
            .read<DriveTelemetryRecord>('drive_telemetry', 'drive-0')!
            .points
            .length,
        2,
      );
      await first.lease.downloadAutomaticCloudPages(pageSize: 1);
      expect(first.lease.keys('drives').length, 2);
      final second = await device('two');
      await second.lease.downloadAutomaticCloudPages(pageSize: 1);
      expect(second.lease.keys('drives').toSet(), {'drive-0', 'drive-1'});
      expect(credentials.every((c) => c == 'Bearer synthetic-a'), isTrue);
    },
  );
  for (final change in ['account', 'epoch', 'refresh', 'logout']) {
    test(
      'late page rejected after $change without changing the destination',
      () async {
        final r = await device('race');
        final lease = r.lease;
        hold = true;
        final pending = lease.downloadAutomaticCloudPages(pageSize: 1);
        await entered.future;
        if (change == 'epoch') {
          await r.retry();
        } else if (change == 'refresh') {
          token = 'synthetic-refresh';
          await sdk.auth.refreshSession();
        } else if (change == 'logout') {
          await sdk.auth.signOut();
        } else {
          uid = b;
          token = 'synthetic-b';
          await sdk.auth.signInWithPassword(
            email: 'b@example.invalid',
            password: 'synthetic',
          );
        }
        await Future<void>.delayed(Duration.zero);
        await r.settled;
        final rejected = expectLater(pending, throwsA(isA<StateError>()));
        release.complete();
        await rejected;
        expect(r.lease.keys('drives'), isEmpty);
        expect(credentials, isNot(contains('Bearer synthetic-b')));
      },
    );
  }
  test(
    'retry and reopened owner retain cursor and local drives after malformed/offline pages',
    () async {
      final r = await device('restart');
      await r.lease.downloadAutomaticCloudPages(pageSize: 1, maxPages: 1);
      offline = true;
      await expectLater(
        r.lease.downloadAutomaticCloudPages(pageSize: 1),
        throwsA(isA<OwnerSyncTransportFailure>()),
      );
      expect(r.lease.keys('drives'), ['drive-0']);
      offline = false;
      corrupt = true;
      await expectLater(
        r.lease.downloadAutomaticCloudPages(pageSize: 1),
        throwsA(anything),
      );
      expect(r.lease.keys('drives'), ['drive-0']);
      corrupt = false;
      await r.close();
      final reopened = await device('restart');
      await reopened.lease.downloadAutomaticCloudPages(pageSize: 1);
      expect(reopened.lease.keys('drives').toSet(), {'drive-0', 'drive-1'});
      expect(cursors, [0, 1, 1, 1]);
    },
  );
  test('upload completes while a real owner download page is pending', () async {
    final r = await device('parallel');
    final lease = r.lease;
    hold = true;
    final pending = lease.downloadAutomaticCloudPages(pageSize: 1);
    await entered.future;
    final adapter = SupabaseOwnerDriveSyncAdapter(
      client: sdk,
      ownerId: a,
      requireCurrent: lease.requireCurrent,
      uploadGateway: OwnerProfileGateway(
        authClient: sdk,
        url: url,
        publicKey: 'sb_publishable_synthetic',
        applicationId: 'com.osaracx.driveit',
        approvedOwner: () => lease.owner.userId,
        approvedEpoch: () => lease.epoch,
        isLeaseCurrent: (e) => e == lease.epoch && lease.isCurrent,
        transport: transport,
      ),
    );
    final m = mutations.first;
    final upload = await adapter.beginUpload(
      OwnerSyncUploadDescriptor(
        contractVersion: 2,
        ownerId: a,
        ownerScope: m.ownerScope,
        sourceIdentity: m.sourceIdentity,
        idempotencyKey: m.idempotencyKey,
        payloadFingerprint: m.payloadFingerprint,
        objectSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        objectBytes: 3,
      ),
    );
    await adapter.uploadPrivateObject(
      intentId: upload.id,
      envelopeBytes: [1, 2, 3],
    );
    expect(
      (await adapter.finalizeUpload(upload.id)).remoteId,
      'synthetic-upload',
    );
    hold = false;
    release.complete();
    await pending;
    expect(lease.keys('drives').length, 2);
    expect(credentials.every((c) => c == 'Bearer synthetic-a'), isTrue);
  });

  test('wrong project and UID reject download before local writes', () async {
    final wrong = await device(
      'wrong',
      project: 'https://viqngnjfgknpxtoapzcg.supabase.co',
    );
    await expectLater(
      wrong.lease.downloadAutomaticCloudPages(),
      throwsA(isA<StateError>()),
    );
    expect(credentials, isEmpty);
    expect(wrong.lease.keys('drives'), isEmpty);
  });

  test(
    'deleted local History is not resurrected by replayed SDK pages',
    () async {
      final r = await device('deleted');
      await r.lease.downloadAutomaticCloudPages(pageSize: 1);
      // A completed deletion fixture, matching the existing lifecycle contract.
      // Normal delete first refuses if independent source/Career is unprepared.
      await expectLater(r.lease.deleteHistory('drive-0'), throwsStateError);
      expect(r.lease.keys('drives'), contains('drive-0'));
      final store = stores['deleted']!;
      await store.remove(store.owner, 'drives', 'drive-0');
      await store.put(store.owner, 'local_lifecycle_v1', 'history:drive-0', {
        'version': 1,
        'state': 'completed',
      });
      expect(r.lease.keys('drives'), ['drive-1']);
      await r.lease.downloadAutomaticCloudPages(pageSize: 1);
      expect(r.lease.keys('drives'), ['drive-1']);
    },
  );

  test(
    'foreign mutation UID rejects whole page before History or cursor writes',
    () async {
      final r = await device('foreign');
      final original = mutations.first.toMap();
      mutations[0] = OwnerSyncMutation.fromMap({...original, 'ownerId': b});
      await expectLater(
        r.lease.downloadAutomaticCloudPages(pageSize: 1),
        throwsA(isA<OwnerSyncConflict>()),
      );
      expect(r.lease.keys('drives'), isEmpty);
      expect(r.lease.keys(OwnerDriveSyncClient.downloadStateBox), isEmpty);
    },
  );
}
