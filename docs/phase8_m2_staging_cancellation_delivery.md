# M2 staging-only cancellation — local delivery, remote approval pending

Follow-up: the separately approved hosted deployment and synthetic acceptance
are complete; see `phase8_m2_staging_cancellation_planet_dev_acceptance.md`.
The remainder records the preceding local-only delivery, not current server
status. The phone's pending real deletion remains untouched.

Date: 2026-10-15. Base HEAD `79fa6ed0d798f91bde30dccca238f15c14108599`.
Only proposed remote target: Planet DEV `viqngnjfgknpxtoapzcg`.
**No remote migration/Edge write, APK build/install, real cancellation, commit
or push was performed.** Existing dirty Android/config and activation work is
preserved; `tatus` and `android/build/` were not modified.

## Implemented protocol

Candidate additive migration:
`supabase/phase8-dev/supabase/migrations/202610160003_phase8_m2_staging_cancellation.sql`
SHA-256 `6DA520A532EA3C849CF7E6C94EF5C65806F9F82F9E738A7F3913839AF0AD1871`.
Previously applied M1, M2 and fencing-repair sources remain unchanged.

- Private RLS table `phase8_drive_cancellations` binds owner, immutable source,
  actual staging intent, consent/deletion UUID, canonical mutation and actual
  server change sequence. It references an existing upload intent, NOT an
  invented manifest. An immutable trigger rejects update/delete. Clients have
  no direct access; service role has SELECT/INSERT only.
- New service-only SECURITY DEFINER RPC `phase8_cancel_staged_drive` has empty
  search_path. It acquires the exact existing per-source advisory lock, validates
  owner/intent/source/fingerprint/consent, atomically inserts cancellation,
  allocates the existing owner's next sequence and marks the intent expired.
  Matching retries return the SAME receipt/sequence; contradictory claims 409.
- `phase8_m2_lock` retains its signature/permissions and now rejects permanently
  cancelled sources with `PT409 source_cancelled`. Existing begin, fenced
  finalize, lease and delete RPCs already use that barrier. Old uploads and late
  finalizers cannot recreate the source, regardless of Storage object existence.
- If a real manifest already won the lock, cancel returns
  `409 source_already_finalized`; no cancellation row is created. Client refreshes
  actual manifest evidence once and sends the standard M2 tombstone with the
  SAME consent UUID/UTC. A lost cancellation ACK never triggers this transition:
  its retry obtains the existing cancellation receipt instead.
- Existing snapshot/page RPC merges cancellation rows and existing immutable
  change rows using the SAME owner sequence, snapshot high-water, page limit and
  contiguous-sequence validation. Existing manifest FK/change-table constraints
  remain intact. Normal tombstone redaction is retained. No cursor advances on
  incomplete/gapped pages.
- Wire kind remains `driveTombstone`, with a STRICT distinct payload variant:
  `causalVersion:2`, actual `intentId`, `cancelledPayloadFingerprint`, existing
  `deletionId` and UTC `deletedAt`. It has **no observedRemoteSequence** because
  no manifest was observed. Standard finalized-drive tombstones remain causal
  version 1. Canonical SHA-256, source/owner scope and deletion idempotency key
  checks apply to both. Unknown/incomplete variants fail closed.
- Existing delete Edge endpoint adds `observeStaging` and `cancelStaging`.
  UID comes only from verified Auth. Observation of finalized source => 409,
  unknown source => 404, invalid claim => 422, temporary DB failure => 503.
  Observation errors no longer masquerade as 404 absence. Receipt requires
  `ok`, positive sequence and the accepted immutable mutation.
- Existing begin/finalize Edge entrypoints return deterministic
  `409 source_cancelled`. Finalize checks cancellation before reading/validating
  an expired staging object; it also retains the DB barrier for the race window.
- Storage remains private. Expired intent revokes client object access, but
  finalized/cancelled private bytes are not physically deleted by cancellation.
  Late Storage writes cannot cross the permanent finalization barrier. No new
  physical retention purge or global orphan sweep is introduced.

## Flutter integration

The existing deletion outbox, not a new queue, persists the mutation before the
request. An optional extension of the existing adapter observes real staging
evidence ONLY after the ordinary manifest observation returns the specific
404 `source_unavailable`. A 404 alone never removes local data. Old backends
without the extension fail closed; no invented fallback receipt is accepted.

Offline/lost-ACK attempts remain retryable and preserve exact consent/mutation.
Only an identical validated server receipt applies the durable source barrier
and existing History deletion. World/Career evidence remains independent.
Pending upload rows are not arbitrarily cleared or rewritten. Both local stale
upload retry and later downloaded upserts are blocked by the source barrier.
UID/epoch checks run after network awaits; revoked-owner results never mutate
the next owner's store. Guest/Device Archive are excluded.

