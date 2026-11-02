import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:driveit_project/config/driveit_auth_callback.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_auth_callback_delivery.dart';
import 'package:driveit_project/services/owner_auth_link_listener.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST') ||
      (await PackageInfo.fromPlatform()).packageName !=
          'com.example.driveit_project.isolated_test') {
    runApp(const MaterialApp(home: Text('DENIED')));
    return;
  }
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('STARTING'))),
    ),
  );
  DriveItAuthCallback.configureForApplicationId(
    'com.example.driveit_project.isolated_test',
  );
  const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  var calls = 0;
  var gpsBusy = false;
  final initial = await AppLinks().getInitialLink();
  final gpsScenario = initial?.queryParameters['code'] == 'synthetic-gps';
  final pkce = MemoryPkce();
  final sdk = SupabaseClient(
    'https://example.invalid',
    'synthetic',
    authOptions: AuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      pkceAsyncStorage: pkce,
      autoRefreshToken: false,
    ),
    httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/recover')) {
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      calls++;
      if ((jsonDecode(r.body) as Map<String, dynamic>)['auth_code'] ==
          'synthetic-failure') {
        return http.Response(
          '{"msg":"synthetic failure"}',
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'access_token': 'synthetic',
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
      );
    }),
  );
  final root = await (await getTemporaryDirectory()).createTemp(
    'callback_probe_',
  );
  final owner = LocalOwnerLifecycle(
    gate: LocalOwnershipGate.synthetic(),
    auth: SupabaseLocalOwnerAuth(sdk),
    openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
    driveInProgress: () async => gpsBusy,
    automaticAccountSync: false,
    automaticAccountDownload: false,
    automaticCloudDeletionRetry: false,
  );
  await owner.start();
  gpsBusy = gpsScenario;
  final account = SupabaseAccountService.forTesting(sdk, null);
  account.attachOwnerForTesting(owner);
  await sdk.auth.resetPasswordForEmail('synthetic@example.invalid');
  // Exercise links delivered before the owner listener is attached.
  await Future<void>.delayed(const Duration(seconds: 3));
  final delivery = OwnerAuthCallbackDelivery(
    owner: owner,
    exchange: (uri) async {
      try {
        await account.exchangeOwnerCallback(uri);
      } catch (_) {
        await owner.settled;
        final guest = owner.lease.owner.userId == null;
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(guest ? 'REJECT count=$calls owner=guest' : 'FAIL'),
              ),
            ),
          ),
        );
        return;
      }
      final valid = owner.lease.owner.userId == uid && calls == 1;
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text(valid ? 'PASS count=1 owner=A' : 'FAIL')),
          ),
        ),
      );
    },
  );
  OwnerAuthLinkListener(delivery).start();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('READY count=0 owner=guest'))),
    ),
  );
}
