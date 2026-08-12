# Drive Score v1 — Phase 8C Integration and Regression Walkthrough

## Scope

Phase 8C verifies the existing Drive Score v1 lifecycle without changing
category mathematics, UI design, Hive schemas, Career scoring, or the World
system.

## Verified end-to-end lifecycle

`DriveStorageService.saveDrive` first persists canonical telemetry when it is
available, then persists the `DriveSession`. Only after those durable writes
succeed does it invoke `DriveScorePersistenceCoordinator`. The coordinator
reads the persisted telemetry, runs the existing Phase 2–7 analysis and score
engines, and writes the deterministic v1 `DriveScoreRecord` into
`drive_scores`. The drive-detail summary normally performs only the lightweight
storage lookup and renders that stored snapshot.

## Missing-score race and recovery

The normal save path awaits the score coordinator before returning, so a newly
saved drive normally has its score ready before its details can be opened. A
small recovery path additionally covers a crash or partial score write: the
detail summary checks storage once; only when v1 record is absent does it call
`calculateAndPersistForDrive`. The coordinator returns an existing v1 record
without recomputing it and returns `null` when there are fewer than two
canonical telemetry samples. There is no polling loop and the normal detail
path never reruns the score engines.

## Failure isolation

Score calculation and `drive_scores` persistence are secondary to saving a
drive. Their failures are caught after the `DriveSession` and telemetry write,
so a score failure cannot discard the recorded drive. The persistence tests
cover a closed score box while saving a drive and verify that the drive remains
in `drives`.

## Restart and deletion lifecycle

`DriveScoreHive` registers adapter typeId 4 and opens `drive_scores` during
application startup. The regression suite closes and reopens the score box,
then reads the same record back. `DriveStorageService.deleteDrive` removes the
parent drive first and attempts telemetry, score, and display-name cleanup even
if an earlier dependent cleanup fails. This prevents a telemetry-cleanup error
from leaving a known score orphan behind.

## Legacy, N/A, and insufficient-data behavior

Legacy drives without canonical telemetry do not enter recovery and do not get
a fabricated v1 score; the detail UI remains on its existing unavailable state.
Persisted `neutralNotApplicable` categories render as `N/A`, while
`neutralInsufficient` categories render as `Yetersiz veri`. Their internal
neutral contributions remain part of the stored final-score calculation but
are never presented as an earned category score. Final-score rounding remains
the existing `834.5 -> 835` behavior.

## Intentional limits

No batch backfill, retry queue, Career integration, World/local-score
integration, score-schema migration, or real-device calibration is introduced
in this phase. Recovery is deliberately one-shot and scoped to the opened
drive detail.

## Validation

The Phase 8C regression suite covers save-to-score persistence, missing-score
recovery and idempotency, telemetry-less legacy behavior, score-storage
failure isolation, restart reads, and dependent deletion cleanup. Repository
analysis, the complete test suite, and whitespace checking are run after the
implementation work.
