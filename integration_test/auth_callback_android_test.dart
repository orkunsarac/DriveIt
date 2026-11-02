import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:driveit_project/config/driveit_auth_callback.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_auth_callback_delivery.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Pkce extends GotrueAsyncStorage {
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android warm intent reaches fenced real SDK PKCE exchange',
    (tester) async {
      DriveItAuthCallback.configureForApplicationId(
        'com.example.driveit_project.isolated_test',
      );
      final pkce = _Pkce();
      var exchanges = 0;
      const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final sdk = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: AuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          pkceAsyncStorage: pkce,
          autoRefreshToken: false,
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/recover')) {
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          exchanges++;
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
        'callback_synthetic_',
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
      final account = SupabaseAccountService.forTesting(sdk, null);
      await owner.start();
      account.attachOwnerForTesting(owner);
      await sdk.auth.resetPasswordForEmail('synthetic@example.invalid');
      final done = Completer<void>();
      final delivery = OwnerAuthCallbackDelivery(
        owner: owner,
        exchange: (uri) async {
          await account.exchangeOwnerCallback(uri);
          if (!done.isCompleted) done.complete();
        },
      );
      final subscription = AppLinks().uriLinkStream.listen((uri) {
        unawaited(delivery.deliver(uri));
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('CALLBACK_READY'))),
      );
      await tester.pumpAndSettle();
      try {
        await done.future.timeout(const Duration(seconds: 120));
        expect(owner.lease.owner.userId, uid);
        expect(exchanges, 1);
      } finally {
        delivery.close();
        await subscription.cancel();
        account.detachOwnerForTesting(owner);
        await owner.close();
        owner.dispose();
        account.dispose();
        await sdk.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
