import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:driveit_project/services/owner_drive_sync_client.dart';
import 'package:driveit_project/services/supabase_owner_drive_sync_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _source = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _intent = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _snapshot = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const _key =
    'owner-sync-v2:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _fingerprint =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _objectHash =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

String _scope(String owner) => '["local_account_store_v1","account","$owner"]';

String _cursor(String snapshot, int sequence) =>
    base64Url.encode(utf8.encode('$snapshot:$sequence')).replaceAll('=', '');

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://phase8-test.invalid',
      'synthetic-anon-key',
      httpClient: MockClient(handler),
    );

OwnerDriveSyncAdapterHarness _adapter(
  SupabaseClient client, {
  String? Function()? auth,
}) {
  var current = true;
  final adapter = SupabaseOwnerDriveSyncAdapter(
    client: client,
    ownerId: _ownerA,
    requireCurrent: () {
      if (!current) throw StateError('stale owner lease');
    },
    authenticatedUserId: auth ?? () => _ownerA,
  );
  return OwnerDriveSyncAdapterHarness(adapter, () => current = false);
}

class OwnerDriveSyncAdapterHarness {
  OwnerDriveSyncAdapterHarness(this.adapter, this.invalidate);
  final SupabaseOwnerDriveSyncAdapter adapter;
  final void Function() invalidate;
}

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

OwnerSyncUploadDescriptor _descriptor() => OwnerSyncUploadDescriptor(
  contractVersion: 2,
  ownerId: _ownerA,
  ownerScope: _scope(_ownerA),
  sourceIdentity: _source,
  idempotencyKey: _key,
  payloadFingerprint: _fingerprint,
  objectSha256: _objectHash,
  objectBytes: 123,
);

Map<String, Object?> _receipt({String? ownerScope, String? key}) => {
  'ownerScope': ownerScope ?? _scope(_ownerA),
  'idempotencyKey': key ?? _key,
  'payloadFingerprint': _fingerprint,
  'remoteId': 'remote-drive-1',
};

