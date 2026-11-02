import 'dart:convert';
import 'package:driveit_project/services/owner_session_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryStorage implements OwnerSessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  const uid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  String token(String sub) =>
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub, 'exp': 2000000000}))).replaceAll('=', '')}.synthetic';
  Session session(String sub) => Session.fromJson({
    'access_token': token(sub),
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'provider_token': 'unneeded',
    'user': {
      'id': uid,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  })!;
  test(
    'vault preserves session without provider credentials and clears',
    () async {
      final memory = MemoryStorage();
      final vault = OwnerSessionVault(memory);
      await vault.save(session(uid));
      expect(memory.value, isNot(contains('unneeded')));
      expect((await vault.load())!.user.id, uid);
      await vault.clear();
      expect(await vault.load(), isNull);
    },
  );
  test(
    'vault rejects mismatched or malformed session without replacing data',
    () async {
      final memory = MemoryStorage();
      final vault = OwnerSessionVault(memory);
      memory.value = 'broken';
      await expectLater(vault.load(), throwsFormatException);
      expect(memory.value, 'broken');
      await expectLater(
        vault.save(session('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')),
        throwsFormatException,
      );
      expect(memory.value, 'broken');
    },
  );
}
