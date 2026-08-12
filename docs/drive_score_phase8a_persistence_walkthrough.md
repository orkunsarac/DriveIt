# Drive Score Phase 8A — Persistence and Lifecycle

## Record and Hive layout

`DriveScoreRecord` is a versioned snapshot stored separately from the legacy
`DriveSession` model. It keeps the drive ID, Drive Score algorithm version,
canonical telemetry data version, calculation time, total score, confidence,
and all seven category snapshots. Each category keeps its raw score, maximum,
applicability, sample sufficiency, contribution used, and contribution source.
The neutral contribution sources remain explicitly distinct from actual scores.

The new `drive_scores` box uses Hive type ID `4`. Existing IDs `0` and `1`
remain the drive and route models, `2` and `3` remain canonical telemetry, and
My World continues to use `10` through `18`. No existing type ID, Hive field,
box name, or `DriveSession` field has changed.

## Lifecycle and safety

The save sequence is canonical telemetry persistence, `DriveSession`
persistence, then best-effort score calculation and `drive_scores` persistence.
`DriveScorePersistenceCoordinator` rereads the persisted telemetry before it
runs the Phase 2 analyzer and the existing Phase 3–7 score engines. A score
failure is isolated in `DriveStorageService`: it cannot roll back or delete a
saved drive or telemetry timeline.

The storage key is deterministic: `<driveId>:v<algorithmVersion>`. This makes
the same drive/version idempotent and avoids score-record accumulation. The
storage service validates finite bounded totals and category values, valid
versions, non-empty IDs, and that category contributions equal the persisted
total before writing.

## Missing telemetry and legacy drives

When canonical telemetry is absent or insufficient, no v1 score record is
created. Legacy `DriveSession` records remain untouched and can simply return
"score not found". This phase does not perform a historical backfill or infer
scores from legacy summary values.

## Phase 8B readiness

`DriveScoreStorageService.get(driveId: ..., algorithmVersion: 1)` provides the
read-only API required by a future Drive Summary UI. Phase 8A intentionally
does not alter any UI, Career, World, ownership, or score mathematics.

## Validation

The Phase 8A tests cover Hive round-trip values, actual and both neutral
contribution sources, telemetry/algorithm version separation, deterministic
idempotency, missing telemetry, and invalid non-finite score rejection.

`flutter test` completed with 117 passing tests. `flutter analyze` found no
new Phase 8A issue; it still reports five existing info-level findings in
Home, Map, and route-preview UI files outside this phase. `git diff --check`
completed successfully.
