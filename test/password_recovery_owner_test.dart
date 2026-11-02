import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

Future<void> _emitRecoveryEvent(SupabaseClient client) async {
  // The callback transport is covered separately; emit the SDK's exact event
  // here to test that the service requires that event and its session.
  // ignore: invalid_use_of_internal_member
  client.auth.notifyAllSubscribers(AuthChangeEvent.passwordRecovery);
  await Future<void>.delayed(Duration.zero);
}

String _accessToken(String owner, {int? expiry}) {
  final exp = expiry ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': exp})))
      .replaceAll('=', '');
  return 'e30.$payload.synthetic';
}

Map<String, dynamic> _user(String owner) => {
  'id': owner,
  'aud': 'authenticated',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'email': 'synthetic@example.invalid',
  'created_at': '2026-01-01T00:00:00Z',
};

Session _session(String owner, {int? expiry}) => Session.fromJson({
  'access_token': _accessToken(owner, expiry: expiry),
  'refresh_token': 'refresh-$owner',
  'expires_at': expiry ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  'token_type': 'bearer',
  'user': _user(owner),
})!;

void main() {
  test('guest to recovery account updates only pinned session A', () async {
    final requests = <http.Request>[];
    Future<http.Response> handler(http.Request request) async {
      requests.add(request);
      if (request.url.path.endsWith('/user') && request.method == 'GET') {
        return http.Response(
          jsonEncode(_user(_ownerA)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/user') && request.method == 'PUT') {
        return http.Response(
          jsonEncode(_user(_ownerA)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    }

    final sdk = SupabaseClient(
      'https://example.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(handler),
    );
    final root = await Directory.systemTemp.createTemp('recovery_owner_');
    final owner = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
      driveInProgress: () async => false,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    final account = SupabaseAccountService.forTesting(
      sdk,
      null,
      recoveryClientFactory: () => SupabaseClient(
        'https://example.invalid',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(handler),
      ),
    );
    try {
      account.startIdentitySync();
      await owner.start();
      expect(owner.lease.owner.userId, isNull);
      await sdk.auth.recoverSession(jsonEncode(_session(_ownerA).toJson()));
      await owner.settled;
      account.attachOwnerForTesting(owner);
      final recoverySession = sdk.auth.currentSession!;
      await expectLater(
        account.preparePasswordRecovery(recoverySession),
        throwsA(isA<AccountServiceException>()),
      );
      await _emitRecoveryEvent(sdk);
      await account.preparePasswordRecovery(recoverySession);
      await account.completePasswordRecovery('NewDrive!2027');

      final update = requests.singleWhere((r) => r.method == 'PUT');
      expect(
        update.headers['authorization'],
        'Bearer ${recoverySession.accessToken}',
      );
      expect(jsonDecode(update.body)['password'], 'NewDrive!2027');
      expect(owner.lease.owner.userId, _ownerA);
      expect(sdk.auth.currentSession?.user.id, _ownerA);
      expect(sdk.auth.currentSession?.accessToken, recoverySession.accessToken);
      await expectLater(
        account.completePasswordRecovery('AnotherDrive!2027'),
        throwsA(isA<AccountServiceException>()),
      );
    } finally {
      account.detachOwnerForTesting(owner);
      account.dispose();
      await owner.close();
      owner.dispose();
      await sdk.dispose();
      await root.delete(recursive: true);
    }
  });

  test(
    'A to B switch after recovery callback rejects update before request',
    () async {
      var updates = 0;
      final sessionA = _session(_ownerA);
      final sessionB = _session(_ownerB);
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.method == 'PUT' && r.url.path.endsWith('/user')) updates++;
          final uid =
              r.headers['authorization'] == 'Bearer ${sessionB.accessToken}'
              ? _ownerB
              : _ownerA;
          return http.Response(
            jsonEncode(_user(uid)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await sdk.auth.recoverSession(jsonEncode(sessionA.toJson()));
      final root = await Directory.systemTemp.createTemp('recovery_switch_');
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      final account = SupabaseAccountService.forTesting(
        sdk,
        null,
        recoveryClientFactory: () => SupabaseClient(
          'https://example.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (r) async => http.Response(
              jsonEncode(_user(_ownerA)),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );
      try {
        account.startIdentitySync();
        await owner.start();
        account.attachOwnerForTesting(owner);
        await _emitRecoveryEvent(sdk);
        await account.preparePasswordRecovery(sdk.auth.currentSession!);
        await sdk.auth.recoverSession(jsonEncode(sessionB.toJson()));
        await owner.settled;
        await expectLater(
          account.completePasswordRecovery('NewDrive!2027'),
          throwsA(isA<AccountServiceException>()),
        );
        expect(updates, 0);
        expect(owner.lease.owner.userId, _ownerB);
        await _emitRecoveryEvent(sdk);
        await account.preparePasswordRecovery(sdk.auth.currentSession!);
        await sdk.auth.signOut(scope: SignOutScope.local);
        await owner.settled;
        await expectLater(
          account.completePasswordRecovery('NewDrive!2027'),
          throwsA(isA<AccountServiceException>()),
        );
        expect(updates, 0);
        expect(owner.lease.owner.userId, isNull);
      } finally {
        account.detachOwnerForTesting(owner);
        account.dispose();
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'active GPS, expired callback and verification network errors fail closed',
    () async {
      const expired = 1700000000;
      var gps = false;
      var networkFailure = false;
      var requests = 0;
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests++;
          if (networkFailure) throw const SocketException('offline');
          return http.Response(
            jsonEncode(_user(_ownerA)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await sdk.auth.recoverSession(jsonEncode(_session(_ownerA).toJson()));
      final root = await Directory.systemTemp.createTemp('recovery_failures_');
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => gps,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      final account = SupabaseAccountService.forTesting(
        sdk,
        null,
        recoveryClientFactory: () => SupabaseClient(
          'https://example.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async => http.Response('{}', 500)),
        ),
      );
      try {
        account.startIdentitySync();
        await owner.start();
        account.attachOwnerForTesting(owner);
        await _emitRecoveryEvent(sdk);
        final beforeGps = requests;
        gps = true;
        await expectLater(
          account.preparePasswordRecovery(sdk.auth.currentSession!),
          throwsStateError,
        );
        expect(requests, beforeGps);
        gps = false;
        networkFailure = true;
        await expectLater(
          account.preparePasswordRecovery(sdk.auth.currentSession!),
          throwsA(anything),
        );
        networkFailure = false;
        final oldCallback = _session(_ownerA, expiry: expired);
        // The callback token no longer matches the active, newer session.
        await expectLater(
          account.preparePasswordRecovery(oldCallback),
          throwsA(isA<AccountServiceException>()),
        );
      } finally {
        account.detachOwnerForTesting(owner);
        account.dispose();
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
