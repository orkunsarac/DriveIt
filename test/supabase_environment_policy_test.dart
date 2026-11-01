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
  test('strict DEV rejects PROD, unknown packages and malformed targets', () {
    const id = 'com.example.driveit_project';
    expect(
      SupabaseEnvironmentPolicy.permits(
        applicationId: id,
        url: 'https://viqngnjfgknpxtoapzcg.supabase.co',
        strictDev: true,
      ),
      isTrue,
    );
    for (final url in [
      'https://arwnbogcswisfesayosy.supabase.co',
      'http://viqngnjfgknpxtoapzcg.supabase.co',
      'https://viqngnjfgknpxtoapzcg.supabase.co.evil.test',
      '',
    ]) {
      expect(
        SupabaseEnvironmentPolicy.permits(
          applicationId: id,
          url: url,
          strictDev: true,
        ),
        isFalse,
      );
    }
    expect(
      SupabaseEnvironmentPolicy.permits(
        applicationId: 'unknown',
        url: 'https://viqngnjfgknpxtoapzcg.supabase.co',
        strictDev: true,
      ),
      isFalse,
    );
    expect(
      SupabaseEnvironmentPolicy.permits(
        applicationId: 'com.osaracx.driveit',
        url: 'https://arwnbogcswisfesayosy.supabase.co',
        strictDev: true,
      ),
      isFalse,
    );
  });
}
