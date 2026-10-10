# Planet segment publication — local preparation contract

This phase does not install a backend or submit segments to the legacy
`world_publishes` API. Existing whole-drive publications and their recovery UI
remain separate. The shared Planet map continues to read server Active World.

The legacy create/source path rejects disconnected or unknown canonical evidence.
An existing-publication UI cannot fall back to creating a whole-drive publication
when a later lookup returns no row. Already server-ready sources retain recovery.
Disabled-adapter receipts never contribute accepted distance or a real acceptance
label, including receipts persisted by a mock during local tests.

## Evidence and identity

- Source DriveSession stays unchanged and single in History.
- Each candidate contains only one canonical reliable GPS interval sequence.
  Invalid accuracy, breakBefore, gap metadata and unreliable time intervals
  break continuity. Presentation gap lines are never an input.
- Identity includes source drive ID, deterministic segment order, observed
  sample start/end microseconds, World rules version 6, geometry version 1 and
  SHA-256 of lossless canonical samples. Changed evidence gets a different key.
- Payload version 1 contains sourceDriveId, order, rulesVersion, geometryVersion,
  distanceMeters, score (nullable), startMicros, endMicros and canonical points.
  Points retain microsecond timestamps and acquisition quality. No credentials.
- distanceMeters is a LOCAL reliable delta total, not provider-validated distance.
  Every piece requires >= MyWorldRules.minimumValidDistanceMeters independently.
- Score uses only its own observed sample span. Authoritative original session
  timing must be known before score eligibility is considered. Missing movement,
  speed provenance or timing means null/N/A, not a numeric zero or copied score.

## Future server adapter requirements

`PlanetSegmentGateway` takes an owner scope and stable segment idempotency key.
The mobile authenticated client must bind this to the real server user; the
server must enforce owner + segment identity uniqueness. No service-role key.

1. `lookup(owner, segmentId)` returns an authoritative absent/pending/accepted/
   rejected/retryable receipt. A lookup timeout is NOT absence.
2. `submit(owner, payload)` must be idempotent under the same identity. Even a
   lookup returning absence followed by concurrent submits must not duplicate.
3. Server validates source/segment identity, geometry, quality, matching and
   >=5km final valid distance. A local eligible candidate is not final acceptance.
4. Accepted receipt includes remoteId and final validDistanceMeters. Rejected
   receipts are terminal; response loss must be recoverable by lookup.
5. Missing backend fields today: segment identity/order and parent drive mapping,
   geometry/quality version contract, per-piece status + score nullability,
   reconciliation lookup and final distance receipt. Do not encode a piece as a
   fake whole DriveSession or use its parent as the old unique local_drive_id.

## Local durability and visibility

`planet_segment_outbox_v1` is an additive dynamic Hive box (no adapter or old
data migration). Immutable evidence plus mutable delivery state is flushed
before network access. Unknown/sending/retryable states reconcile before submit.
Accepted/rejected states never resubmit. Per-key single-flight prevents parallel
requests in the main isolate. Each piece is independent; partial success remains.
Restart recovery is explicit adapter delivery/reconciliation, never startup
network submission. The production adapter is disabled in this phase.

Owner scope is fixed at preparation. Guest local-unassigned records are not
automatically reassigned or uploaded after login. An explicit ownership migration
policy is required before enabling a real adapter. Local deletion does not delete
this store or retract remote acceptance; accepted data retention needs a future
explicit account/privacy policy rather than ordinary History/World deletion.

Accepted publication distance sums only final accepted receipts. Unique road
discovery is a different server overlap/ownership statistic and is not inferred
from outbox totals. Queued/mock items never become shared map features.

Hive flush/reopen tests are not proof against every filesystem/power-loss failure
or multi-process writer. The store is a single-main-isolate consumer, not a GPS
foreground-isolate journal. No SQLite GPS schema or algorithms are changed.
