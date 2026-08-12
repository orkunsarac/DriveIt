# Drive Score Phase 8B — Summary UI

## Persisted record loading

`DriveScoreSummarySection` is a small reusable, read-only widget used by the
saved-drive detail screen. It calls only
`DriveScoreStorageService.get(driveId: ..., algorithmVersion: 1)` through a
single Future and never loads telemetry, invokes analysis, or recalculates a
score. This also makes it safe for a newly saved drive: the lifecycle already
awaits score persistence before control returns, while the widget still shows a
short loading state if a read has not completed.

## Display behavior

The persisted `totalScore` is rounded for the primary `Drive Score / 1000`
display. The seven categories follow the constitution order. Actual,
applicable, sample-sufficient categories show their persisted raw score and
maximum. `neutralNotApplicable` is rendered as `N/A`; the internal neutral 75%
contribution is never shown as a category score. `neutralInsufficient` is
rendered as `Yetersiz veri`.

Legacy drives with no record show `Drive Score v1 mevcut değil` without an
invented score. Storage errors use a contained unavailable state, so the map
and all pre-existing drive summary statistics remain visible.

## Scope

No persistence, lifecycle, category mathematics, aggregation, Career, World,
or DriveSession Hive schema changed in Phase 8B. The section reuses the detail
screen's dark surface, neon-blue border, text hierarchy, spacing and card
language rather than introducing a separate design system.

## Validation

Widget tests cover final rounding (`834.5 → 835`), actual category score,
N/A, insufficient sample data, legacy record absence, loading, and storage
error fallback. `flutter test` completed with 120 passing tests. `flutter
analyze` reported no Phase 8B issue; it retains five existing info-level
findings in Home, Map, and route-preview UI files outside this phase. `git
diff --check` completed successfully.

## Phase 8C

Potential follow-up work is limited to lifecycle/recovery and production
regression checks. It must not introduce automatic legacy backfill, Career,
or World usage without a separately approved phase.
