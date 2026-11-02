# R4 — Password recovery acceptance

Status: PASS for the controlled recovery flow with the existing Supabase SDK
and owner runtime. Play Auth, PROD signup, SMTP, and Group Drive remain closed.

## Behavior

- The service observes the SDK `PASSWORD_RECOVERY` event and pins its exact
  session. An ordinary signed-in session cannot create a recovery ticket.
- Preparation waits for the current owner transition, checks the callback
  session against the shared SDK session, and verifies its UID with Supabase
  `getUser`. The ticket is bound to that UID, access/refresh tokens, owner
  lease, and owner epoch.
- Password update holds the existing owner/GPS operation fence. It rechecks
  the ticket and server identity, then uses a short-lived Supabase SDK client
  restored with the pinned session. Its `updateUser` request therefore uses
  the pinned bearer token even if the shared SDK session changes later. The
  temporary client has automatic refresh disabled and is disposed locally.
- Ticket reuse, expiry, GPS activity, owner change, logout, and server or
  network verification failures reject the update. The normal owner session
  remains in place on success; an account switch or logout clears the ticket.
- The existing `DriveItPasswordRecoveryScreen` now reaches this service
  through its existing `DriveItAccountGateway` method.

## Test evidence

- Targeted Flutter suite: **45/45 PASS** across
  `password_recovery_owner_test.dart`, `driveit_auth_callback_test.dart`,
  `owner_session_restore_test.dart`, and `local_owner_bootstrap_writer_test.dart`.
- Tests cover Guest → Account, successful update with pinned A
  authorization, A → B before submission, logout after callback, ordinary
  session rejection, active GPS, stale/expired callback, and network failure.
- Existing recovery form and callback tests verify input validation, the
  success state, and rejection after the recovery context changes.
- `dart analyze` on the changed runtime, recovery tests, callback UI tests, and
  Android probe: no issues found.
- The probe uses the installed GoTrue SDK's actual PKCE code exchange with the
  `passwordRecovery` verifier event, then the real owner service API. Its HTTP
  transport returns synthetic responses only.
- On Samsung A55 (`R5CX42V8GSJ`), a debug APK with application ID
  `com.example.driveit_project.isolated_test` completed the PKCE exchange and
  password update and showed `PASSWORD_UPDATED owner=A`. The APK identity was
  checked with `aapt` before installation. The production package
  `com.osaracx.driveit` and its data were not changed.
- No real user, PROD project, or email was used. This is synthetic Android
  integration evidence, not a real inbox/hosted account acceptance.
