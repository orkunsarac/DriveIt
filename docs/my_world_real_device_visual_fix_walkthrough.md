# My World real-device visual fix

## Root causes

- The trace detail sheet exposed the full-drive metrics as a large grid, which
  made the bottom sheet too tall on Galaxy A55-sized viewports.
- Distant zoom levels used the same stroke/glow scale as close zoom levels.
- Marker visibility was tied only to trace visibility and the palette conflict
  resolver avoided exact colors but not nearby hues.

## Applied fixes

- The detail sheet is now world-trace focused: trace score, trace distance,
  trace start/end, source date, and full Drive Score are primary. Full-drive
  metrics remain as a compact secondary summary and the existing full-detail
  CTA is unchanged.
- The sheet remains intrinsically sized and scrollable; the compact grid and
  secondary summary avoid fixed-height overflow.
- Selected traces keep the strongest core/glow. Other traces are reduced to
  approximately 18% opacity while a trace is selected.
- Colors remain deterministic per `sourceDriveSessionId`; cyan/blue,
  green/gold, and purple/magenta conflicts are resolved to another palette
  slot for adjacent sources.

## Zoom policy

| Map zoom | Minimum trace distance | Glow/core behavior |
| --- | ---: | --- |
| 13+ | 0 m | normal close presentation |
| 11–12.99 | 300 m | thin core, controlled glow |
| 8–10.99 | 1,000 m | 1 px core, very low glow |
| 6–7.99 | 2,500 m | 1 px core, low glow |
| <6 | 5,000 m | 1 px core, no glow |

Markers are hidden below zoom 6 and use the resolved active-trace geometry
start/end points above that level. Starts are hollow rings and ends are filled
dots; they are not full-drive endpoints.

## Ownership and small fragments

No World index or ownership code was changed. Any small colored fragments are
therefore existing `ActiveWorldTrace` records from the backend index, not
presentation-created subdivisions.

## Segment score

The selected active trace still maps its resolved geometry endpoints to the
ordered canonical telemetry subset and runs the existing in-memory
`DriveScoreCalculator`. No score record or World data is persisted.

## Verification

- `flutter test`: passed after the visual fixes.
- `flutter analyze`: no errors; only the repository's existing info-level
  findings remain.
- `git diff --check`: passed.

## Device checklist

On the Galaxy A55, verify the detail sheet at default text scale, zoom from
country view to street view, selected/unselected trace contrast, marker
visibility, and the full-drive CTA navigation.
