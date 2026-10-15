# Phase 8 M2 — local deletion and lease delivery

Latest outcome: the approved forward fencing repair passed real Planet DEV
acceptance; see `phase8_m2_fencing_repair_acceptance.md`. Client activation is
still disabled. This local report and the first-deploy report are historical.

Historical local delivery report. Subsequent approved remote deployment and its
**partial / blocked fencing acceptance** are recorded in
`phase8_m2_planet_dev_deployment.md`. Statements below that remote deployment
has not occurred describe the earlier local-delivery checkpoint only.

Date: 2026-10-15. Branch: `feature/gps-refactor`, base HEAD
`481607ddcb63b5374e247434d6e4654120b05c48`.

## Boundary and outcome

M2 source integration is implemented and tested locally. **Remote M2 deployment
and normal-app M2 activation have NOT happened.** No A55 command, APK build,
real-user deletion, remote request, PAT use, commit or push was performed.
Existing dirty M1/manual-sync and Phase 7 work was preserved. The normal
production owner runtime retains its existing configuration; it was not
disabled or reactivated by this task.

The only proposed remote target is **Planet DEV `viqngnjfgknpxtoapzcg`**.
The separate Phase 8 project is not a deployment target.

## Client and normal UI

- `owner_drive_sync_client.dart`: durable M2 queue in the same scoped Hive
  store (`owner_sync_deletions_v2`). `drive:<localId>` intents and
  `source:<immutableUuid>` anti-resurrection barriers have distinct namespaces.
  Local keys are not authority and cannot delete another source after ID reuse.
- A fresh deletion UUID and actual UTC consent timestamp are persisted before
  network access. A source must be proven and account-owned. A never-attempted
  local outbox entry is not proof of a cloud copy: ordinary local deletion is
  preserved for those drives. Ambiguous attempted uploads are protected.
- M1 ACKs do not contain a causal sequence. `observe` retrieves the actual
  manifest sequence, and its fingerprint must match the durable local upload
  or source-ID mapping. Missing evidence is not synthesized. Offline consent
  can remain queued before this observation succeeds.
- The exact mutation is flushed before sending. Lost ACK retries use the same
  deletion ID, timestamp, revision, canonical hash and idempotency key. A
  conflict is retained, not silently converted to success.
- History displays the explicit warning: “Bu sürüş hesabınızdan ve senkronize
  cihazlarınızdan silinecek.” Cancel sends nothing. Until server confirmation,
  the local drive remains and pending status is shown, including after reopen.
  The upload button is disabled for pending deletion.
- Startup/resume retry only previously consented M2 intents, at most four per
  event, stopping at the first transport failure. There is no polling loop,
  bulk uploader or new background service. Owner epoch guards reject late
  results without writing into the next account.
- A validated tombstone writes a durable source barrier before removing the
  matching History/telemetry/Score copy. It does not remove World/Career
  contributions or their independent source snapshot. Unprojected M1 replica
  imports can be deleted without inventing M3 contributions; active World
  evidence is not bypassed. Source-to-local ID mapping prevents removal of an
  unrelated colliding drive. Older pages cannot re-create a source once its
  tombstone has been observed locally.
- Other devices apply deletion on their **next explicit download**. This is
  causal convergence, not immediate Realtime/background synchronization.
- Guest and Device Archive never enter M2. The existing legacy tombstone API
  still fails closed for historical records without causal evidence.

## Lease/fencing

- Server lease key: authenticated UID + immutable source UUID, with device UUID,
  actual journal session ID, monotonic fencing token, server heartbeat and
  three-minute expiry. Another device cannot steal a live lease; acquisition
  after expiry increments the token. An expired heartbeat cannot revive it.
- `OwnerDriveLeaseHeartbeat` renews every 30 seconds with no overlapping calls,
  stops on owner revocation/failure and exposes an error without touching GPS.
- The existing owner-bound GPS bridge has an M2-gated, non-blocking lease hook.
  It stores only device/session binding, not extra coordinates. Local recording
  does not wait for the network. Save and owner invalidation stop the heartbeat.
  Explicit upload reacquires from that durable binding and sends fencing
  claims through the existing finalizer. Process loss expires the server lease;
  it does not erase the journal or silently grant an old token.
- Physical Android background heartbeat/recovery has **not** been accepted in
  this task. Timer behavior is host-tested; server expiry/fencing is tested
  against real local PostgreSQL and Edge. No new Android FGS was introduced.
- Both `cloudDeletionEnabled` and adapter `deletionEnabled` are explicitly
  **false in ProductionOwnerRuntimeFactory**. There is no build flag that
  silently enables normal-app M2. Existing manual M1 upload/download remains.

## Server candidate and invariants

New migration: `202610160001_phase8_m2_deletion_fencing.sql`.
Neither applied M1 file was edited. Their SHA-256 values remain:

- `202610120001`: `BF7AEAB76A39D075876C0C4CE02546782EBEB2F8374C0D521CD36977F8BFFD11`
- `202610150001`: `B1BAF05304E01ABA3D0E04654ED266B5130D2A8C14BB712C59237B591BD61F1C`

The additive M2 candidate creates two private, RLS-enabled, client-inaccessible
tables (`phase8_drive_tombstones`, `phase8_drive_leases`), service-only RPCs and
forward wrappers around M1 begin/finalize/snapshot. Retired M1 internals have
EXECUTE revoked from service_role as well as clients; wrappers execute as the
pinned definer with empty search_path. Auth UID is verified by Edge, never
accepted as caller authority. Source locks order begin/finalize/delete/lease;
the same transaction allocates the owner sequence and immutable tombstone.

