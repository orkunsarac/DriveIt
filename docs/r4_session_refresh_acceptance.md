# R4 controlled refresh acceptance

Status: PASS for the controlled refresh path in the existing owner runtime.

## Implementation

- Expired or near-expiry vault sessions are refreshed through Supabase GoTrue
  `refreshSession(refreshToken)` during startup, before the foreground service
  or account owner store is attached.
- Active sessions are refreshed on app resume when within the two-minute
  window. SDK automatic persistence and automatic refresh remain disabled.
- Both paths keep the existing owner identity-change fence held while the SDK
  mutates its shared session, call server `getUser` for the resulting access
  token, require the same non-anonymous UID and token pair, and persist rotated
  credentials only to `AndroidOwnerSessionStorage` after verification.
- Refresh is refused during an active/recoverable GPS session. An unverified
  replacement is signed out locally before the owner lock is released; account
  and guest stores and GPS journals are not deleted or relabeled.

## Evidence

- Targeted Flutter suite: 36 tests passed across
  `owner_session_restore_test.dart`, `owner_session_vault_test.dart`, and
  `local_owner_bootstrap_writer_test.dart`.
- `flutter analyze` on the changed runtime, account service, app lifecycle,
  refresh tests, and Android probe: no issues found.
- Debug APK built from
  `integration_test/owner_session_restore_probe.dart` with
  `DRIVEIT_ISOLATED_ANDROID_TEST=true`. `aapt` verified application ID
  `com.example.driveit_project.isolated_test` before A55 installation.
- On Samsung A55 (`R5CX42V8GSJ`), the isolated app stored an expired synthetic
  session, was force-stopped and reopened, then displayed `ROTATED owner=A`.
  After a second force-stop and cold restart it displayed `RESTORED owner=A`.
  The probe used a synthetic HTTP client; no PROD Supabase project, account,
  or email was used. Android Keystore-backed FlutterSecureStorage was used.
- The regular `com.osaracx.driveit` package was not modified, reset, or
  reinstalled. Play Auth, PROD signup, and Group Drive gates remain closed.

## Scope limits

The A55 acceptance verifies Android secure-storage persistence and the real
Flutter owner-bootstrap path with the installed Supabase SDK and synthetic
responses. It does not claim a physical-device request to Supabase PROD, real
account authentication, or real email acceptance. On a network refresh error,
the old SDK session is closed locally under the owner fence while the encrypted
vault remains available for a later startup retry; local drive and GPS data
remain intact.
