# DriveIt Phase 8 backend contract and implementation boundary

2026-10-15 update: the normal app now has real Planet DEV Auth. The newer
`phase8_m1_normal_runtime_delivery.md` records local M1 server acceptance,
the forward correction migration, the guarded normal factory connection and
the pending same-Auth-project deployment decision. Earlier statements below
that tools are absent or the normal owner runtime is unavailable are historical.
No cross-project JWT trust or remote deployment is implied. The four milestone
boundaries and privacy/causality rules below remain in force.

Status: client staging contract implemented locally. The user has created a
separate Phase 8 DEV project; local backend candidate files are prepared, but
no remote project has been queried or changed, no migration has been applied,
and no real Supabase adapter is enabled. The existing Planet DEV
project/schema/data are out of scope.

## Project and rollout boundary

- Phase 8 requires a separate Supabase DEV project. It must not reuse the
  current Planet DEV project because its Planet data and project-wide Realtime
  settings are not disposable.
- Host tests and isolated local/fake stores may advance while physical devices
  are unavailable. Two real accounts/devices are a milestone acceptance gate,
  not a prerequisite to continue independent implementation work.
- The production ownership gate stays off. No release composition receives a
  network adapter from this change. Legacy/device-archive rows are not eligible
  for automatic sync.
- Provisioning a project, creating test accounts, applying migrations,
  configuring Storage/Realtime, and deploying functions require a separate
  explicit operational approval.

## Drive upload: staged Storage plus transactional PostgreSQL finalization

PostgreSQL and Storage do not share an atomic transaction. Therefore a drive
must not be made downloadable merely because an object upload succeeded.

1. A finalized account-owned local drive is represented by the existing
   immutable `OwnerSyncMutation`, with proven source UUID, owner scope,
   stable idempotency key, and payload fingerprint. Legacy, guest, deleted,
   incomplete, or unproven drives remain ineligible.
2. Client canonical envelope encoding is sync contract v2: JSON object keys
   are sorted by UTF-16 code-unit order recursively, array order is retained,
   finite numbers use ECMAScript shortest-decimal/JCS exponent thresholds,
   integers outside the interoperable IEEE-754 safe range and non-string
   object keys are rejected. Existing persisted v1 outbox rows
   retain their original hash/key validation and remain readable; new enqueue
   operations use v2. The staged envelope is capped at 10 MiB. This cap must be
   validated against the synthetic two-hour / 8,000-point fixture before any
   rollout. The Edge implementation must pass the same cross-language
   canonical JSON vectors before v2 is accepted remotely.
3. An authenticated begin-upload operation binds `auth.uid()` to the owner,
   idempotency key, source UUID, contract version, semantic payload fingerprint,
   canonical object SHA-256, and byte count. The key is unique per authenticated
   owner/source/operation. Same key + same claims returns the same live intent
   or finalized receipt; different claims return a conflict. Client owner IDs
   are assertions only.
4. The object is uploaded to a private, non-listable staging prefix scoped to
   owner and intent. It is not inserted into the drive manifest or owner change
   feed. Bucket policies do not allow clients to write final paths or read
   another owner's staging object.
5. An authenticated finalization function verifies the caller, loads the
   exact intent/object, checks byte count and SHA-256, parses the envelope,
   validates schema/provenance/owner/idempotency and recomputes the canonical
   payload fingerprint. It then invokes a narrow database finalizer.
6. One PostgreSQL transaction locks the owner sequence row, checks the unique
   idempotency reservation and payload fingerprint, writes the immutable drive
   manifest, appends one ordered owner change row, marks the intent finalized,
   and stores the exact ACK receipt. Same replay returns that receipt; changed
   bytes/claims conflict. The service-role key remains only in Edge Function
   secrets and is never returned to the client.
7. If upload/finalize response is ambiguous, client retries the same canonical
   bytes/key and first queries/replays the durable intent. A finalized intent
   returns its original receipt without another change row. Local ACK is only
   persisted after owner/key/fingerprint receipt checks and local read-back.
