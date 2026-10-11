# Isolated Android integration tests

Android integration tests must use a separate debug package so the Flutter test
runner cannot install over or uninstall the user's DriveIt application.

The normal application ID remains `com.example.driveit_project`. Pass the
explicit `DRIVEIT_ISOLATED_ANDROID_TEST=true` Dart define only for a test build;
the Android Gradle script detects the forwarded `dart-defines` property and
appends `.isolated_test` to the debug application ID. A direct Gradle build can
instead use `-PdriveItIsolatedTest=true`. Neither path affects release variants
or ordinary builds.

The test process must also pass
`--dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true`. `SupabaseBootstrap` then
refuses initialization even if Supabase dart-defines are accidentally present.
Never pass a real DEV/PROD config file to these tests. `LocalOwnershipGate` in
the production bootstrap remains disabled; tests that need ownership behavior
must use the explicit synthetic gate and fake Auth fixtures.

## Verify the APK before device use

```powershell
flutter build apk --debug --no-pub `
  --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true
```

Inspect `build/app/outputs/flutter-apk/app-debug.apk` with Android SDK
`apkanalyzer manifest application-id`. Proceed only if the result is exactly
`com.example.driveit_project.isolated_test`.

## Run one test at a time

Pass the same isolated Dart define on every invocation, target the intended
device with `-d`, and always pass `--no-uninstall`. Flutter integration
tests otherwise uninstall their target app by default. For example:

```powershell
flutter test integration_test/owner_world_poster_android_test.dart `
  -d R5CX42V8GSJ --no-pub --no-uninstall `
  --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true
```

The Flutter `integration_test` harness is compiled into the target debug APK;
this project does not build a separate Android instrumentation APK. Verify the
target APK application ID before the first device run. Grant runtime
permissions, if genuinely required, only to the `.isolated_test` package.
