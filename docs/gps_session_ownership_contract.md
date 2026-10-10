# GPS ownership sidecar — Phase 5A, dormant

No production bootstrap, foreground callback, auth event or existing Hive sink
opens this component. Existing GPS SQLite journal stays version 3. Sidecar is
a separate database (version 1), with WAL + synchronous FULL transactions.
There is no runtime feature flag which can accidentally enable new routing.

## Identity and lifecycle

- Guest, account (canonical Supabase UUID) and legacy_unassigned are distinct.
- Target identity is JSON `[local_account_store_v1, kind, UUID-or-null]`;
  scoped record identity combines that target and unchanged local session ID.
- Binding is unique on stable local journal identity + session ID. Reusing that
  acquisition identity for a different owner is rejected, never overwritten.
- Capture auth exactly once. Commit/read back a prepared reservation BEFORE
  journal creation, create the existing v3 session, then commit/read back its
  ready binding. Only after readiness may a future caller start native recording.
- If prepare fails no journal is created. If journal create fails the orphan
  reservation stays. If binding fails, journal is retained and no native start
  is performed by this coordinator. No automatic removal/rebind.
- Two DBs are not one transaction. A crash between journal creation and binding
  leaves an unassigned journal. Do not infer its owner from pending reservations,
  newest timestamp, current auth or profile names. Existing legacy recovery must
  remain available, but scoped transfer is blocked. Explicit reconciliation and
  approved legacy claiming belong to later phases.

## Transfer

OwnedGpsTransferSink must be bound to a fixed target repository for its lifetime.
Shared production GpsHiveTransferSink intentionally does not implement it.
Before any sink access, the coordinator checks a committed ready manifest and
commits a sidecar transfer intent with deterministic operation ID and target.
It then reuses existing GpsSessionTransfer projection, intent, full read-back,
verification and SQLite receipt; no GPS/score algorithm is duplicated.

Only after that verification does sidecar state become verified. Lost response
or sidecar receipt failure leaves the intent retryable to the SAME target.
Existing journal verified receipt alone is not new ownership verification.
A future cleanup integration MUST require both receipts plus fresh scoped sink
verification; this component never calls journal maintenance or deletes points.
Current production cleanup is unchanged because the new path is not connected.

## Old data and future integration gates

Missing binding resolves read-only to legacy_unassigned. Old sessions, transfer
receipts, Hive objects and IDs are neither scanned/backfilled nor rewritten.
No account claim API is supplied in 5A. Existing shared transfer remains working.

Before enabling in 5B: implement fixed scoped sinks, startup/recovery barriers,
stable journal identity provisioning, no native start before manifest readiness,
scoped receipt cleanup checks, and per-account asynchronous consumer/cache guards.
Before 5C: approved copy/verify/commit migration for legacy payloads and receipts.
Auth signIn/signOut and Supabase APIs are intentionally unchanged.

## Evidence limits

Fault callbacks run inside sidecar transactions; these are controlled failures,
not OS process kills. The child probe exits after a committed intent without
closing the database: this tests process-exit/WAL recovery, not power loss or
Android OS kill. Real device acceptance remains deferred. No coordinates or
credentials are included in sidecar metadata or error logging.
