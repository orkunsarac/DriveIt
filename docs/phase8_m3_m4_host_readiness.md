# Phase 8 M3/M4 host readiness (2026-10-13)

Status: synthetic host preparation only. No remote Supabase, PostgreSQL,
Realtime, physical-device, or production acceptance is claimed here.

## M3 — World and Career projection

`test/phase8_owner_projection_host_test.dart` uses three separately opened
`OwnerScopedLocalStore` instances: two synthetic device stores for the same
account and one for another account. It passes the same proven source identity
through the existing source/contribution repositories and World v6 rebuild.
The fixture deliberately uses device-local drive IDs that differ. Replaying
the same contribution leaves the source-identity Career key and 6 km total
unchanged. The test also exercises independent History deletion and World
exclusion, and verifies that the other owner has no projected records or
legacy contribution.

This is a projection-boundary host test, not a two-device download test. It
does not prove a remote World/Career event feed, server-side exactly-once
semantics, crash durability across two network clients, or real account/RLS
isolation. M3 remains incomplete pending a versioned backend projection
contract and isolated server acceptance. History, World, and Career deletion
remain independent; legacy contributions are intentionally excluded.

## M4 — Group membership and realtime contract

The existing `GroupDriveService`/`GroupDriveClient` boundary is retained. The
in-memory fake host tests exercise owner leases, membership grants, fresh
location acceptance (15-second limit), pause clearing the latest point and
revoking its publication grant, resume with a new publication identity,
leave/ban rejection, and owner-epoch invalidation of delayed publishers.
Normal drive-save continuity has a separate existing regression test.

The remote adapter contract remains: server-derived actor identity;
transactional membership/role/capacity/expiry checks; a server-controlled
channel generation rotated on pause, membership revocation, ban, owner
revocation, or group end; no direct client broadcast; every publish must be
re-authorized against current membership, consent, owner epoch, and generation;
receivers drop stale generations and clear cached points on revocation. Points
expire after 15 seconds and are not persisted as history. The fake's group
revision/publication grants are useful host models, but are not proof that an
already-connected Supabase Realtime channel is immediately revoked. M4 remains
incomplete until the server adapter and two-client remote tests reject reads
and writes on pre-revocation channels.

## M1 backend static review delta

The isolated additive SQL candidate now rejects null idempotency, hash,
version, byte-count, page-cursor, and cleanup-limit arguments explicitly,
avoiding SQL three-valued-logic cases that could otherwise turn malformed
server RPC calls into empty results or deferred constraint errors. A matching
manifest discovered beside a still-staging intent is treated as invariant
drift and fails closed instead of returning a possibly-null ACK. Three pgTAP
negative assertions cover null finalization fingerprint, null page cursor,
and null cleanup limit. Snapshot pages additionally reject a leading or
interior sequence gap instead of advancing over it; pgTAP includes a synthetic
missing-leading-sequence case. The isolated deployment script's reviewed
SHA-256 pins were updated to the exact candidate sources.

These SQL changes were statically reviewed only. The local Docker Engine,
Supabase CLI, and Deno runtime were unavailable in the current environment;
the updated 45-test pgTAP suite and Edge tests have not been run against
PostgreSQL or an Edge runtime. No remote project was contacted or changed.
