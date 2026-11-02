import 'dart:async';
import 'dart:convert';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'password proof cannot change shared session or follow owner switch',
    () async {
      const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      const url = 'https://arwnbogcswisfesayosy.supabase.co';
      var selected = a;
      var owner = a;
      var epoch = 1;
      var blockProof = false;
      final entered = Completer<void>();
      final release = Completer<void>();
      var updates = 0;
      String payload(String uid, String token) => jsonEncode({
        'access_token': token,
        'refresh_token': 'refresh-$uid',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {
          'id': uid,
          'email': '$uid@example.invalid',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      });
      final sdk = SupabaseClient(
        url,
        'sb_publishable_synthetic',
        httpClient: MockClient(
          (r) async => http.Response(
            payload(selected, 'shared-$selected'),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final transport = MockClient((r) async {
        if (r.url.path.endsWith('/logout')) return http.Response('{}', 200);
        if (r.method == 'PUT') {
          updates++;
          return http.Response(
            jsonEncode({
              'id': a,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (blockProof) {
          entered.complete();
          await release.future;
        }
        return http.Response(
          payload(a, 'proof-a'),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final gateway = OwnerProfileGateway(
        authClient: sdk,
        url: url,
        publicKey: 'sb_publishable_synthetic',
        applicationId: 'com.osaracx.driveit',
        approvedOwner: () => owner,
        approvedEpoch: () => epoch,
        isLeaseCurrent: (e) => e == epoch,
        transport: transport,
      );
      final service = SupabaseAccountService.forTesting(sdk, gateway);
      try {
        await sdk.auth.signInWithPassword(
          email: 'a@example.invalid',
          password: 'x',
        );
        await service.changePassword(
          currentPassword: 'old',
          newPassword: 'new-password',
        );
        expect(updates, 1);
        expect(sdk.auth.currentUser?.id, a);
        expect(sdk.auth.currentSession?.accessToken, 'shared-$a');
        blockProof = true;
        final pending = service.changePassword(
          currentPassword: 'old',
          newPassword: 'new-password',
        );
        await entered.future;
        selected = b;
        await sdk.auth.signInWithPassword(
          email: 'b@example.invalid',
          password: 'x',
        );
        owner = b;
        epoch++;
        final rejected = expectLater(pending, throwsA(isA<StateError>()));
        release.complete();
        await rejected;
        expect(updates, 1);
        expect(sdk.auth.currentUser?.id, b);
      } finally {
        if (!release.isCompleted) release.complete();
        service.dispose();
        await sdk.dispose();
      }
    },
  );
}