8. Orphan cleanup is not a blind Storage bucket sweep. After seven days without
   activity, a DB transaction marks an unfinalized intent `cleanup_pending`
   while holding its row lock. A cleanup worker deletes only the exact private
   object path for that intent, then marks it `expired`. Delete failure remains
   retryable. Finalized intents/manifests are never garbage-collected by this
   worker. The tiny intent/idempotency tombstone remains to prevent a stale
   retry from resurrecting or silently replacing content.

The local client now has `OwnerSyncStagedUploadAdapter`, `sendStaged`, a
bounded `runStagedOnce`, and a synthetic staged remote test. It exercises
private staging, checksum verification, DB-finalization response loss, replay,
and one durable ACK. This is not an HTTP/Supabase adapter and is not wired into
production `LocalOwnerLifecycle`.

## Snapshot and change-feed contract

- Each owner has a monotonically increasing change sequence. Finalization
  allocates it under the same transaction/owner lock as the manifest change.
- `begin_snapshot` returns an opaque owner-bound cursor and committed high
  water mark. A page is bounded by that watermark, ordered by sequence, and
  returns `from`, `next`, and `high_water`. A later page cannot observe a row
  inserted behind its cursor or skip an uncommitted lower sequence.
- Every page is authorized from the current JWT and validated in full before
  local writes. Cursor values from a different UID are rejected. The local
  cursor moves only after every row is durably written, read back, and marked
  complete. Replaying a page is idempotent.
- If a server-side snapshot cannot be held indefinitely, the server must
  materialize a bounded snapshot/change watermark; clients must never invent
  or advance a cursor based on wall-clock time.

## Delete and active-drive lease contract

- Delete sync remains disabled until a tombstone contains deletion operation
  UUID, account UID, proven source identity, UTC deletion time, observed remote
  revision/change sequence, and a causal version. A minimal durable server
  tombstone dominates older uploads indefinitely; content may be removed after
  all supported retention rules, but its anti-resurrection identity cannot be
  dropped while stale devices can reconnect.
- Existing local deletion evidence is insufficient and must fail closed. No
  guessed timestamp/identity and no legacy auto-tombstones.
- A lease binds UID, device ID, session/source UUID, monotonic fencing token,
  heartbeat and expiry. Initial policy: heartbeat every 30 seconds, expiry
  after 3 minutes. Server rejects stale fencing tokens at finalization. Offline
  local GPS recording continues; reconnect reports a conflict and retains both
  records for explicit resolution rather than dropping one.

## World, Career, and Planet compatibility

- Cross-device World/Career projection accepts only newly proven source UUIDs
  and versioned contribution/source events. Career contribution unique keys
  include owner and source identity. Existing World v6 geometry/overlap rules
  remain local domain behavior; legacy cumulative Career and unproven World
  traces are not uploaded or merged.
- History delete does not cascade to World/Career. Their independent delete
  events need separate evidence and identity.
- Existing `world_publishes` whole-drive Planet API and accepted public records
  remain unchanged. Private drive backup is not Planet publication. A
  segmented submission must never fall through to the legacy whole-drive
  endpoint. No Planet data or current Planet DEV schema is changed here.

## Group membership and Realtime revocation

- Server transactions own invite rotation, membership, bans, role transfer,
  capacity (10), expiry (12 hours plus at most two 6-hour extensions), and
  one-active-group-per-user. Client-provided role/owner is never authority.
- Group broadcasts use a private topic containing a server-controlled group
  generation. Every membership removal, ban, share pause/stop, owner revocation,
  group end, or expiry increments that generation. New authorized members
  receive only the new topic; revoked clients cannot join it.
- Supabase Realtime authorization at channel join is not enough: an already
  joined channel may retain its join authorization until token refresh/expiry.
  The server therefore accepts each point only through a narrow authenticated
  publish RPC/function that rechecks current membership, consent, owner epoch,
  active status, and generation. Direct client broadcast is denied. Receivers
  reject old generations, unsubscribe on revocation events, and perform a
  bounded membership refresh at most every five seconds while the map is open.
- Coordinates are transient Broadcast only: never Postgres rows, Presence
  payloads, logs, or replayable history. Each point includes generation and
  timestamp and expires after 15 seconds. Pause/leave/ban/end clears latest
  in-memory marker state. Reconnect sends only a fresh point, never a backlog.
