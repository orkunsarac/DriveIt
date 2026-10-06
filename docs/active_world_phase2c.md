# Active World Phase 2C

## Planner choice

A handwritten TS port would duplicate interval subtraction, split/merge,
sanitization and deterministic ID behavior. A SQL ownership algorithm would
duplicate scoring/ownership decisions and make parity harder. Instead the actual
pure Dart `WorldIndexMutationPlanner` is compiled into the existing server
bundle. SQL validates provenance and interval invariants, not who wins.

The planner receives only current spatial candidates, grouped by trace before
planning. All source sections for those candidates remain canonical. Bounds are
full-section coarse filters, so adjacent versions of the same source section
enter the same candidate snapshot; non-candidates cannot merge with a candidate
of that same section outside the coarse snapshot. Unaffected traces are never
copied. The normalized resulting **candidate** snapshot is diffed, not the
planner's `tracesToCreate` field: that field alone omits incumbent remainders and
post-merge trace identities.

No-win preserves covered incumbent ownership, but uncovered challenger spans
may still be added. Full/start/end/middle/multiple wins use the existing Dart
split and merge. 2km winning spans, 1km active/remainder filtering and <3km
geometric ownership suppression retain My World semantics. Directions stay
separate. IDs use Dart's existing three-decimal key formatting; actual offsets
are never rounded. Offsets cross JSON as float8 round-trip decimal strings.
Generation metadata is TS BigInt/SQL bigint, avoiding JS safe-integer loss.

## Persistence and concurrency

Migration `202610060002` adds a current-section index, a server-only enriched
candidate read RPC and `commit_active_world_mutation`. It reuses temporal trace
versions and existing generation operation/source-publish uniqueness.

The commit locks the single pointer, checks duplicate publish first, then CAS.
It verifies processing/source-ready publish, eligible validated distance,
operation identity, exact retired current versions, spatial candidate membership,
real published source provenance, section/cumulative bounds, finite >=1km spans,
unchanged remainder direction/bounds and coverage by retired source spans.
It checks duplicate current intervals for touched source sections. Interval
coordinates are added in section_order as float8, never unordered numeric SUM.
Metadata precedes temporal FK changes; publish and pointer changes are last.
Everything commits in one transaction. Existing generation trace_count plus
delta determines the new global count without recounting/copying the world.

CAS loser returns `stale_generation`; the client treats it as retryable, and a
new request recomputes from the current world. After committed-but-response-lost,
the unique source publish operation returns already_processed before CAS,
Storage or Mapbox. Existing validation reuse and Phase 1 generation 0 remain.
Later empty snapshots use the shared mutation path rather than assuming gen0.
RPC EXECUTE is revoked from PUBLIC/anon/authenticated; service_role only.

## Tests and limits

Native Dart oracle and compiled JS fixtures cover wins, remainders, multiple
incumbents/matches, partial traces, multi-section/cumulative, fractional offsets,
adjacent merge and >2^53 generations. Existing semantic/scoring/overlap fixtures
remain required. SQL tests clone schema constraints into an isolated rollback
transaction and inject failure after insertion. A separate two-transaction race
uses a fixed synthetic namespace, removed in finally. Neither test writes the
real public World pointer, generations or traces or invokes a real publish.

Projection segment metadata is prepared once per range; mathematically disjoint
canonical segment intervals are excluded before projection. Distance/heading,
self-intersection range preference, telemetry and tolerance rules are unchanged.
Original oracle parity is checked, not regenerated to hide changed outcomes.

Representative desktop Deno observations (not hosted SLA): dense 2001 telemetry
points/201 section geometry points, 40 windows: ~0.31s one candidate/~0.77s three;
5000 candidate traces ~0.15s planner, unchanged-world delta ~582 bytes. Sampled
heap ~82MB/RSS ~171MB across sequential benchmark cases is not a true peak bound.
One private source transfer per unique eligible source/request; seeded challenger
avoids repeat upload/download. Dense fixture telemetry JSON ~444KB per drive.
SQL commit+post-checks across small fixtures ~3ms mean/~5ms max; not a million-row
load benchmark. Large source sets, highly dense sections and high candidate
counts still need hosted CPU/memory budgets before broad production rollout.
Planner's duplicate-ownership assertion is quadratic in candidate trace count.

No actual A55 challenger was invoked. Real generation 1 must remain unchanged
until a separately authorized authenticated second-publish test. Phase 2C
changes are deliberately not committed/pushed in this task.
