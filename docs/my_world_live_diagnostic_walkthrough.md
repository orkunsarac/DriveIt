# My World live diagnostic

## What was added

`lib/features/my_world/services/world_diagnostic_service.dart` is a small,
debug-only, read-only projection of the latest saved `DriveSession`. It reads
the existing `drives`, canonical telemetry, Drive Score, validated-road,
processing, pending-job and active-index boxes. It does not call a provider or
any enqueue, retry, rebuild, write, delete, migration or score-calculation
operation.

`main.dart` starts it once after Hive and the application have been initialized,
guarded by `kDebugMode`. Release builds therefore do not emit the diagnostic.
Every terminal line starts with `[WORLD_DIAG]` and the Mapbox token is reported
only as a boolean.

## Classification tests

`test/world_diagnostic_test.dart` covers missing jobs/roads, the 2999/3000 m
threshold, an unprocessed validated drive, an active trace success, and a
processed drive whose index trace is missing.

## Device trigger

Run the debug app and watch the same terminal for the prefixed report:

```text
flutter run -d R5CX42V8GSJ --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_TOKEN
```

The token may be omitted for a local diagnosis; the report will then show
`MAPBOX_ACCESS_TOKEN configured=false`. Replace `R5CX42V8GSJ` with the device
serial shown by `flutter devices`. No token value or token characters are ever
printed.

## Deliberately not fixed here

The utility diagnoses the first pipeline breakpoint only. It does not repair
missing jobs, invoke Mapbox, rebuild the World index, or change the underlying
World/Drive Score behavior.
