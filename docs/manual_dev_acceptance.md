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

Test 4 reports Auth, profile, cloud and Storage results separately. A successful
canonical mutation, payload fingerprint and source identity check through A's
official phase8-drive-download response is required before B's precise
not-found or access-denied response is accepted as an isolation result. Generic
HTTP 400 and expired/invalid JWT responses are failures.

Test 5 recreates the SDK client without logging out at the server. It verifies
the vault candidate using Auth, refreshes when necessary, and requires the same
A identity before enabling owner data. This is an SDK recreation check, not an
OS process-death acceptance. Live DEV retesting is performed by the operator.

Connecting the DEV client also attempts vault restore. If that stored session
has been revoked or cannot be verified, restore reports its own failure, owner
access stays closed, and a fresh empty SDK permits manual login. The connection
result `dev_client_ready_sign_in_required` means the client is ready for login;
it does not claim that the old session or a server acceptance test passed. The
vault is preserved until a successful login explicitly saves a new session.
