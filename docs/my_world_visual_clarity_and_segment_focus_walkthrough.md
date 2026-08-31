# My World visual clarity and segment focus

## Applied changes

- Active traces now use a thinner core (2 px) and a restrained glow (5 px),
  with selected/highlighted traces at 4/8 px.
- Presentation-only zoom filtering hides short traces at distant zoom levels:
  5000 m minimum below zoom 6, 2500 m below zoom 8, 1000 m below zoom 11,
  and 300 m below zoom 13.
  The active index and source geometry are never changed.
- Each resolved trace renders a small hollow start circle and filled end circle
  from the resolved active-trace geometry, not from the full DriveSession.
  Circle radii reduce in screen prominence as the map zooms out and disappear
  together with filtered traces.
- The existing deterministic visual-variant assignment now uses an eight-color
  premium dark-map palette (cyan, blue, red, green, orange, purple, gold and
  magenta). A source drive keeps the same variant for all of its traces.
- Selecting a trace still dims the other traces and fits only the selected
  geometry. The detail sheet now includes trace distance, trace start/end,
  full Drive Score, and an on-demand “Dünya İzi Puanı”.

## Segment score

`WorldTraceDetailService.loadTrace` reads the selected trace geometry and the
existing canonical telemetry, finds the corresponding ordered telemetry range,
and sends that in-memory subset through the existing `DriveScoreCalculator`.
No Hive score record is written and no World ownership/index operation is
called. If the subset is insufficient, the UI safely shows “Mevcut değil”.

## Detail navigation and safety

“Sürüşü Görüntüle” continues to open the existing full-drive detail screen.
The map remains read-only; no Mapbox request, rebuild, ownership mutation, or
DriveSession change was added.

## Performance

Filtering and marker construction happen only during the map build/idle cycle,
not on every Hive read or animation frame. Segment score is calculated only
after a trace is selected.

## Verification

- `flutter test`: passed, 201 tests.
- `git diff --check`: passed; only Git's LF/CRLF normalization notices remain.
- `flutter analyze`: no errors; five pre-existing info-level findings remain in
  `home_screen.dart`, `map_screen.dart`, and `route_preview.dart`.
- The new visibility policy tests cover distance/zoom filtering and marker
  sizing. Existing Phase 8/9 selection and detail tests also pass.
