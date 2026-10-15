# M2 real-phone upload/delete failure — diagnosis and bounded correction

Hosted follow-up: `202610160003` and the three approved Edge changes passed
synthetic Planet DEV acceptance. See
`phase8_m2_staging_cancellation_planet_dev_acceptance.md`. The historical
diagnosis below remains valid; no phone update or real cancellation occurred
in that backend deployment task. GPS zero-sample cause remains unproven.

Follow-up: local staging-cancellation implementation and acceptance are now
recorded in `phase8_m2_staging_cancellation_delivery.md`. The reserved migration
below has been created locally, but no remote deploy or phone update occurred.

Date: 2026-10-15. Normal app on A55; Planet DEV `viqngnjfgknpxtoapzcg`.
No user email, UID, token, object path or coordinate is recorded here.

## Proven failure boundaries

Read-only hosted invocation logs after the user's attempt show lease 200,
begin 200, finalize **422** (two invocations), delete/observe **404** (two
invocations). Existing real-account DB state contains the prior successful
manifest and no new manifest/tombstone for the failed new attempts. Matching
private staging objects exist with exact declared byte lengths. Lease expiry
was still 142–156 seconds away at the last intent update, so this is not the
earlier 409/fencing or offline problem.

The two recent failed staging envelopes were downloaded into process memory
for READ-ONLY validation with the existing server validator. They were never
saved or printed. Both have correct object SHA-256 and canonical bytes; the
validator throws `provenance_or_bundle_invalid`. Boolean subdivision identifies
only **telemetry.points is empty** in that predicate. Finalize therefore returns
the existing public `422 staged_envelope_rejected`. No GPS points, scores or
metrics were invented, repaired or uploaded. Why the recording produced zero
canonical telemetry points is not proven by these observations; GPS/journal
capture code was not changed to speculate about that cause.

M1's successful drive and previous synthetic tests had nonempty telemetry.
The client eligibility check validated provenance/record presence but did not
require a nonempty telemetry list, unlike the server. Thus previously passing
M1/M2 synthetic tests did not cover this genuine phone payload.

## Why delete cannot complete

The durable upload outbox treats `attemptCount>0` as ambiguous cloud evidence.
That is intentional: a missing local ACK is not proof of cloud absence.
Deletion consent is persisted and blocks subsequent upload retries for that
source. `sendCloudDeletion` first observes a manifest to obtain actual revision
evidence. With only staging/no manifest, the current observe endpoint returns
**404 source_unavailable**. No valid drive tombstone is sent or acknowledged.
Current tombstones reference a real manifest and require its observed sequence;
those values cannot be manufactured for a staging-only source.

The phone's private Hive files were not opened; local row contents were not
dumped. The specific outbox state/error follows the observed 404 and the existing
persisted client transition (`conflict`, `source_unavailable`), not a fabricated
private-file inspection. The old History banner labeled every non-ACK state
as pending, obscuring this permanent contract gap.

**A 404 observation alone is not a safe cancellation receipt.** Another
in-flight request could finalize after it; removing only local data/outbox would
permit resurrection. Nor is this solved by deleting a private Storage object.

## Local fixes implemented

- Existing sync client: empty-telemetry candidates show `ineligibleTelemetry`;
  new enqueue and reconciliation reject/skip them before creating a network
  attempt. Persisted staged mutations also have an empty-list guard. No old
  queue row or payload fingerprint is rewritten/removed.
- Existing cloud UI: the upload control is disabled with the explicit local-only
  telemetry explanation. Typed conflicts are not described as probable offline
  failures. This does not claim a missing GPS sample was recovered.
- Existing History: conflict is distinguished from retryable pending. A source
  unavailable conflict explains that cloud finalization did not complete and
  the record is retained. No false success/ACK is shown.
- Same owner/epoch/fencing/consent and anti-resurrection barriers are retained.
  Guest, Device Archive, World/Career, Auth and normal GPS recording are unchanged.

Existing tests gained two synthetic regressions: empty telemetry never enqueues
and stays local; failed upload -> deletion observe 404 retains consent/data and
prevents a stale upload from resurrecting the source. Existing M1 successful
upload/ACK, response-loss retry, tombstones, cursor and A/B tests remain covered.

## Server change required — NOT DEPLOYED, approval required

Proposed single forward M2 migration scope:
`202610160003_phase8_m2_staging_cancellation.sql` (reserved proposal, not created
or applied in this task). Existing applied migrations remain immutable.

1. Add permanent owner/source-bound **staging cancellation evidence**, separate
   from finalized-drive tombstones. Bind actual existing intent/source/hash,
   actual consent UUID/UTC and idempotency; do not invent a manifest or observed
   manifest sequence. No physical data purge, Auth/Planet edits or global cleanup.
2. A service-only, empty-search-path SECURITY DEFINER cancel RPC acquires the
   existing per-source lock. If finalization won, return the actual manifest
   evidence and use the existing tombstone protocol instead. If still staging,
   atomically record cancellation and revoke the intent's future finalization.
   Replays return the same receipt; owner/hash conflicts are rejected.
3. Existing begin/finalize barriers reject a permanently cancelled source even
   from old offline clients. Keep M1 paths unchanged for all other sources.
4. Extend only the existing delete Edge endpoint for authenticated cancellation
   observation/receipt, and existing download/change-feed handling if a source
   cancellation event is emitted. Use a distinct validated cancellation contract,
   not an invented `driveTombstone` with a nonexistent observed sequence.
5. Extend the existing local deletion client to apply a verified cancellation
   receipt and permanent source barrier, then remove only the matching local
   History copy. Until receipt, preserve the drive/outbox/consent. Finalized
   sources still use current tombstones. Staging-only cancellation must not be
   silently downgraded into a local-only delete.

Required acceptance uses existing pgTAP/Edge/Flutter infrastructure: cancel vs
finalize race in both orders, ACK loss/replay, old upload retry rejection, cursor
consistency, owner A/B/anonymous rejection, M1 upload regression. Synthetic data
only. Real user's pending sources will NOT be used as automated fixtures.

This fixes an M2 cancellation contract gap, not M3/M4 or a new storage/sync
architecture. Exact SQL/API implementation and remote rollout require approval;
no remote write, migration, Edge deployment or automatic user operation occurred.

## Tests, installation and safe next action

- Targeted existing Flutter tests: **61/61**.
- Existing local PostgreSQL: M2 **34/34**, M1 **45/45**.
- Existing Deno canonical tests: **2/2**.
- Full Flutter regression: **993 passed, 2 conditional skips**.
- Analyze: existing **3 warnings + 4 infos**, no new finding; exit 1, not clean.
- `git diff --check` passes. Prior successful manifest row fingerprint matches
  its pre-M2 baseline. No remote synthetic or real-account mutation was run.
- No normal APK build/install: this is not a Flutter-only end-to-end fix.
  Installing only diagnostic/eligibility changes would leave the current pending
  staging deletion blocked. No commit/push or private-device-data access.

Current failed drive, staging object and deletion consent remain protected.
Do not clear its queue or retry its old upload to bypass deletion. The prior
successful cloud drive remains outside all operations. Next user decision:
approve the narrowly scoped staging-cancellation backend/client repair above;
after synthetic acceptance, a corrected normal APK can safely retry the existing
consented deletion. A future nonempty-telemetry drive remains the valid M1 upload
case, but no real-account upload is initiated here.
