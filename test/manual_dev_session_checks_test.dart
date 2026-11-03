import 'dart:convert';
import 'package:driveit_project/features/dev_acceptance/manual_dev_session_checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';
import 'package:driveit_project/services/owner_sync_canonical_json.dart';

void main() {
  test(
    'official download proof rejects tampering and foreign owner/source',
    () {
      final payload = <String, dynamic>{
        'drive': {'id': 'drive'},
        'score': 900,
        'telemetry': [1, 2],
      };
      final expected = OwnerSyncMutation(
        version: 2,
        kind: OwnerSyncMutationKind.driveUpsert,
        ownerScope: 'scope-a',
        ownerId: 'a',
        idempotencyKey: 'intent',
        payloadFingerprint: canonicalOwnerSyncSha256(payload),
        sourceIdentity: 'source-a',
        payload: payload,
      );
      expect(
        ManualDevSessionChecks.downloadMatches(
          expected,
          OwnerSyncMutation.fromMap(expected.toMap()),
        ),
        isTrue,
      );
      for (final changed in [
        {...expected.toMap(), 'ownerId': 'b'},
        {...expected.toMap(), 'sourceIdentity': 'source-b'},
        {...expected.toMap(), 'payloadFingerprint': 'wrong'},
        {
          ...expected.toMap(),
          'payload': {...payload, 'score': 901},
        },
        {
          ...expected.toMap(),
          'payload': {
            ...payload,
            'telemetry': [1, 3],
          },
        },
      ]) {
        expect(
          ManualDevSessionChecks.downloadMatches(
            expected,
            OwnerSyncMutation.fromMap(changed),
          ),
          isFalse,
        );
      }
    },
  );
  test(
    'Storage denial requires exact semantic rejection and official A download proof',
    () {
      for (final status in ['400', '404']) {
        final denied = StorageException('Object not found', statusCode: status);
        expect(
          ManualDevSessionChecks.storageDenied(
            denied,
            officialDownloadVerified: true,
          ),
          isTrue,
        );
        expect(
          ManualDevSessionChecks.storageDenied(
            denied,
            officialDownloadVerified: false,
          ),
          isFalse,
        );
      }
      for (final status in ['400', '401', '403', '500']) {
        expect(
          ManualDevSessionChecks.storageDenied(
            StorageException('Bad request', statusCode: status),
            officialDownloadVerified: true,
          ),
          isFalse,
        );
      }
      expect(
        ManualDevSessionChecks.storageDenied(
          const StorageException(
            'The resource was not found',
            statusCode: '400',
            error: 'not_found',
          ),
          officialDownloadVerified: true,
        ),
        isTrue,
      );
    },
  );

  test(
    'real SDK recreation does not revoke session and verifies vault candidate on server',
    () async {
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final user = {
        'id': uid,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      };
      final requests = <String>[];
      SupabaseClient create() => SupabaseClient(
        'https://viqngnjfgknpxtoapzcg.supabase.co',
        'test-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path.endsWith('/logout')) {
            return http.Response('{"code":"session_not_found"}', 403);
          }
          if (request.url.path.endsWith('/user')) {
            return http.Response(
              jsonEncode(user),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'access_token': 'synthetic-access',
              'refresh_token': 'synthetic-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': user,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final old = create();
      final signed = await old.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic-only',
      );
      final vaultCandidate = signed.session!;
      final fresh = await ManualDevSessionChecks.recreate(old, create);
      expect(fresh.auth.currentSession, isNull);
      final verified = await fresh.auth.getUser(vaultCandidate.accessToken);
      expect(verified.user!.id, uid);
      await fresh.auth.recoverSession(jsonEncode(vaultCandidate.toJson()));
      expect(fresh.auth.currentUser!.id, uid);
      expect(
        fresh.auth.currentSession!.refreshToken,
        vaultCandidate.refreshToken,
      );
      expect(requests.any((path) => path.endsWith('/logout')), isFalse);
      await fresh.dispose();
    },
  );
}
