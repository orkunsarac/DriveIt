# My World short trace and detail card audit

## Short trace audit

`ActiveWorldTrace` currently persists source drive, road/section identifiers,
offsets, bounds and timestamps, but not mutation provenance. Therefore a
100-metre trace can be measured exactly from `endOffsetMeters -
startOffsetMeters`, yet cannot be safely classified as `SPLIT_REMAINDER` or
`CHALLENGER_WINNING_REGION` from the persisted snapshot alone. The debug
diagnostic now emits `[WORLD_TRACE_AUDIT]` lines with the trace id, source drive,
offsets, length, and `origin=UNKNOWN_NO_PERSISTED_PROVENANCE` without changing
the index. It deliberately reports no minimum-winning-region violation: a
short old remainder is valid under the existing World rules.

The mutation planner already rejects a new challenger region below
`MyWorldRules.minimumLocalWinningRegionMeters` (500 m) before creating the
challenger trace, while `_splitExisting` may preserve shorter old remainders.
No engine fix was required and no ownership rebuild was performed.

## Detail card root cause and fix

The detail sheet combined a secondary full-drive summary, a fixed-aspect-ratio
grid and coordinate values inside compact tiles. On a Galaxy A55 viewport the
combined intrinsic height exceeded the bottom-sheet constraints. Primary trace
metrics now use an intrinsic `Wrap` with responsive half-width tiles rather than
`GridView.count` with a fixed child aspect ratio. Tile columns use natural
height, ellipsis protects long values, and the sheet remains scrollable inside
`SafeArea`.

The card remains trace-focused: World Trace Score, trace distance, trace start,
trace end and full Drive Score are the primary fields. Existing full-drive data
is retained only as a compact secondary summary and the full-drive CTA is
unchanged.

## Segment score and visibility

The selected trace still maps its resolved active geometry to canonical
telemetry and calls the existing in-memory `DriveScoreCalculator`; no score is
persisted. A short trace may legitimately show its real distance and an
unavailable score when telemetry is insufficient. Zoom filtering and marker
behavior remain presentation-only.

## Verification

- Focused Phase 8/9 presentation tests and visual policy tests pass.
- Full `flutter test` passes (201 tests).
- `flutter analyze` has no errors; five pre-existing info-level findings remain.
- `git diff --check` passes.
