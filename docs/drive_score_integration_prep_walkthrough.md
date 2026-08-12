# Drive Score Integration Prep

## Purpose

This small preparation phase separates the existing full Drive Score v1
calculation pipeline from Hive persistence. It does not change scoring
mathematics, category weights, the Drive Score record format, UI behavior, or
any My World code.

## In-memory calculation entry point

`DriveScoreCalculator.calculate` accepts an `Iterable` of
`CanonicalTelemetryPoint` values and returns the existing `DriveScoreResult`.
It does not require a `DriveSession` ID, does not create a
`DriveScoreRecord`, and never reads or writes Hive. It uses the same Phase 2
analysis, all existing category engines, endurance engine, and final v1
aggregation previously orchestrated directly by the persistence coordinator.

This permits a future caller to score an independently selected canonical
telemetry range, such as a verified common-road range, without persisting a
normal whole-drive record.

## Persistence coordinator

`DriveScorePersistenceCoordinator` retains its public
`calculateAndPersistForDrive` behavior. It loads canonical telemetry by drive
ID, invokes `DriveScoreCalculator` with explicit v1 selection, maps the result
to the unchanged `DriveScoreRecord`, then saves it through the existing
deterministic storage key. Legacy or insufficient telemetry still returns no
fabricated score.

## Algorithm version selection

`DriveScoreAlgorithmVersion` centrally represents supported calculation
versions. Only `v1` is implemented. `calculateForVersion` converts persisted
integer values explicitly and throws `UnsupportedDriveScoreAlgorithmVersion`
for an unknown value; it never silently falls back to v1. A future v2 can add
an explicit resolver branch without changing callers that use the calculator
contract.

## Determinism

The in-memory calculator uses no current time, DriveSession ID, random input,
or persistence state in its score result. Identical canonical telemetry and
algorithm version produce the same v1 result. Persistence time remains record
metadata only.

## Validation

Regression tests cover in-memory scoring without Hive writes, no DriveSession
ID requirement, local subset scoring, deterministic reruns, explicit v1,
unsupported versions, coordinator/calculator parity, and existing v1
persistence behavior. Full repository tests, static analysis, and whitespace
checking are run after the change.

## Explicitly not included

No My World integration, local-road ownership logic, score math change,
category weight change, record migration, UI change, or v2 scoring algorithm
is introduced.
