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
  if (!const bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST') ||
      (await PackageInfo.fromPlatform()).packageName !=
          'com.example.driveit_project.isolated_test') {
    showResult('DENIED');
    return;
  }
  showResult('STARTING');
  try {
    const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final vault = OwnerSessionVault(const AndroidOwnerSessionStorage());
    final stored = await vault.load();
    if (stored == null) {
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': uid, 'exp': expiry})))
          .replaceAll('=', '');
      final session = Session.fromJson({
        'access_token': 'e30.$payload.synthetic',
        'refresh_token': 'synthetic',
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
      showResult('SAVED');
      return;
    }
    final user = {
      'id': uid,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    };
    final sdk = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode(user),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final root = await (await getApplicationSupportDirectory()).createTemp(
      'driveit_owner_test_',
    );
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
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
          ? 'RESTORED owner=A'
          : 'FAIL',
    );
  } catch (_) {
    showResult('FAIL');
  }
}
