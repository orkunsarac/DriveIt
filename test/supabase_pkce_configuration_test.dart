import 'dart:convert';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryPkce extends GotrueAsyncStorage {
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
  test(
    'Play auth options disable unattended callback, restore and refresh',
    () {
      final options = SupabaseBootstrap.playAuthOptions;
      expect(options.authFlowType, AuthFlowType.pkce);
      expect(options.detectSessionInUri, isFalse);
      expect(options.persistSession, isFalse);
      expect(options.autoRefreshToken, isFalse);
    },
  );
  test('recovery uses configured PKCE S256 and exact callback', () async {
    final storage = _MemoryPkce();
    final transport = MockClient((request) async {
      expect(request.url.path, '/auth/v1/recover');
      expect(
        request.url.queryParameters['redirect_to'],
        'com.osaracx.driveit://auth/callback',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['code_challenge_method'], 's256');
      expect(body['code_challenge'], isA<String>());
      expect((body['code_challenge'] as String).isNotEmpty, isTrue);
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final options = SupabaseBootstrap.authOptions.copyWith(
      pkceAsyncStorage: storage,
    );
    final client = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: options,
      httpClient: transport,
    );
    await client.auth.resetPasswordForEmail(
      'synthetic@example.invalid',
      redirectTo: 'com.osaracx.driveit://auth/callback',
    );
    expect(storage.values, isNotEmpty);
    await client.dispose();
  });
}