- The independent Android background group-location FGS is a separate open
  Android acceptance item. It is not pulled into this backend workstream.

## Four delivery milestones and gates

1. **Account drive sync (first vertical):** staged upload/finalize and stable
   owner change feed; same account downloads on another store; B is denied.
   Host tests can progress without devices. Completion additionally requires
   two real accounts/devices against the separate DEV project. Stop if any
   payload is visible before finalization, any cross-owner read/write succeeds,
   or idempotency creates a second manifest/change row.
2. **Deletion and active-drive lease:** proven-only tombstones and fenced
   lease/heartbeat; offline recording is retained. Host race/replay tests and
   then virtual-device tests precede physical acceptance. Stop on resurrection,
   lost offline session, or stale fencing acceptance.
3. **Private World/Career projection:** versioned proven-source events and
   exactly-once career contributions; History/World/Career deletion remain
   independent. Legacy stays excluded. Stop on a duplicate contribution,
   cross-owner projection, or mutation of accepted Planet records.
4. **Group server and Realtime:** server-authoritative membership plus
   generation-rotated private Broadcast and immediate revocation semantics.
   Local fake tests and virtual clients proceed independently; physical
   two-device acceptance is required before claiming live sharing. Stop if an
   already-connected revoked member can publish/read fresh coordinates.

Physical A55 release acceptance for Phase 5 and the separate group background
FGS acceptance remain explicit rollout blockers for the capabilities they
cover; neither blocks host implementation of independent Phase 8 milestones.

## Environment status / not yet performed

At implementation time, Supabase CLI and Docker are unavailable in this
workspace, and no separate Phase 8 DEV project credentials/configuration were
provided. Therefore migrations, Edge Functions, RLS/Storage policies, and
Realtime settings have not been deployed or represented as tested. The
current Planet DEV project has not been contacted or modified. Provision the
separate isolated project and its disposable test accounts before remote
integration acceptance.

## Autonomous local client progress (2026-10-13)

- Added an explicit `SupabaseOwnerDriveSyncAdapter` for the existing staged
  upload and snapshot-download interfaces. It checks the fixed owner against
  the current Supabase Auth UID and owner lease before and after I/O. It is
  not wired into production bootstrap, the ownership gate remains off, and no
  credentials are embedded in source or build configuration.
- Storage uploads use the deterministic private owner/intent path, an
  `application/json` file part, and `upsert=false`. An immutable-object
  duplicate does not overwrite data; the client asks the server finalizer to
  re-verify its hash/size. This handles the process-crash window after Storage
  accepted an object but before the client persisted its upload marker.
- The host `MockClient` suite covers authenticated-owner rejection, begin and
  finalize payloads/receipts, exact private staging path, non-upsert behavior,
  duplicate-object retry, snapshot cursor validation, stale-owner response
  rejection, and a staged upload followed by same-owner replica download. A
  local drive-ID collision with different proven provenance is rejected
  without replacing the local drive or advancing its cursor. These are mock
  transport tests, not RLS or live Supabase acceptance.
- PostgreSQL/RLS/Storage/Edge integration tests were not run in this session:
  the Docker CLI is present, but Docker Desktop's daemon reported that it was
  unable to start; no Supabase CLI or Deno executable is available in PATH.
  No local stack was started and no migration was applied.
- Remote read-only preflight remains **WAITING — PAT REQUIRED**. The pending
  local PowerShell prompt was cancelled with Ctrl+C while no PAT had been
  entered. No Management API request, remote write, or deploy was performed.
  The prior user-supplied Project Ref is `jidyfemjzztlwjmijndx`; it has not been
  re-queried in this session. The existing Planet project and root
  `supabase/.temp` link were not accessed.
- Before remote M1 deployment, the user must run the isolated preflight/deploy
  workflow from their own PowerShell session with an appropriately scoped
  temporary PAT, review the exact target/migration/source fingerprints, and
  separately approve the actual `-Apply` write. Disposable Auth test accounts
  and remote smoke-test approval are also still required.

## Autonomous local completion update (2026-10-13)

