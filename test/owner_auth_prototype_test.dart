import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/owner_auth_prototype.dart';

void main() {
  test(
    'mismatched captured credential is rejected before client creation',
    () async {
      const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final auth = SupabaseClient(
        'https://example.invalid',
        'synthetic-public',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'access_token': 'synthetic-A',
              'refresh_token': 'synthetic-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': a,
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
      await auth.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      expect(
        () => OwnerAuthPrototype(
          authClient: auth,
          ownerId: a,
          epoch: 1,
          isCurrent: (_) => true,
          capturedToken: 'synthetic-B',
          transport: MockClient((_) async => http.Response('{}', 200)),
        ),
        throwsStateError,
      );
      await auth.dispose();
    },
  );
  test(
    'SDK B while owner A rejects new A request; in-flight A uses only A token',
    () async {
      const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      var next = a;
      final auth = SupabaseClient(
        'https://example.invalid',
        'synthetic-public',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'access_token': next == a ? 'synthetic-A' : 'synthetic-B',
              'refresh_token': 'synthetic-refresh',
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
          ),
        ),
      );
      final entered = Completer<void>();
      final finish = Completer<void>();
      final headers = <String?>[];
      var epoch = 1;
      await auth.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      final context = OwnerAuthPrototype(
        authClient: auth,
        ownerId: a,
        epoch: 1,
        isCurrent: (value) => epoch == value,
        capturedToken: auth.auth.currentSession!.accessToken,
        transport: MockClient((request) async {
          headers.add(request.headers['authorization']);
          entered.complete();
          await finish.future;
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      try {
        final inFlight = context.invoke('synthetic', {'payload': 'A'});
        await entered.future;
        next = b;
        await auth.auth.signInWithPassword(
          email: 'synthetic@example.invalid',
          password: 'synthetic',
        );
        expect(auth.auth.currentUser?.id, b);
        await expectLater(
          context.invoke('synthetic', {'payload': 'A'}),
          throwsA(isA<StateError>()),
        );
        expect(headers.length, 1);
        expect(headers.single == 'Bearer synthetic-A', isTrue);
        epoch++;
        final lateResponse = expectLater(inFlight, throwsA(isA<StateError>()));
        finish.complete();
        await lateResponse;
        expect(
          headers.any((header) => header == 'Bearer synthetic-B'),
          isFalse,
        );
      } finally {
        if (!finish.isCompleted) finish.complete();
        await context.dispose();
        await auth.dispose();
      }
    },
  );
}
