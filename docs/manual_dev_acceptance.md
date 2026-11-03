# Manual DEV acceptance APK

This harness is a debug-only manual test target. It uses only the DEV project
`https://viqngnjfgknpxtoapzcg.supabase.co`; it accepts a Supabase
`sb_publishable_` key at runtime. Never put a key, test password, or account
email in build defines, source files, shell history, logs, or commits.

Build from the repository root:

```powershell
flutter build apk --debug --no-pub `
  -t lib/features/dev_acceptance/manual_dev_acceptance_app.dart `
  --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true `
  --dart-define=DRIVEIT_MANUAL_DEV_ACCEPTANCE=true
```

Before installation, inspect the APK application ID and require
`com.example.driveit_project.isolated_test`. Install/update only that package.
Do not uninstall or clear either normal DriveIt package.

In the app, paste the publishable key from the DEV Dashboard, connect, and
enter the temporary DEV account credentials directly into Account A and
Account B fields. Run the numbered checks individually: Account A login and
profile, synthetic GPS/score, upload/finalize/download, Account B isolation,
Account A secure-vault restore, Planet owner read, and logout. Planet schema2
publication is separate, requires an explicit confirmation, and creates DEV
data that is not automatically deleted. Account deletion is not present in
this harness.

The key is held in memory only and the password input is cleared after use.
App results show PASS/FAIL plus a sanitized short code. The harness disables
SDK automatic token refresh and uses the existing Android owner-session vault
for the explicit restore check. These manual server checks still require the
operator to provide DEV credentials and must not be represented as passing
until run.
