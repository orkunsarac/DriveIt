import 'dart:convert';

import 'package:driveit_project/config/driveit_auth_callback.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class _PkceStorage implements GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async =>
      'synthetic-verifier/${AuthChangeEvent.passwordRecovery.name}';

  @override
  Future<void> removeItem({required String key}) async {}

  @override
  Future<void> setItem({required String key, required String value}) async {}
}

void _result(String result) => runApp(
  MaterialApp(
    home: Scaffold(body: Center(child: Text(result))),
  ),
);

Map<String, dynamic> _user() => {
  'id': _uid,
  'aud': 'authenticated',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'email': 'synthetic@example.invalid',
  'created_at': '2026-01-01T00:00:00Z',
};

String _token() {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': _uid, 'exp': exp})))
      .replaceAll('=', '');
  return 'e30.$payload.synthetic';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST') ||
      (await PackageInfo.fromPlatform()).packageName !=
          'com.example.driveit_project.isolated_test') {
    _result('DENIED');
    return;
  }
  _result('STARTING');
  var phase = 'bootstrap';
  final recoveryToken = _token();
  final pkce = _PkceStorage();
  SupabaseClient clientForRecovery() => SupabaseClient(
    'https://example.invalid',
    'synthetic-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/user') && request.method == 'PUT') {
        final authorization = request.headers['authorization'];
        final password = (jsonDecode(request.body) as Map)['password'];
        return http.Response(
          jsonEncode({
            ..._user(),
            if (authorization != 'Bearer $recoveryToken' ||
                password != 'Synthetic!2027')
              'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/user')) {
        return http.Response(
          jsonEncode(_user()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    }),
  );
  try {
    final sdk = SupabaseClient(
      'https://example.invalid',
      'synthetic-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: pkce,
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': recoveryToken,
              'refresh_token': 'synthetic-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': _user(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/user')) {
          return http.Response(
            jsonEncode(_user()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    final support = await getApplicationSupportDirectory();
    final root = await support.createTemp('driveit_owner_test_recovery_');
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    phase = 'owner-bootstrap';
    final runtime = (await LocalOwnershipBootstrap.run(
      gate: LocalOwnershipGate.synthetic(),
      legacyBootstrap: () async => throw StateError('legacy unavailable'),
      controlled: ControlledOwnershipDependencies(
        descriptor: descriptor,
        databaseFactory: databaseFactory,
        restoreAuth: () async => SupabaseLocalOwnerAuth(sdk),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        producerRunning: () async => false,
        attachForeground: (_, _) async {},
        detachForeground: (_) async {},
        automaticAccountSync: false,
        automaticCloudDeletionRetry: false,
      ),
    ))!;
    phase = 'auth-attach';
    final account = SupabaseAccountService.forTesting(
      sdk,
      null,
      recoveryClientFactory: clientForRecovery,
    );
    account.attachOwnerForTesting(runtime.owner);
    phase = 'account-transition';
    account.startIdentitySync();
    DriveItAuthCallback.configureForApplicationId(
      'com.example.driveit_project.isolated_test',
    );
    phase = 'pkce-exchange';
    final callback = Uri.parse(
      '${DriveItAuthCallback.uri}?code=synthetic-code',
    );
    final exchanged = await account.exchangeOwnerCallback(callback);
    final recoverySession = exchanged.session;
    if (exchanged.redirectType != AuthChangeEvent.passwordRecovery.name) {
      throw StateError('Synthetic recovery event missing');
    }
    phase = 'prepare';
    await account.preparePasswordRecovery(recoverySession);
    phase = 'update';
    await account.completePasswordRecovery('Synthetic!2027');
    phase = 'owner-check';
    _result(
      runtime.owner.lease.owner.userId == _uid &&
              sdk.auth.currentSession?.user.id == _uid
          ? 'PASSWORD_UPDATED owner=A'
          : 'FAIL',
    );
  } catch (error) {
    _result('FAIL-$phase-${error.runtimeType}');
  }
}