- The download importer persists a per-owner mapping from immutable
  `sourceIdentity` to local drive ID. It preserves the remote drive ID when
  free and uses deterministic `sync_<sourceIdentity>` only when an unrelated
  local record already occupies that ID. It remaps Drive, telemetry, and Score
  references together; derived World roads remain excluded. The original
  remote ID is retained and restored when the proven source is re-enqueued, so
  a second device computes the same canonical hash and idempotency key.
- The importer writes and reads back that mapping before applying drive data.
  A test injects a telemetry flush failure, closes/reopens the owner store, and
  completes the same snapshot import without duplicate data or cursor advance
  before completion. An explicit local History deletion suppresses replay on
  that device; this does not create or upload a server tombstone.
- Enqueue/reconciliation now build the eligible payload from the owner-scoped
  Drive, telemetry, provenance, and current Score records. They no longer
  depend on the optional World source snapshot being ready. This does not run
  World processing or change World/Score algorithms.
- The SQL and Edge download paths now fail closed if a snapshot claims a
  higher committed sequence but returns no page progress. The PostgreSQL
  candidate has a pgTAP regression for this gap; it has not been executed
  because the local Docker daemon is unavailable.
- `owner_sync_causality.dart` adds isolated value validation for the future
  M2 deletion-evidence and lease/fencing contract. It is not wired to GPS,
  delete UI, outbox, or remote calls. Its host suite checks explicit causal
  evidence, idempotent equality, expiry, and stale fencing tokens.
- M3/M4 remain contract-only here. Existing owner-scoped Career/World and
  fake group-generation tests are useful host foundations, but no cross-device
  World/Career server projection or live Realtime revocation has been built
  or accepted. Do not infer either from those local tests.
- Targeted host suites pass: 25/25 owner sync, adapter, and causality tests;
  the synthetic two-device finalization/retry/download flow passes as well.
  Full `flutter test --timeout=2m`: 965 passed, 2 conditional skips, no failures
  after correcting the non-collision local-ID mapping. `flutter analyze` reports
  the pre-existing 4 info notices, and `git diff --check` passes. Docker daemon
  access failed with a local named-pipe permission denial; pinned Supabase CLI
  2.120.0 was not cached for offline `npx`, and Deno is not installed. No local
  PostgreSQL, RLS, Storage, or Edge runtime acceptance ran. Remote Phase 8 DEV
  preflight remains **WAITING — PAT REQUIRED**; there were no remote calls.

## Local M1 acceptance correction (2026-10-14)

- The earlier environment note above is superseded for this date: Docker
  Desktop/Engine and the isolated `supabase/phase8-dev` stack were available.
  The current Phase 8 migration source passed **45/45 pgTAP assertions** after
  its SQL functions were reapplied to the local database. This is local
  PostgreSQL/RLS evidence only.
- Migration version `202610120001` was already present in local migration
  history while several stored function bodies still differed from the
  current source file. The migration runner records versions, not source
  hashes; editing an already-recorded migration therefore did not update those
  bodies by itself. The idempotent source was reapplied locally without reset
  or volume deletion. Before any remote deployment, compare actual remote
  objects as well as migration versions. If the remote has already applied an
  older body, deliver the correction in a new additive migration; do not rely
  on replaying the same recorded version.
- The first local Edge attempt reached GoTrue and returned `403 bad_jwt` for
  synthetic admin-user creation. Supabase CLI 2.120 local `ANON_KEY` and
  `SERVICE_ROLE_KEY` are opaque API keys, not JWT bearer credentials. The test
  client was narrowly adjusted to keep the API key in `apikey` and use a
  separate short-lived, locally signed role JWT in `Authorization`. No key or
  JWT value is recorded here.
- One targeted retry was attempted, but produced no Deno test result and no
  new GoTrue request or synthetic test accounts; it is **not a pass**. The
  Edge/Storage end-to-end flow remains unverified. No remote calls or writes
  occurred. The Edge runtime started for that attempt was stopped afterwards;
  containers and volumes were preserved.
- `flutter test --timeout=2m`: **968 passed, 2 conditional skips**. Analyze
  reported 3 unnecessary-null-assertion warnings in unrun Android integration
  files and 4 informational notices. These warnings do not affect the normal
  production composition but remain recorded; the integration files were not
  included in the local code checkpoint.
