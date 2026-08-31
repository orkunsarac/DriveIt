# My World v3 Rebuild and Short-Trace Audit

## Root cause

The rule version was already `3`, and `MyWorldRebuildService.needsRebuild()` correctly
detected a persisted snapshot with version `2`. The missing link was startup
wiring: `main.dart` drained pending validation jobs, but never called
`needsRebuild()` or `rebuild()`. The old active pointer therefore remained the
source for the first World read.

## Fix

`MyWorldRuntime.ensureCurrentWorldIndex()` now runs after Hive boxes open and
before `runApp`. It logs the pre-rebuild snapshot, awaits a rules/score-version
rebuild when required, then reads the committed generation again and verifies
`needsRebuildAfter == false`. The rebuild is source-history based and uses the
stored `DriveSession`, `ValidatedRoad`, and canonical telemetry; it does not
send Mapbox requests or delete source data.

The empty Hive-index fallback deliberately remains version `2`: a missing
pointer must force the first rules-v3 rebuild instead of hiding stored
validated roads. After that rebuild, the committed snapshot is version `3`.

## Audit output

Debug startup emits `[WORLD_REBUILD_AUDIT]`, `[WORLD_RULES]`, and
`[WORLD_REBUILD]`. `WorldDiagnosticService.auditCurrentWorldAfterRulesV3()`
also prints pointer/snapshot generation and version, deterministic snapshot
fingerprint, active distance/count, and every active trace below 1 km. Since
`ActiveWorldTrace` has no persisted provenance field, short-trace origin is
reported as `UNKNOWN` rather than inferred.

`MyWorldReadService` emits `[WORLD_READ]` with the loaded generation/version and
`[WORLD_RENDER_TRACE]` for short rendered traces. It has no long-lived screen
cache, so each load reads the active pointer again.

## Short-trace semantics

The planner still drops existing split remainders below 1,000 m and rejects
challenger winning regions below 2,000 m. First-record and uncovered
continuation traces are not globally filtered, preserving the approved product
semantics. No snapshot was manually cleared and no source record was removed.

## Validation

- `flutter analyze`: passes with the five pre-existing info-level findings.
- `flutter test`: 207 tests passed.
- `git diff --check`: passed; only Windows LF/CRLF notices were emitted.

Real-device counters and screenshots require a debug run on the Galaxy A55.
The expected log groups are `[WORLD_REBUILD_AUDIT]`, `[WORLD_REBUILD]`,
`[WORLD_SHORT_TRACE]`, `[WORLD_RENDER_TRACE]`, and `[WORLD_V3_AUDIT]`.
