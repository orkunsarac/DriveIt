import 'dart:async';
import 'dart:convert';

import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('real profile service fences SDK switch and late response', () async {
    const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    var sdkUser = a;
    var token = 'token-a';
    var owner = a;
    var epoch = 1;
    var wait = false;
    final entered = Completer<void>();
    final release = Completer<void>();
    final headers = <String?>[];
    final auth = SupabaseClient(
      'https://arwnbogcswisfesayosy.supabase.co',
      'public',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': sdkUser,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final transport = MockClient((request) async {
      headers.add(request.headers['authorization']);
      if (wait) {
        entered.complete();
        await release.future;
      }
      final responseOwner = request.headers['authorization'] == 'Bearer token-a'
          ? a
          : b;
      return http.Response(
        jsonEncode({
          'id': responseOwner,
          'username': 'name',
          'display_name': 'Name',
        }),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = OwnerProfileGateway(
      authClient: auth,
      url: 'https://arwnbogcswisfesayosy.supabase.co',
      publicKey: 'sb_publishable_synthetic',
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => owner,
      approvedEpoch: () => epoch,
      isLeaseCurrent: (e) => e == epoch,
      transport: transport,
    );
    final service = SupabaseAccountService.forTesting(auth, gateway);
    try {
      await auth.auth.signInWithPassword(
        email: 'a@example.invalid',
        password: 'x',
      );
      await expectLater(
        service.completePasswordRecovery('NewDrive!2026'),
        throwsA(isA<AccountServiceException>()),
      );
      expect((await service.fetchCurrentProfile())?.id, a);
      expect(service.profile?.id, a);
      wait = true;
      final pending = service.fetchCurrentProfile();
      await entered.future;
      sdkUser = b;
      token = 'token-b';
      await auth.auth.signInWithPassword(
        email: 'b@example.invalid',
        password: 'x',
      );
      expect(service.profile, isNull);
      await expectLater(
        service.updateDisplayName('New name'),
        throwsA(isA<StateError>()),
      );
      expect(headers.every((h) => h == 'Bearer token-a'), isTrue);
      owner = b;
      epoch++;
      final rejected = expectLater(pending, throwsA(isA<StateError>()));
      release.complete();
      await rejected;
      expect(service.profile, isNull);
      wait = false;
      expect((await service.fetchCurrentProfile())?.id, b);
      expect(service.profile?.id, b);
      epoch++;
      expect(service.profile, isNull);
      expect((await service.fetchCurrentProfile())?.id, b);
      token = 'token-b-refreshed';
      await auth.auth.refreshSession();
      expect((await service.fetchCurrentProfile())?.id, b);
      final savedSession = jsonEncode(auth.auth.currentSession!.toJson());
      await auth.auth.signOut();
      expect(service.profile, isNull);
      expect(await service.fetchCurrentProfile(), isNull);
      await auth.auth.recoverSession(savedSession);
      expect((await service.fetchCurrentProfile())?.id, b);
      expect((await service.updateDisplayName('New name')).id, b);
      expect(headers.last, 'Bearer token-b-refreshed');
    } finally {
      if (!release.isCompleted) release.complete();
      await auth.dispose();
    }
  });
}
