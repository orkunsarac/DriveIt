import 'dart:convert';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/owner_session_vault.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';

void showResult(String text) => runApp(
  MaterialApp(
    home: Scaffold(body: Center(child: Text(text))),
  ),
);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var stage = 'package_guard';
  var unmatchedRoute = '';
  var refreshRequests = 0;
  if (!const bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST') ||
      (await PackageInfo.fromPlatform()).packageName !=
          'com.example.driveit_project.isolated_test') {
    showResult('DENIED');
    return;
  }
  showResult('STARTING');
  try {
    const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    stage = 'vault_load';
    showResult('STAGE $stage');
    final vault = OwnerSessionVault(const AndroidOwnerSessionStorage());
    final stored = await vault.load();
    if (stored?.refreshToken != 'refresh-expired' &&
        stored?.refreshToken != 'refresh-rotated') {
      stage = 'vault_save_expired';
      showResult('STAGE $stage');
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': uid, 'exp': expiry})))
          .replaceAll('=', '');
      final session = Session.fromJson({
        'access_token': 'e30.$payload.synthetic',
        'refresh_token': 'refresh-expired',
        'token_type': 'bearer',
        'user': {
          'id': uid,
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      })!;
      await vault.save(session);
      showResult('SAVED_EXPIRED');
      return;
    }
    stage = 'sdk_client';
    showResult('STAGE $stage');
    final user = {
      'id': uid,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    };
    final restoredStored = stored!;
    if (restoredStored.user.id != uid) {
      throw StateError('Synthetic owner mismatch');
    }
    final sdk = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/token')) {
          refreshRequests++;
          final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
          final payload = base64Url
              .encode(utf8.encode(jsonEncode({'sub': uid, 'exp': expiry})))
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'e30.$payload.rotated',
              'refresh_token': 'refresh-rotated',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': user,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path.endsWith('/user')) {
          return http.Response(
            jsonEncode(user),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        unmatchedRoute = '${r.method} ${r.url.path}';
        return http.Response('{}', 404);
      }),
    );
    stage = 'owner_runtime_prepare';
    showResult('STAGE $stage');
    final root = await (await getApplicationSupportDirectory()).createTemp(
      'driveit_owner_test_',
    );
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    stage = 'owner_session_restore';
    showResult('STAGE $stage');
    final runtime = (await LocalOwnershipBootstrap.run(
      gate: LocalOwnershipGate.synthetic(),
      legacyBootstrap: () async => throw StateError('legacy unavailable'),
      controlled: ControlledOwnershipDependencies(
        descriptor: descriptor,
        databaseFactory: databaseFactory,
        restoreAuth: () async => SupabaseLocalOwnerAuth(sdk),
        restoreSession: (owner) => restoreVerifiedOwnerSession(
          owner: owner,
          client: sdk,
          vault: vault,
        ),
        openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
        producerRunning: () async => false,
        attachForeground: (_, _) async {},
        detachForeground: (_) async {},
        automaticAccountSync: false,
        automaticCloudDeletionRetry: false,
      ),
    ))!;
    showResult(
      runtime.owner.lease.owner.userId == uid && sdk.auth.currentUser?.id == uid
          ? '${refreshRequests == 0 ? 'RESTORED' : 'ROTATED'} owner=A'
          : 'FAIL',
    );
  } catch (error) {
    // Show only a stage label and runtime type. Never render exception text,
    // since auth/network failures may contain URLs or credentials.
    final detail = error is AuthException
        ? ' status=${error.statusCode ?? '-'} code=${error.code ?? '-'}'
        : '';
    final route = unmatchedRoute.isEmpty ? '' : ' route=$unmatchedRoute';
    showResult('FAIL $stage ${error.runtimeType}$detail$route');
  }
}
