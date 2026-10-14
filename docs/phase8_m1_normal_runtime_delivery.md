# Phase 8 M1: normal runtime connection and local backend acceptance

Date: 2026-10-15. No remote project was queried or modified in this delivery.

## Working mobile checkpoint

`f7d0e243a22a3f60316bdf904808ab1230168bb1` preserves the normal owner
factory, real Planet DEV Auth/Profile, persistent Guest and read-only device
archive. It was pushed to `feature/gps-refactor` and remote HEAD matched.
The baseline full Flutter suite passed 970 tests with two conditional skips.
Archive list/detail/route and lock revocation are user-reported A55 acceptance,
not new instrumentation results. No Android tests were run in this delivery.

## Auth/backend decision requiring operational approval

The current normal app authenticates with Planet DEV
`viqngnjfgknpxtoapzcg`. M1 tables reference the backend project's
`auth.users(id)`; Edge authenticates through that project's
`admin.auth.getUser(bearer)`. Storage authorizes the verified `auth.uid()`.
A Planet JWT/UID cannot simply be passed to the separate
`jidyfemjzztlwjmijndx` project as if it had a matching Auth session.

Recommended normal-app deployment: keep the existing Auth identities and add
the namespaced M1 backend to the SAME Planet DEV project, after explicit user
approval and remote read-only schema/history comparison. Do not move users,
copy signing secrets, relabel local owners, or touch accepted Planet records.
The separate Phase 8 DEV project remains available as a separate test project;
its users/tokens are never interchangeable with Planet users/tokens.

Keeping the real backend in the separate project would instead require an
approved external-identity trust setup, external principal/FK changes, and
Storage/Realtime authorization changes. That is not the current M1 contract
and has not been silently implemented. Supabase documents supported JWT trust
mechanisms at https://supabase.com/docs/guides/auth/jwts .

## M1 source changes

- The real production dependency factory can supply
  `SupabaseOwnerDriveSyncAdapter` to the existing owner lifecycle. It uses the
  same real Auth client and checks the exact approved Auth project. It never
  constructs a Guest/fake cloud identity.
- `DRIVEIT_ACCOUNT_SYNC_ENABLED` defaults to false; the normal Auth release
  helper does NOT enable it. No real cloud worker is activated in the APK.
  An enabled candidate must verify the authenticated backend capability
  response (contract 2, revision `202610150001`, exact owner scope) before
  uploading outbox data. A missing/wrong backend fails closed.
- Reconciliation stays under the existing local owner operation barrier.
  HTTP/Storage upload and page fetch run outside it, so a delayed cloud
  response cannot block local Save or account revocation. A prefetched page
  is applied under the barrier after rechecking owner/epoch/durable cursor.
  Each lifecycle pass processes at most four uploads and one download page;
  later startup/resume/Save events retry. No polling service was added.
- Requests have a 30-second transport timeout. Lost responses leave retryable
  outbox state; existing source identity/fingerprint/idempotency is preserved.
- Server payload validation rejects missing restore-critical date, route,
  metrics, telemetry and provenance fields instead of filling defaults.
  This proves serialization/hash/owner binding, not independent GPS truth or
  server-side recomputation of Score/World/Planet eligibility.
- Completed or expired snapshots can renew from the exact committed sequence.
  The old snapshot must belong to the verified caller, and the response binds
  the replacement to the exact prior cursor. New drives are no longer hidden
  indefinitely behind an already-completed high-water mark.
- `202610150001_phase8_m1_forward_repair.sql` explicitly reinstalls the reviewed
  RPC bodies/grants and advertises capabilities. The original
  `202610120001_phase8_drive_sync.sql` was not edited in this delivery. Concurrent
  same-key begin retries serialize before inserting an intent. No rows,
  containers or volumes were reset/deleted.
- Edge's Supabase JS dependency is pinned to the locally tested `2.117.2`.

## Actual local validation

