import 'package:driveit_project/config/supabase_environment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play permits only the exact HTTPS production project', () {
    const id = 'com.osaracx.driveit';
    expect(
      SupabaseEnvironmentPolicy.permits(
        applicationId: id,
        url: 'https://arwnbogcswisfesayosy.supabase.co',
      ),
      isTrue,
    );
    for (final url in [
      'https://viqngnjfgknpxtoapzcg.supabase.co',
      'http://arwnbogcswisfesayosy.supabase.co',
      'https://arwnbogcswisfesayosy.supabase.co.evil.test',
      'https://arwnbogcswisfesayosy.supabase.co/other',
      'https://arwnbogcswisfesayosy.supabase.co?redirect=https://evil.test',
    ]) {
      expect(
        SupabaseEnvironmentPolicy.permits(applicationId: id, url: url),
        isFalse,
      );
    }
  });
  test('existing developer configuration stays available', () {
    expect(
      SupabaseEnvironmentPolicy.permits(
        applicationId: 'com.example.driveit_project',
        url: 'https://viqngnjfgknpxtoapzcg.supabase.co',
      ),
      isTrue,
    );
  });
}
