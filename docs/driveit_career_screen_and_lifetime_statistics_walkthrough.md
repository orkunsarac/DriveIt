# DriveIt Career Screen

## Data audit

| Metric | Source | Calculation | Limitation |
|---|---|---|---|
| Total drives, distance, duration | `DriveSession` / `career_totals` | Deterministic lifetime aggregate | Deleted drives are not recoverable from the active box |
| Moving average speed | `DriveSession.distance`, `durationSeconds`, `stoppedSeconds` | Distance divided by moving time | Depends on recorded stop duration |
| Maximum speed | `DriveSession.maxSpeed` | Maximum persisted value | Uses the existing canonical recording pipeline |
| Stops, braking, corners | `DriveSession.stopCount`, `hardBrakeCount`, `cornerCount` | Sum of persisted counters | Labels describe detected events, not pedal/IMU readings |
| Drive Score | `drive_scores` / `DriveScoreRecord` | Average of available records only | Missing records are excluded |
| 0–100 | `DriveSession.bestZeroToHundredSeconds` | Existing validated persisted measurement | Missing values show “Henüz kayıt yok” |
| 0–60, World records, detailed G | — | Not fabricated in this phase | No reliable persisted source exists |

## Implementation

`CareerStatisticsService` is a read-only, deterministic aggregate over existing
`DriveSession` and `DriveScoreRecord` data. It does not add Hive fields, mutate
drives, or introduce a second career cache. Missing legacy telemetry and scores
are skipped safely.

`CareerScreen` presents a hero summary, general career metrics, personal records,
speed/performance, braking, corner/G diagnostics, and Drive Score career cards.
Record source navigation is available for the longest drive; unsupported metrics
use explicit empty-state text instead of fake zero values.

The Home “Kariyerim” card now opens `CareerScreen` with the existing DriveIt
visual language and retains all existing home statistics and storage behavior.

## Validation

- `flutter test`: 208 tests passed.
- `flutter analyze`: no new errors; five existing info-level findings remain.
- `git diff --check`: passed (only repository line-ending notices).

## Device checklist

Verify on the Galaxy A55: card tap/back navigation, long Turkish labels,
empty-score states, scroll behavior, and absence of overflow on a populated
history.
