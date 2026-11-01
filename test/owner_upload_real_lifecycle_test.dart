import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/supabase_owner_drive_sync_adapter.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const intent = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const url = 'https://arwnbogcswisfesayosy.supabase.co';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production upload pins credentials across SDK/real lease changes and retries',
    () async {
      final root = await Directory.systemTemp.createTemp('driveit_upload_sdk_');
      var uid = a;
      var token = 'synthetic-a';
      var fail = false;
      var hold = false;
      final entered = Completer<void>();
      final release = Completer<void>();
      final sent = <String?>[];
      final sdk = SupabaseClient(
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
      final runtime = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      const hash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const key = 'owner-sync-v2:$hash';
      final scope = jsonEncode(['local_account_store_v1', 'account', a]);
      final transport = MockClient((r) async {
        sent.add(r.headers['authorization']);
        if (hold) {
          entered.complete();
          await release.future;
        }
        if (fail) return http.Response('{"error_code":"unavailable"}', 503);
        final body = r.url.path.contains('/storage/')
            ? {'Key': 'synthetic'}
            : r.url.path.endsWith('phase8-drive-finalize')
            ? {
                'ok': true,
                'receipt': {
                  'ownerScope': scope,
                  'idempotencyKey': key,
                  'payloadFingerprint': hash,
                  'remoteId': 'one',
                },
              }
            : {'ok': true, 'intentId': intent, 'state': 'staging'};
        return http.Response(
          jsonEncode(body),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      });
      try {
        await sdk.auth.signInWithPassword(
          email: 'a@example.invalid',
          password: 'synthetic',
        );
        await runtime.start();
        final lease = runtime.lease;
        await lease.put('drive_names', 'retained', 'local');
        final gateway = OwnerProfileGateway(
          authClient: sdk,
          url: url,
          publicKey: 'sb_publishable_synthetic',
          applicationId: 'com.osaracx.driveit',
          approvedOwner: () => lease.owner.userId,
          approvedEpoch: () => lease.epoch,
          isLeaseCurrent: (e) => e == lease.epoch && lease.isCurrent,
          transport: transport,
        );
        final adapter = SupabaseOwnerDriveSyncAdapter(
          client: sdk,
          ownerId: a,
          requireCurrent: lease.requireCurrent,
          uploadGateway: gateway,
        );
        final wrong = OwnerProfileGateway(
          authClient: sdk,
          url: 'https://viqngnjfgknpxtoapzcg.supabase.co',
          publicKey: 'sb_publishable_synthetic',
          applicationId: 'com.osaracx.driveit',
          approvedOwner: () => lease.owner.userId,
          approvedEpoch: () => lease.epoch,
          isLeaseCurrent: (e) => lease.isCurrent && e == lease.epoch,
          transport: transport,
        );
        await expectLater(
          wrong.run((data, id) => data.functions.invoke('phase8-drive-begin')),
          throwsA(isA<StateError>()),
        );
        expect(sent, isEmpty);
        await expectLater(
          adapter.download(ownerId: a, afterCursor: '', limit: 1),
          throwsA(isA<OwnerSyncConflict>()),
        );
        final descriptor = OwnerSyncUploadDescriptor(
          contractVersion: 2,
          ownerId: a,
          ownerScope: scope,
          sourceIdentity: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          idempotencyKey: key,
          payloadFingerprint: hash,
          objectSha256: hash,
          objectBytes: 3,
        );
        fail = true;
        await expectLater(
          adapter.beginUpload(descriptor),
          throwsA(isA<OwnerSyncTransportFailure>()),
        );
        expect(lease.read('drive_names', 'retained'), 'local');
        fail = false;
        await adapter.beginUpload(descriptor);
        await adapter.uploadPrivateObject(
          intentId: intent,
          envelopeBytes: [1, 2, 3],
        );
        expect((await adapter.finalizeUpload(intent)).remoteId, 'one');
        expect((await adapter.finalizeUpload(intent)).remoteId, 'one');
        token = 'synthetic-a-refresh';
        await sdk.auth.refreshSession();
        await adapter.beginUpload(descriptor);
        expect(sent.last, 'Bearer synthetic-a-refresh');
        hold = true;
        final late = adapter.finalizeUpload(intent);
        await entered.future;
        uid = b;
        token = 'synthetic-b';
        await sdk.auth.signInWithPassword(
          email: 'b@example.invalid',
          password: 'synthetic',
        );
        await Future<void>.delayed(Duration.zero);
        await runtime.settled;
        expect(lease.isCurrent, false);
        final rejected = expectLater(late, throwsA(isA<StateError>()));
        release.complete();
        await rejected;
        await expectLater(
          adapter.beginUpload(descriptor),
          throwsA(isA<StateError>()),
        );
        expect(sent, isNot(contains('Bearer synthetic-b')));
        await sdk.auth.signOut();
        await Future<void>.delayed(Duration.zero);
        await runtime.settled;
        expect(runtime.lease.owner.userId, isNull);
        await expectLater(
          adapter.uploadPrivateObject(intentId: intent, envelopeBytes: [1]),
          throwsA(isA<StateError>()),
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await runtime.close();
        runtime.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