The existing lifecycle bounded retry additionally allows old consented
`conflict/source_unavailable` rows to try the new protocol. Other conflicts are
not automatically retried. No fresh consent is invented, no batch upload is
enabled, and no normal-app update has been installed here. The user's existing
pending row therefore remains untouched on the phone.

## Empty telemetry: evidence, not assumptions

Two existing failed staging envelopes were inspected READ-ONLY in process
memory, outputting only counters/validation booleans. Each has:

- frozen transfer metadata `finalSequence=0`;
- canonical telemetry points 0;
- route points 0;
- equal transfer/canonical counts and correct canonical SHA-256 bytes.

The production transfer reads every committed journal point without filtering,
requires journal length == final_sequence, and verifies exact canonical point
equality on Hive read-back. Existing nonempty transfer tests pass. This does
**not** indicate committed SQLite points were dropped during owner serialization.
No physical private journal was opened or data repaired.

Stationarity alone is NOT a proven explanation: existing pipeline tests accept
valid stationary GPS samples and suppress drift distance rather than erase all
samples. Provider callbacks, permission/accuracy quality or start/stop timing
before the first accepted point remain unproven causes of the initial zero
count. No speculative GPS/filter/foreground/journal change was made.

Earlier local fixes remain: empty telemetry is local-only, not upload eligible;
enqueue/reconciliation are blocked before attempting network upload. Existing
empty outbox records are preserved. No fake coordinate, score, timestamp or
telemetry is synthesized. Local save/History/Score-N/A behavior is unchanged.

## Actual local acceptance

- Cancellation pgTAP **22/22**: RLS/ACL, forged-owner denial, exact receipt
  replay, permanent immutable barrier, revoked staging access, no invented
  manifest, old begin/finalize/lease rejection, cursor and both serialized race
  orders (cancel first / finalize first).
- Existing M2 pgTAP **34/34**, M1 pgTAP **45/45** on the same local PostgreSQL.
- Existing REAL local GoTrue/Storage/Edge E2E **1/1**. Covers empty envelope
  finalize 422 -> staging observation -> accepted cancellation -> replay,
  retained private bytes/client access revocation, deterministic old retry
  rejection, cursor delivery, A/B/anonymous denial, AND concurrent
  `Promise.all(cancel,finalize)` with exactly one winner and never both records.
  Existing M1 upload/finalize/ACK/cursor and M2 fencing/tombstone tests also pass.
  This is localhost acceptance, NOT new remote Supabase acceptance.
- Existing targeted Flutter/GPS tests **80/80**: lost cancel ACK/reopen, race
  fallback with same consent, late ACK/epoch rejection, second local store
  cancellation -> old upsert suppression, A/B rejection, adapter wire contract,
  nonempty transfer preservation, stationary samples, existing M1/M2 tests.
- Affected Edge entrypoints and E2E source pass cached Deno type-check.
- Full Flutter regression: **997 passed, 2 conditional skips**. Four added
  brace-style infos were corrected; final analyze has only the previous
  **3 warnings + 4 infos**, exit 1 (not a clean analyze). None belongs to this
  cancellation change. `git diff --check` passes. Final source-only brace
  corrections do not change behavior; targeted tests are rechecked afterward.

## Exact remote approval requested

After a fresh read-only drift/backup check, apply ONLY the new
`202610160003_phase8_m2_staging_cancellation.sql`, then update only:

1. `phase8-drive-delete` (observation/cancel actions and precise errors)
2. `phase8-drive-begin` (deterministic cancellation error)
3. `phase8-drive-finalize` (early cancellation read + existing race barrier)

No bucket, secret, Auth/Planet data, lease Edge or download Edge deployment is
needed. Download's existing tombstone envelope forwarding works with the new
page RPC. No M3/M4 or unrelated migration is selected. Test new behavior remotely
only with separately authorized synthetic fixtures, not the pending real drive.
The existing remote M2 test mode deliberately returns before local candidate
cancellation tests; it must not be presented as cancellation remote acceptance.

Risks/rollout: old clients reject unknown causal version 2, so upgrade supported
clients before real cancellation. Finalize now requires the cancellation table:
deploy migration BEFORE the three Edge updates. Preserve cancellation rows and
merged snapshot handling after first receipt; do not roll back to a downloader
that forgets the cancellation sequence, or drop barriers to "repair" history.
Keep physical content retained until an independently approved retention policy.

After remote synthetic acceptance and a separately approved normal APK update,
the existing real consent can retry (bounded lifecycle or explicit user retry).
Important for that future update: startup/resume may retry this ALREADY consented
operation; it must not be mistaken for a newly authorized automated test.
If still staging, a cancellation receipt will safely conclude History removal;
if already finalized, the real manifest/tombstone path will conclude it instead.
Until then the real pending drive, outbox, staging bytes and earlier successful
cloud drive are retained. No real-account test or automatic deletion was run.
