import 'dart:convert';

import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('SDK mutates current session before asynchronous owner event', () async {
    const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    var next = a;
    final client = SupabaseClient(
      'https://example.invalid',
      'synthetic-public-key',
      httpClient: MockClient((request) async {
        final payload = {
          'access_token': 'synthetic-token',
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
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final adapter = SupabaseLocalOwnerAuth(client);
    final ownerEvents = <String?>[];
    final eventSubscription = adapter.changes.listen(ownerEvents.add);
    final snapshots = <({String? sdkId, String? observedOwner})>[];
    // Test-only observation of SDK ordering; production code does not use it.
    // ignore: invalid_use_of_internal_member
    final syncSubscription = client.auth.onAuthStateChangeSync.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        snapshots.add((
          sdkId: client.auth.currentUser?.id,
          observedOwner: ownerEvents.isEmpty ? null : ownerEvents.last,
        ));
      }
    });
    try {
      await client.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      await Future<void>.delayed(Duration.zero);
      next = b;
      await client.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      expect(snapshots.last.sdkId, b);
      expect(snapshots.last.observedOwner, a);
      await Future<void>.delayed(Duration.zero);
      expect(ownerEvents.last, b);
    } finally {
      await eventSubscription.cancel();
      await syncSubscription.cancel();
      await client.dispose();
    }
  });
}