Existing isolated stack: `supabase/phase8-dev/supabase`; Docker Engine 29.8.2,
Supabase CLI 2.120.0, Deno 2.5.6, Edge runtime 1.77.4 (Deno 2.1.4 compatible).
Commands used only the Phase 8 local workspace and localhost. Root
`supabase/.temp` was not used.

- Both numbered migrations are recorded in the local DB. The forward repair
  was applied with `db push --local`. Existing PostgreSQL/pgTAP: **45/45**.
- Four Edge entries and the integration test pass Deno type-check.
- Canonical JSON/SHA-256: **2/2** Deno tests.
- Existing real local Edge/Storage E2E: **1/1**. Synthetic A/B users sign in,
  A stages/finalizes/downloads, B and anon are denied, same bytes replay the
  durable ACK, different hash conflicts, partial/missing/bad objects stay
  invisible, cursor pages/renewal/expiry recover, cleanup rejects a wrong token
  and preserves finalized objects. Test HTTP bodies are consumed; Deno's
  resource sanitizer remains enabled. These are real LOCAL server results,
  not remote or physical two-device acceptance.
- Targeted Flutter client/adapter/lifecycle/navigation suites: **52/52** before
  adding the transport-timeout regression. Final full Flutter: **975 passed,
  two conditional skips** (isolated Android define and Windows symlink).
- Analyze has the existing three archive-instrumentation null-assertion
  warnings and four info notices. No new analyzer finding was introduced.
- `git diff --check` passes.

Synthetic local Auth/Storage test resources remain in the existing stack.
No real account, user route or phone data was used.

## M2, M3, M4 status and normal UI

M2 remains local evidence/causal/lease models plus host tests. Durable server
tombstones, causal feed application, lease acquisition/heartbeat/fencing and
their normal delete/start integration are NOT implemented or accepted.
Deletion sync is disabled. Keep the 30-second / 3-minute lease contract.

M3's source-based World v6/Career projection host tests remain valid; they are
not a remote projection event protocol. Downloaded M1 History/telemetry/Score
does not imply cross-device World/Career projection. Normal owner navigation
now opens the existing World choice screen with owner-scoped My World and the
real existing Planet map entry. Planet map reads still depend on its existing
RPCs; no remote availability was assumed. Owner segment publication still
prepares a local queue only and says so. No automatic public publication,
legacy whole-drive fallback, or Planet table mutation was added.

M4 still needs server-authoritative membership/invite/expiry/roles and the
real adapter. The normal app does not inject the fake group service. Private
channel generation rotation and per-publish revocation must be implemented
and tested with already-connected revoked members before live sharing.
Independent Android group-only background FGS remains a separate open item.

## Exact remote approval boundary

No remote deployment is performed. Proposed normal target:
`viqngnjfgknpxtoapzcg`, preserving its existing Auth and Planet data.
After approval, compare remote history/objects first, then apply ONLY:

1. `202610120001_phase8_drive_sync.sql` and
   `202610150001_phase8_m1_forward_repair.sql`, through a versioned workflow
   preserving all pre-existing Planet migration history.
2. Private `phase8-drive-staging` bucket: 10 MiB, JSON only, matching narrow
   staging insert policy. No public/list/update/delete grant.
3. `phase8-drive-begin`, `phase8-drive-finalize`,
   `phase8-drive-download`, `phase8-drive-cleanup`.
4. A server-only cleanup secret, before deploying/enabling cleanup. No client
   secret or signing key is added to Flutter.
5. Approved synthetic remote account smoke tests before a cloud-enabled
   normal APK. Do not claim M1 remote acceptance from local results.

The old `tool/deploy_phase8_m1.ps1` is deliberately NOT retargeted to Planet.
It pins the old single-migration bundle and the separate Phase 8 project.
Its source/hash checks reject this revised bundle. Do not run its `-Apply`
or reuse its former 30/30 self-test result as current deploy approval.
Retargeting requires the user's project decision and a reviewed source manifest.
On any schema/history collision, stop without repair/reset/fallback.