Tombstones dominate all older uploads indefinitely. Both begin retry and
finalize ACK replay pass the deletion barrier. Snapshot positions/high-water
remain ordered; a source deleted after snapshot creation is redacted into its
tombstone even at its earlier position. This privacy redaction may reveal a
later deletion earlier, but never advances a cursor beyond the returned page.
The actual delete event remains in the ordered feed and replay is idempotent.

This is **logical account History deletion**, not physical erasure of every
Storage byte. Immutable private manifests/objects and independent World/Career
evidence remain retained; normal authenticated download cannot expose a deleted
source. M1 orphan cleanup does not garbage-collect finalized content or the
anti-resurrection identity. A retention/physical-erasure policy is not added.

Existing installed M1 clients retain their exact capability response. M2 is
negotiated explicitly with `milestone: 2`. Old M1 clients cannot apply a deletion
event and must fail closed rather than re-create it. Update supported syncing
clients before enabling real deletion; do not claim old binary compatibility
with the new event kind.

## Actual local validation

Used existing Docker Engine 29.8.2, Supabase CLI 2.120.0, Deno 2.9.6 and the
existing `supabase/phase8-dev` workspace/container. Docker access required the
outside-sandbox tool permission. No new stack, reset, volume deletion or root
Planet `.temp` use. M2 was applied to this local database only, then its accepted
source was recorded in the local migration history alongside the two M1 versions.

- M2 PostgreSQL pgTAP: **34/34**, including actual authenticated/anonymous
  permission-denied queries, cross-owner deletion rejection, immutable
  tombstones, replay, old snapshot redaction, old upload/finalize rejection,
  expiry, takeover, valid fenced finalization and stale finalized-ACK fencing.
- Existing M1 PostgreSQL pgTAP: **45/45**. The grant assertion distinguishes
  deliberately retired internal M1 RPCs from callable server wrappers.
- Existing Edge integration test extended locally: **1/1 passed** against real
  GoTrue/PostgreSQL/private Storage/Edge, not a mock. It covers M1 plus observe,
  Auth A/B and anonymous deletion denial, finalize/ACK replay, anti-resurrection,
  tombstone download and real lease/heartbeat rejection. Its remote branch
  returns before the new M2 deletion tests: it cannot accidentally run these
  against Planet DEV through an old M1 remote command.
- Canonical Deno tests: **2/2**. Five changed/new Edge entrypoints type-check.
- Flutter frozen targeted sync/adapter/causality suites: **40/40**. Includes real
  History widget confirmation/cancel/pending display, bounded resume retry,
  reopened local queue, lost ACK, source/local-ID collisions, stale owner result,
  replica deletion/replayed old upsert, default-disabled adapter and heartbeat.
- Frozen full `flutter test --timeout=2m`: **989 passed, 2 conditional skips**,
  no failures (1m52s). Skips are the explicit isolated-Android build define
  requirement and unavailable Windows synthetic-symlink capability. Neither
  is counted as a successful physical acceptance.
- Frozen `flutter analyze`: **0 errors, 0 new warnings/info**; exit 1 because
  the existing 3 integration-test unnecessary-null warnings remain, alongside
  4 existing infos (Home interpolation, Map WillPopScope/interpolation,
  RoutePreview withOpacity). These unrelated files were not changed to hide
  baseline findings. `git diff --check` passed; staging is empty.

Evidence logs (Git-ignored): `.buildlog/m2_pgtap.log`,
`.buildlog/m2_m1_pgtap.log`, `.buildlog/m2_edge_test.log`,
`.buildlog/m2_targeted_frozen.log`, `.buildlog/m2_flutter_frozen.log`,
`.buildlog/m2_analyze_frozen.log`. The temporary Edge serving command started
for this acceptance was stopped after the tests; local database/volumes remain.

An intermediate full run was invalidated by source edits during lazy test
loading; it was stopped and not used as final acceptance. Final evidence must
come from the frozen-source run, not that mixed run.

## Exact remote scope requiring user approval

Before any remote write: verify Planet DEV ref, migration/catalog compatibility,
current M1/Planet/Auth fingerprints and restorable backup. Do not replay M1
migrations or use the M1 deployment script as an unreviewed M2 deploy command.

Proposed bounded order after approval:

M2 migration SHA-256:
`B7817BBDE7307E293237F0C61113DDF693AEA19C72B719B616FA586B6692B1D4`.

1. Deploy the backward-compatible `phase8-drive-begin` capability handler first.
2. Apply **only** `202610160001_phase8_m2_deletion_fencing.sql` after exact
   schema/history checks; preserve all M1/Planet/Auth data and existing policies.
3. Update `phase8-drive-finalize` and `phase8-drive-download`; verify barriers.
4. Deploy new JWT-verified `phase8-drive-delete` and `phase8-drive-lease`.
   No new bucket, cleanup secret, cleanup function or M3/M4 object is required.
5. Run synthetic-only remote M1/M2 acceptance and source-bound cleanup. Never
   select the user's A55 drive as a deletion fixture.
6. Only after remote acceptance, separately approve normal-client activation,
   release build/update and manual rollout. Account sync remains manual-only.

On failure stop M2 activation and preserve queues, tombstones and source data.
Once a deletion exists, rolling back to an old unfiltered download function or
dropping tombstones is unsafe. Use a forward repair, not a resurrection rollback.

## Remaining acceptance

Remote M2 is **NOT DEPLOYED/NOT ACCEPTED**. Normal APK M2 is **OFF** and no APK
was produced or installed. Real two-device delete convergence and Android
background lease behavior remain unverified. M3/M4 were not developed or enabled.
The user's uploaded real drive was not queried or changed.
