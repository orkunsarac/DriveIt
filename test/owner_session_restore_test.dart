import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/owner_session_vault.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Mem implements OwnerSessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

String jwt(String uid, int exp) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': exp}))).replaceAll('=', '')}.synthetic';

Map<String, dynamic> userJson(String uid) => {
  'id': uid,
  'aud': 'authenticated',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> refreshJson(String uid, String access, String refresh) => {
  'access_token': access,
  'refresh_token': refresh,
  'expires_in': 3600,
  'token_type': 'bearer',
  'user': userJson(uid),
};

void main() {
  test(
    'expired startup session rotates then restores verified owner',
    () async {
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final old = Session.fromJson({
        ...refreshJson(uid, jwt(uid, now - 1), 'refresh-old'),
        'expires_at': now - 1,
      })!;
      final rotatedAccess = jwt(uid, now + 3600);
      final mem = Mem();
      final vault = OwnerSessionVault(mem);
      await vault.save(old);
      var refreshRequests = 0;
      var verifiedRequests = 0;
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/token')) {
            refreshRequests++;
            expect(jsonDecode(r.body)['refresh_token'], 'refresh-old');
            return http.Response(
              jsonEncode(refreshJson(uid, rotatedAccess, 'refresh-new')),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (r.url.path.endsWith('/user')) {
            verifiedRequests++;
            expect(r.headers['authorization'], 'Bearer $rotatedAccess');
            return http.Response(
              jsonEncode(userJson(uid)),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final root = await Directory.systemTemp.createTemp('refresh_restore_');
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      try {
        await owner.start();
        expect(owner.lease.owner.userId, isNull);
        await restoreVerifiedOwnerSession(
          owner: owner,
          client: sdk,
          vault: vault,
        );
        final stored = await vault.load();
        expect(refreshRequests, 1);
        expect(verifiedRequests, 1);
        expect(sdk.auth.currentUser?.id, uid);
        expect(owner.lease.owner.userId, uid);
        expect(stored?.accessToken, rotatedAccess);
        expect(stored?.refreshToken, 'refresh-new');
      } finally {
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'startup refresh rejects a different owner before opening its store',
    () async {
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final old = Session.fromJson({
        ...refreshJson(uid, jwt(uid, now - 1), 'refresh-old'),
        'expires_at': now - 1,
      })!;
      final vault = OwnerSessionVault(Mem());
      await vault.save(old);
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode(
              refreshJson(other, jwt(other, now + 3600), 'refresh-other'),
            ),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final root = await Directory.systemTemp.createTemp(
        'startup_refresh_owner_',
      );
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      try {
        await owner.start();
        await expectLater(
          restoreVerifiedOwnerSession(owner: owner, client: sdk, vault: vault),
          throwsStateError,
        );
        await owner.settled;
        expect(sdk.auth.currentSession, isNull);
        expect(owner.lease.owner.userId, isNull);
        expect(await vault.load(), isNull);
      } finally {
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test('active refresh rotates under owner fence and GPS blocks it', () async {
    const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final oldAccess = jwt(uid, now + 300);
    final old = Session.fromJson({
      ...refreshJson(uid, oldAccess, 'refresh-old'),
      'expires_at': now + 300,
    })!;
    final nextAccess = jwt(uid, now + 3600);
    final mem = Mem();
    final vault = OwnerSessionVault(mem);
    await vault.save(old);
    var gps = false;
    var refreshRequests = 0;
    final sdk = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/token')) {
          refreshRequests++;
          return http.Response(
            jsonEncode(refreshJson(uid, nextAccess, 'refresh-new')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path.endsWith('/user')) {
          return http.Response(
            jsonEncode(userJson(uid)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await sdk.auth.recoverSession(jsonEncode(old.toJson()));
    final root = await Directory.systemTemp.createTemp('active_refresh_');
    final owner = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
      driveInProgress: () async => gps,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    try {
      await owner.start();
      gps = true;
      await expectLater(
        refreshVerifiedOwnerSession(
          owner: owner,
          client: sdk,
          vault: vault,
          refreshWindow: const Duration(minutes: 10),
        ),
        throwsStateError,
      );
      expect(refreshRequests, 0);
      expect(owner.lease.owner.userId, uid);
      gps = false;
      expect(
        await refreshVerifiedOwnerSession(
          owner: owner,
          client: sdk,
          vault: vault,
          refreshWindow: const Duration(minutes: 10),
        ),
        isTrue,
      );
      expect(owner.lease.owner.userId, uid);
      expect(sdk.auth.currentSession?.accessToken, nextAccess);
      expect((await vault.load())?.refreshToken, 'refresh-new');
    } finally {
      await owner.close();
      owner.dispose();
      await sdk.dispose();
      await root.delete(recursive: true);
    }
  });

  test(
    'different server owner during refresh is closed before owner opens',
    () async {
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final oldAccess = jwt(uid, now + 300);
      final old = Session.fromJson({
        ...refreshJson(uid, oldAccess, 'refresh-old'),
        'expires_at': now + 300,
      })!;
      final mem = Mem();
      final vault = OwnerSessionVault(mem);
      await vault.save(old);
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode(
                refreshJson(other, jwt(other, now + 3600), 'refresh-other'),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode(userJson(other)), 200);
        }),
      );
      await sdk.auth.recoverSession(jsonEncode(old.toJson()));
      final root = await Directory.systemTemp.createTemp('owner_mismatch_');
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      try {
        await owner.start();
        await expectLater(
          refreshVerifiedOwnerSession(
            owner: owner,
            client: sdk,
            vault: vault,
            refreshWindow: const Duration(minutes: 10),
          ),
          throwsStateError,
        );
        await owner.settled;
        expect(sdk.auth.currentSession, isNull);
        expect(owner.lease.owner.userId, isNull);
        expect(await vault.load(), isNull);
      } finally {
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'revoked refresh token closes SDK owner and clears the stale vault',
    () async {
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final access = jwt(uid, now + 300);
      final old = Session.fromJson({
        ...refreshJson(uid, access, 'revoked-refresh'),
        'expires_at': now + 300,
      })!;
      final vault = OwnerSessionVault(Mem());
      await vault.save(old);
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'code': 'refresh_token_not_found',
              'msg': 'Invalid Refresh Token: Refresh Token Not Found',
            }),
            400,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await sdk.auth.recoverSession(jsonEncode(old.toJson()));
      final root = await Directory.systemTemp.createTemp('revoked_refresh_');
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      try {
        await owner.start();
        await expectLater(
          refreshVerifiedOwnerSession(
            owner: owner,
            client: sdk,
            vault: vault,
            refreshWindow: const Duration(minutes: 10),
          ),
          throwsA(anything),
        );
        await owner.settled;
        expect(sdk.auth.currentSession, isNull);
        expect(owner.lease.owner.userId, isNull);
        expect(await vault.load(), isNull);
      } finally {
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'duplicate refresh requests serialize around one rotated credential',
    () async {
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final oldAccess = jwt(uid, now + 300);
      final old = Session.fromJson({
        ...refreshJson(uid, oldAccess, 'refresh-old'),
        'expires_at': now + 300,
      })!;
      final nextAccess = jwt(uid, now + 3600);
      final vault = OwnerSessionVault(Mem());
      await vault.save(old);
      var requests = 0;
      final entered = Completer<void>();
      final release = Completer<void>();
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/token')) {
            requests++;
            entered.complete();
            await release.future;
            return http.Response(
              jsonEncode(refreshJson(uid, nextAccess, 'refresh-new')),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(userJson(uid)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await sdk.auth.recoverSession(jsonEncode(old.toJson()));
      final root = await Directory.systemTemp.createTemp('refresh_race_');
      final owner = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        driveInProgress: () async => false,
        automaticAccountSync: false,
        automaticAccountDownload: false,
        automaticCloudDeletionRetry: false,
      );
      try {
        await owner.start();
        final first = refreshVerifiedOwnerSession(
          owner: owner,
          client: sdk,
          vault: vault,
          refreshWindow: const Duration(minutes: 10),
        );
        await entered.future;
        final second = refreshVerifiedOwnerSession(
          owner: owner,
          client: sdk,
          vault: vault,
          refreshWindow: const Duration(minutes: 10),
        );
        final secondRejected = expectLater(second, throwsStateError);
        release.complete();
        expect(await first, isTrue);
        await secondRejected;
        expect(requests, 1);
        expect(owner.lease.owner.userId, uid);
        expect((await vault.load())?.refreshToken, 'refresh-new');
      } finally {
        if (!release.isCompleted) release.complete();
        await owner.close();
        owner.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'account switch persists only new owner and logout clears vault',
    () async {
      const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      var next = a;
      final memory = Mem();
      final vault = OwnerSessionVault(memory);
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/logout')) return http.Response('{}', 200);
          final payload = base64Url
              .encode(utf8.encode(jsonEncode({'sub': next, 'exp': 2100000000})))
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'e30.$payload.synthetic',
              'refresh_token': 'synthetic',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': next,
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final root = await Directory.systemTemp.createTemp(
        'owner_login_synthetic_',
      );
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
        sessionVault: vault,
      );
      try {
        await owner.start();
        account.attachOwnerForTesting(owner);
        await account.signIn(
          email: 'synthetic@example.invalid',
          password: 'synthetic',
        );
        expect((await vault.load())?.user.id, a);
        next = b;
        await account.signIn(
          email: 'synthetic@example.invalid',
          password: 'synthetic',
        );
        expect((await vault.load())?.user.id, b);
        expect(owner.lease.owner.userId, b);
        await account.signOut();
        expect(await vault.load(), isNull);
        expect(owner.lease.owner.userId, isNull);
        account.detachOwnerForTesting(owner);
      } finally {
        await owner.close();
        owner.dispose();
        account.dispose();
        await sdk.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test('restore requires server verified owner and GPS fence', () async {
    const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final token =
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': a, 'exp': 2100000000}))).replaceAll('=', '')}.synthetic';
    final user = <String, dynamic>{
      'id': a,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    };
    final session = Session.fromJson({
      'access_token': token,
      'refresh_token': 'synthetic',
      'token_type': 'bearer',
      'user': user,
    })!;
    final mem = Mem();
    final vault = OwnerSessionVault(mem);
    await vault.save(session);
    var serverId = a;
    var offline = false;
    var gps = false;
    var requests = 0;
    Completer<void>? entered;
    Completer<void>? release;
    final sdk = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests++;
        if (entered != null) {
          entered.complete();
          await release!.future;
        }
        if (offline) throw const SocketException('offline');
        return http.Response(
          jsonEncode({...user, 'id': serverId}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final root = await Directory.systemTemp.createTemp(
      'owner_restore_synthetic_',
    );
    final owner = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
      driveInProgress: () async => gps,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    try {
      await owner.start();
      gps = true;
      await expectLater(
        restoreVerifiedOwnerSession(owner: owner, client: sdk, vault: vault),
        throwsStateError,
      );
      expect(requests, 0);
      expect(sdk.auth.currentSession, isNull);
      gps = false;
      serverId = b;
      await expectLater(
        restoreVerifiedOwnerSession(owner: owner, client: sdk, vault: vault),
        throwsStateError,
      );
      await owner.settled;
      expect(sdk.auth.currentSession, isNull);
      expect(owner.lease.owner.userId, isNull);
      offline = true;
      await expectLater(
        restoreVerifiedOwnerSession(owner: owner, client: sdk, vault: vault),
        throwsA(anything),
      );
      await owner.settled;
      expect(sdk.auth.currentSession, isNull);
      offline = false;
      serverId = a;
      entered = Completer<void>();
      release = Completer<void>();
      final pending = restoreVerifiedOwnerSession(
        owner: owner,
        client: sdk,
        vault: vault,
      );
      await entered.future;
      // Emulate an asynchronous logout event while server verification waits.
      // ignore: invalid_use_of_internal_member
      sdk.auth.notifyAllSubscribers(AuthChangeEvent.signedOut);
      await Future<void>.delayed(Duration.zero);
      final rejected = expectLater(pending, throwsStateError);
      release.complete();
      await rejected;
      await owner.settled;
      expect(sdk.auth.currentSession, isNull);
      entered = null;
      release = null;
      await restoreVerifiedOwnerSession(
        owner: owner,
        client: sdk,
        vault: vault,
      );
      expect(sdk.auth.currentUser?.id, a);
      expect(owner.lease.owner.userId, a);
    } finally {
      await owner.close();
      owner.dispose();
      await sdk.dispose();
      await root.delete(recursive: true);
    }
  });
}
