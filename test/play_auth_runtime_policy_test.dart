import 'package:driveit_project/config/play_auth_runtime_policy.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play Auth is closed and the policy requires an enabled gate', () {
    expect(SupabaseBootstrap.playAuthEnabled, isFalse);
    expect(
      PlayAuthRuntimePolicy.permitsBootstrap(
        applicationId: 'com.osaracx.driveit',
        playAuthEnabled: false,
      ),
      isFalse,
    );
    expect(
      PlayAuthRuntimePolicy.permitsBootstrap(
        applicationId: 'com.osaracx.driveit',
        playAuthEnabled: true,
      ),
      isTrue,
    );
    expect(
      PlayAuthRuntimePolicy.permitsBootstrap(
        applicationId: 'com.example.driveit_project',
        playAuthEnabled: false,
      ),
      isTrue,
    );
  });
  test('Play identity change requires owner binding', () {
    expect(
      PlayAuthRuntimePolicy.permitsIdentityChange(
        isPlay: true,
        ownerBound: false,
      ),
      isFalse,
    );
    expect(
      PlayAuthRuntimePolicy.permitsIdentityChange(
        isPlay: true,
        ownerBound: true,
      ),
      isTrue,
    );
    expect(
      PlayAuthRuntimePolicy.permitsIdentityChange(
        isPlay: false,
        ownerBound: false,
      ),
      isTrue,
    );
  });
}
