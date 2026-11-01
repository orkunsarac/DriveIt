import 'dart:convert';
import 'package:driveit_project/config/supabase_public_key_policy.dart';
import 'package:flutter_test/flutter_test.dart';

String token(String role) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.signature';

void main() {
  test('permits only publishable or legacy anon-shaped keys', () {
    expect(
      SupabasePublicKeyPolicy.permits('sb_publishable_synthetic_example'),
      isTrue,
    );
    expect(SupabasePublicKeyPolicy.permits(token('anon')), isTrue);
    expect(SupabasePublicKeyPolicy.permits(token('service_role')), isFalse);
    expect(
      SupabasePublicKeyPolicy.permits('sb_secret_synthetic_example'),
      isFalse,
    );
    expect(SupabasePublicKeyPolicy.permits('malformed'), isFalse);
  });
}
