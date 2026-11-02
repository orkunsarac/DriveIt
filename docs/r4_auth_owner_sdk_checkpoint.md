# R4 Auth/owner SDK checkpoint

Status: BLOCKED / not end-to-end accepted. Play Auth remains hard-closed. No hosted activation or Android signing changes.

For explicitly coordinated account login/signup/logout, the existing owner lifecycle now revokes the active lease after the GPS quiescence check and before invoking the SDK. It reconciles the owner after the action, including failure; prior records are not moved or deleted. The deletion authorization path retains its existing lease semantics. A real SDK synthetic HTTP test checks the old lease is already invalid at the SDK synchronous account-switch event. The existing scoped gateways still pin credentials and reject late results. A server request already sent before revocation cannot be recalled.

The Play SDK configuration is now fail-closed: automatic URI handling, SDK session persistence/restore and automatic token refresh are disabled, while PKCE remains selected. This does not implement controlled link delivery or persistence; Play Auth remains unavailable.

SDK source reviewed: supabase_flutter 2.17.2 `lib/src/supabase_auth.dart` initializes the link observer only for `detectSessionInUri` and invokes `getSessionFromUrl`; `lib/src/supabase.dart` starts `recoverSession` asynchronously after initialization. gotrue 2.27.2 `lib/src/gotrue_client.dart` saves a session before notifying subscribers in sign-in and URL exchange; `recoverSession` restores a valid serialized session and may refresh an expired one if auto refresh is enabled; token refresh also saves the resulting session. The SDK provides switches to disable automatic behavior; the remaining integration is not claimed to be an unsupported SDK API.

Verification: targeted suite after changes: 51 PASS including actual SDK with synthetic responses, owner/GPS cases and deletion; a separate pre-final suite was 64 PASS. No real hosted, email or physical-device acceptance.

Remaining required work: cold/warm link delivery and one-time PKCE exchange through the GPS/owner fence, safe persisted session restore, explicit same-owner token refresh, recovery credential binding and its UI/session context, process restart/replay and full SDK + isolated service races. These are unimplemented or unproven; do not enable the Play Auth gate. Separate device and real email acceptance remains necessary after technical completion.
