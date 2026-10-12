# Isolated Android integration tests

Android integration tests must use a separate package so the Flutter test
runner cannot install over or uninstall the user's DriveIt application.

The normal application ID remains `com.example.driveit_project`. The Android
Gradle script detects Flutter's `-Ptarget=integration_test/...` target and
fails configuration unless the explicit
`DRIVEIT_ISOLATED_ANDROID_TEST=true` Dart define (or the isolated Gradle
property) selects `com.example.driveit_project.isolated_test`. It also verifies
the selected application ID before Android build tasks proceed. This applies
to debug and release integration-test variants. Ordinary builds retain the
normal ID and signing configuration. The isolated native runtime manifest
marker is enabled only for the isolated variant.

The test process must also pass
`--dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true`. `SupabaseBootstrap` then
refuses initialization even if Supabase dart-defines are accidentally present.
Never pass a real DEV/PROD config file to these tests. `LocalOwnershipGate` in
the production bootstrap remains disabled; tests that need ownership behavior
must use the explicit synthetic gate and fake Auth fixtures.

## The only supported Codex/Windows test entry point

```powershell
.\tool\run_android_integration_test.ps1 `
  -TestFile integration_test/owner_world_poster_android_test.dart `
  -DeviceSerial R5CX42V8GSJ
```

The script accepts only a `.dart` file inside `integration_test/`, requires an
explicit device serial, passes the isolated define itself, and uses
`--no-uninstall`. Flutter's automatic install is protected by the Gradle
configuration guard: an integration-test target without the isolated marker
fails before an APK is produced or installed. Do not invoke
`flutter test integration_test/...` directly.

For any separately built APK that might be installed as a test app, inspect it
with the fail-closed verifier first:

```powershell
.\tool\verify_isolated_android_apk.ps1 `
  -ApkPath build/app/outputs/flutter-apk/app-debug.apk
```

The verifier rejects every package ID except
`com.example.driveit_project.isolated_test`; it does not install anything.
Never use it as a substitute for the Gradle guard in Flutter's test runner.

The Flutter `integration_test` harness is compiled into the target APK; this
project does not build a separate Android instrumentation APK. Grant runtime
permissions, if genuinely required, only to the `.isolated_test` package.
