# Phase 6 owner-drive synchronization contract (fake client acceptance)

Status: client-side contract and synthetic two-store adapter only. No Supabase
schema, RPC, RLS, credentials, network transport, or production worker is
created by this document or implementation.

## Identity and authorization

- A syncable record is a newly finalized, account-owned drive with a proven
  immutable `sourceIdentity` (UUID v4), owner scope, complete drive/route,
  telemetry, and optional already-persisted Drive Score. `drive.id` remains a
  local record key; it is not cross-device identity. Legacy, guest, unfinished,
  deleted, unproven, and conflicting records are excluded.
- A server must derive the account UUID from the authenticated token. A client
  `ownerId`/scope is an assertion to validate, never authorization. All reads,
  writes, cursors, idempotency reservations, receipts, and leases are scoped to
  that authenticated UUID; a mismatch is denied without revealing whether
  another owner's record exists.
- `sourceIdentity` is immutable across retries/devices. The server's unique
  logical key is `(authenticated owner UUID, source namespace/version,
  sourceIdentity, operation kind)`. Identical replays return the original
  receipt. Same key with a different canonical payload fingerprint is a
  conflict, not last-write-wins. Distinct source identities are distinct drives
  even if local `drive.id` values collide. Same real-world trip without common
  identity is not automatically inferred or merged.

## Upload, ACK, and retry

- Upload v1 carries operation/version, authenticated-owner assertion, source
  identity/version/namespace, stable idempotency key, SHA-256 of canonical
  payload, and the validated `LocalSourceBundle` v2 (recorded drive summary,
  ordered route with segment boundaries, canonical telemetry/acquisition
  metadata and optional persisted Score). Mutable map-matched roads, World
  generations/jobs, Career contributions, poster files, and credentials are not
  part of this immutable drive-upsert payload. They require separate
  versioned domain changes; roads are derived locally from the canonical
  route/telemetry instead of changing an already-ACKed drive payload. It
  contains no poster image path/content. A future
  server validates schema, ranges, provenance-owner agreement, canonical
  fingerprint, and immutable identity before commit.
- A durable local outbox row is `queued → sending → acknowledged`,
  `retryableFailure`, or terminal `conflict`. Timeout/connection loss is
  ambiguous: retry only with the same key and bytes. A matching ACK must echo
  owner scope, key, and fingerprint. ACK is persisted and read back locally.
  Retry scheduling is bounded to one page/pass at a suitable lifecycle event;
  exponential backoff with jitter and a cap is a backend/worker policy, not an
  always-on polling loop in this client phase.
- A failed queue/transport/ACK does not fail the already verified local drive
  save. Startup reconciliation repairs the Hive-finalization-to-outbox crash
  gap and never scans legacy or guest data.

## Download and checkpoint

- Download takes the authenticated UUID and an opaque account-scoped cursor.
  The server returns an owner-bound page from a consistent ordered change feed,
  with `fromCursor`, changes, and `nextCursor`; a cursor must not be reusable
  across owners. A snapshot token or equivalent server guarantee is required
  when pagination spans a changing feed.
- The client validates the whole page's owner, operation kind, proven source
  identity, owner scope, and payload fingerprint before applying any row.
  Tombstones/unsupported versions fail closed. Each drive is staged behind a
  durable `sync_importing` finalization marker, written into that account's
  scoped store, verified by read-back, then exposed by a completed marker and
  durable received receipt. The cursor advances only after every page row has
  completed and been verified. If interrupted, the cursor stays put and the
  same page is safely replayed; an incomplete History row remains hidden.
- Reapplying an identical completed record is a no-op. Existing local ID with
  different provenance/content is a conflict and is never overwritten. Same
  identity under an unexpected local key also requires explicit reconciliation;
  there is no automatic rekey/remap in this phase.
- This limited receiver persists History, route, telemetry, provenance, and an
  included persisted Score. It does not run World rebuild or create Career
  contributions; cross-device derived World/Career replication/projection is
  not claimed by this fake acceptance and needs its own explicit event/rebuild
  contract before cloud rollout. History deletion remains independent from
  World/Career; this phase does not cascade a History delete into them.

## Deletion and active-drive lease (not implemented here)

- Delete sync stays disabled. A valid future tombstone needs an immutable
  deletion operation UUID, authenticated owner UUID, proven source identity,
  UTC deletion timestamp, source record/version or server revision observed at
  deletion, and a durable causal ordering/version. Server replay must be
  idempotent and dominate older uploads so stale devices cannot resurrect
  deleted payload. Existing local tombstones lack this evidence; do not infer
  it or synthesize timestamps/identities.
- Concurrent active-drive exclusion is a server lease, not a local lock. The
  product baseline is a 30-second heartbeat and 3-minute expiry, subject to
  field tuning. A future lease binds authenticated owner, device/session,
  source identity, monotonically increasing fencing token, and expiry. Offline
  recording is never stopped or discarded when the lease expires; reconnect
  requires explicit conflict reconciliation. No lease transport or heartbeat
  is implemented in this phase.

## Current implementation/test boundary

`OwnerDriveSyncClient` owns local outbox validation, stable identity/fingerprint,
ACK checks, and the synthetic download applier. `OwnerDriveSyncWorker.runOnce`
is bounded. `LocalOwnerLifecycle` can receive only an explicitly injected fake
remote under enabled synthetic ownership composition; it runs one pass after
owner readiness/finalization and exposes a resume hook for another single pass.
Production composition provides no adapter; ownership gate remains closed.

Fake two-device acceptance uses separate Hive roots for Device 1 and Device 2,
one shared in-memory fake remote, and synthetic coordinates only. Device 2
downloads under the same A UUID, verifies History/route/telemetry/Score and
replay idempotency; B receives no A rows and rejects a forged A mutation. This
does not prove server authorization, durability, RLS, multi-device leases, real
network ambiguity, or Android process/power-loss recovery.