void main() {
  test(
    'M2 real adapter remains fail-closed without explicit activation',
    () async {
      var requests = 0;
      final client = _client((_) async {
        requests++;
        return _json({});
      });
      try {
        final adapter = _adapter(client).adapter;
        await expectLater(
          adapter.observeDrive(_source),
          throwsA(isA<OwnerSyncConflict>()),
        );
        await expectLater(
          adapter.updateLease(
            sourceIdentity: _source,
            deviceId: _intent,
            sessionId: 'session',
          ),
          throwsA(isA<OwnerSyncConflict>()),
        );
        expect(requests, 0);
      } finally {
        await client.dispose();
      }
    },
  );

  test(
    'M2 observation negotiates capability and never trusts a foreign UID',
    () async {
      var calls = 0;
      final client = _client((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('phase8-drive-begin')) {
          expect(body['milestone'], 2);
          return _json({
            'ok': true,
            'schemaRevision': '202610160001',
            'ownerScope': _scope(_ownerA),
            'deleteSync': true,
            'leaseFencing': true,
          });
        }
        return _json({
          'ok': true,
          'ownerId': _ownerB,
          'source_identity': _source,
          'payload_fingerprint': _fingerprint,
          'change_sequence': 1,
        });
      });
      try {
        final adapter = SupabaseOwnerDriveSyncAdapter(
          client: client,
          ownerId: _ownerA,
          requireCurrent: () {},
          authenticatedUserId: () => _ownerA,
          deletionEnabled: true,
        );
        await expectLater(
          adapter.observeDrive(_source),
          throwsA(isA<OwnerSyncConflict>()),
        );
        expect(calls, 2);
      } finally {
        await client.dispose();
      }
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a lost function response becomes a bounded retryable transport failure',
    () async {
      final pending = Completer<http.Response>();
      final client = _client((_) => pending.future);
      addTearDown(client.dispose);
      final adapter = SupabaseOwnerDriveSyncAdapter(
        client: client,
        ownerId: _ownerA,
        authenticatedUserId: () => _ownerA,
        requireCurrent: () {},
        requestTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        adapter.verifyBackend(),
        throwsA(isA<OwnerSyncTransportFailure>()),
      );
      pending.complete(_json({'ok': false}));
    },
  );

  test(
    'backend readiness is owner-bound and requires the forward migration',
    () async {
      var revision = '202610150001';
      final client = _client(
        (_) async => _json({
          'ok': true,
          'contractVersion': 2,
          'schemaRevision': revision,
          'ownerScope': _scope(_ownerA),
          'driveUpload': true,
          'driveDownload': true,
          'deleteSync': false,
        }),
      );
      addTearDown(client.dispose);
      final harness = _adapter(client);
      await harness.adapter.verifyBackend();
      revision = '202610120001';
      await expectLater(
        harness.adapter.verifyBackend(),
        throwsA(isA<OwnerSyncConflict>()),
      );
    },
  );

  test(
    'snapshot renewal retains the exact previous owner checkpoint',
    () async {
      final oldCursor = _cursor(_snapshot, 5);
      const renewedSnapshot = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
      var renewalProof = oldCursor;
      final client = _client(
        (_) async => _json({
          'ok': true,
          'snapshotId': renewedSnapshot,
          'from': 5,
          'next': 5,
          'highWater': 5,
          'hasMore': false,
          'nextCursor': _cursor(renewedSnapshot, 5),
          'resumedFromCursor': renewalProof,
          'changes': <Object>[],
        }),
      );
      addTearDown(client.dispose);
      final harness = _adapter(client);
      final page = await harness.adapter.download(
        ownerId: _ownerA,
        afterCursor: oldCursor,
        limit: 1,
      );
      expect(page.fromCursor, oldCursor);
      expect(page.nextCursor, _cursor(renewedSnapshot, 5));
      renewalProof = '';
      await expectLater(
        harness.adapter.download(
          ownerId: _ownerA,
          afterCursor: oldCursor,
          limit: 1,
        ),
        throwsA(isA<OwnerSyncConflict>()),
      );
    },
  );

  test(
    'begin upload enforces immutable owner descriptor and response',
    () async {
      late Uri requestedUri;
      late Map<String, dynamic> requestBody;
      final client = _client((request) async {
        requestedUri = request.url;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'ok': true, 'intentId': _intent, 'state': 'staging'});
      });
      final harness = _adapter(client);
      addTearDown(client.dispose);

      final intent = await harness.adapter.beginUpload(_descriptor());
      expect(requestedUri.path, '/functions/v1/phase8-drive-begin');
      expect(requestBody['ownerId'], _ownerA);
      expect(requestBody['ownerScope'], _scope(_ownerA));
      expect(requestBody['sourceIdentity'], _source);
      expect(intent.id, _intent);
      expect(intent.state, OwnerSyncStagingState.staging);
    },
  );

  test(
    'authenticated owner mismatch fails before any network request',
    () async {
      var requests = 0;
      final client = _client((_) async {
        requests++;
        return _json({'ok': true});
      });
      final harness = _adapter(client, auth: () => _ownerB);
      addTearDown(client.dispose);

      await expectLater(
        harness.adapter.beginUpload(_descriptor()),
        throwsA(isA<OwnerSyncConflict>()),
      );
      expect(requests, 0);
    },
  );

  test(
    'private staging upload uses exact owner path and never upserts',
    () async {
      late Uri requestedUri;
      late http.Request captured;
      final client = _client((request) async {
        captured = request;
        requestedUri = request.url;
        return _json({
          'Key': 'phase8-drive-staging/$_ownerA/$_intent/envelope.json',
        });
      });
      final harness = _adapter(client);
      addTearDown(client.dispose);

      await harness.adapter.uploadPrivateObject(
        intentId: _intent,
        envelopeBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(
        requestedUri.path,
        '/storage/v1/object/phase8-drive-staging/$_ownerA/$_intent/envelope.json',
      );
      expect(
        captured.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(captured.headers['x-upsert'], 'false');
      expect(
        captured.body.toLowerCase(),
        contains('content-type: application/json'),
      );
    },
  );

  test(
    'immutable staging duplicate is surfaced for verified finalize retry',
    () async {
      final client = _client((request) async {
        return http.Response(
          jsonEncode({'statusCode': '409', 'error': 'Duplicate'}),
          409,
          headers: const {'content-type': 'application/json'},
        );
      });
      final harness = _adapter(client);
      addTearDown(client.dispose);

      await expectLater(
        harness.adapter.uploadPrivateObject(
          intentId: _intent,
          envelopeBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<OwnerSyncStagedObjectAlreadyExists>()),
      );
    },
  );

  test(
    'finalize receipt is validated against owner and immutable mutation',
    () async {
      final client = _client((request) async {
        return _json({'ok': true, 'receipt': _receipt()});
      });
      final harness = _adapter(client);
      addTearDown(client.dispose);

      final receipt = await harness.adapter.finalizeUpload(_intent);
      expect(receipt.ownerScope, _scope(_ownerA));
      expect(receipt.idempotencyKey, _key);

      final conflictingClient = _client((request) async {
        return _json({
          'ok': true,
          'receipt': _receipt(ownerScope: _scope(_ownerB)),
        });
      });
      final conflicting = _adapter(conflictingClient);
      addTearDown(conflictingClient.dispose);
      await expectLater(
        conflicting.adapter.finalizeUpload(_intent),
        throwsA(isA<OwnerSyncConflict>()),
      );
    },
  );

  test('download starts owner snapshot and parses a stable cursor', () async {
    late Map<String, dynamic> body;
    final client = _client((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({
        'ok': true,
        'snapshotId': _snapshot,
        'from': 0,
        'next': 0,
        'highWater': 0,
        'nextCursor': _cursor(_snapshot, 0),
        'hasMore': false,
        'changes': <Object>[],
      });
    });
    final harness = _adapter(client);
    addTearDown(client.dispose);

    final page = await harness.adapter.download(
      ownerId: _ownerA,
      afterCursor: '',
      limit: 32,
    );
    expect(body, {'action': 'begin', 'limit': 32});
    expect(page.ownerId, _ownerA);
    expect(page.fromCursor, isEmpty);
    expect(page.nextCursor, _cursor(_snapshot, 0));
    expect(page.changes, isEmpty);
  });

  test('download rejects owner changes and malformed cursor pages', () async {
    var authId = _ownerA;
    final client = _client((request) async {
      return _json({
        'ok': true,
        'snapshotId': _snapshot,
        'from': 0,
        'next': 0,
        'highWater': 0,
        'nextCursor': _cursor(_snapshot, 0),
        'hasMore': false,
        'changes': <Object>[],
      });
    });
    final harness = _adapter(client, auth: () => authId);
    addTearDown(client.dispose);

    authId = _ownerB;
    await expectLater(
      harness.adapter.download(ownerId: _ownerA, afterCursor: '', limit: 20),
      throwsA(isA<OwnerSyncConflict>()),
    );
    authId = _ownerA;
    await expectLater(
      harness.adapter.download(
        ownerId: _ownerA,
        afterCursor: 'not-a-cursor',
        limit: 20,
      ),
      throwsA(isA<OwnerSyncConflict>()),
    );
    final nonAdvancingClient = _client(
      (request) async => _json({
        'ok': true,
        'snapshotId': _snapshot,
        'from': 5,
        'next': 5,
        'highWater': 6,
        'nextCursor': _cursor(_snapshot, 5),
        'hasMore': true,
        'changes': <Object>[],
      }),
    );
    final nonAdvancing = _adapter(nonAdvancingClient);
    addTearDown(nonAdvancingClient.dispose);
    await expectLater(
      nonAdvancing.adapter.download(
        ownerId: _ownerA,
        afterCursor: _cursor(_snapshot, 5),
        limit: 20,
      ),
      throwsA(isA<OwnerSyncConflict>()),
    );
  });

  test(
    'owner epoch invalidated during response rejects stale result',
    () async {
      var currentOwner = _ownerA;
      final client = _client((request) async {
        currentOwner = _ownerB;
        return _json({'ok': true, 'intentId': _intent, 'state': 'staging'});
      });
      final harness = _adapter(client, auth: () => currentOwner);
      addTearDown(client.dispose);

      await expectLater(
        harness.adapter.beginUpload(_descriptor()),
        throwsA(isA<OwnerSyncConflict>()),
      );
    },
  );
}
