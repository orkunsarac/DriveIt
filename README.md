# driveit_project

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Benim Dunyam v2 - Phase 1 walkthrough

Phase 1 adds only the provider-independent data and persistence foundation.
It does not change the visible World card or any driving behavior.

### Existing project structures found

- `DriveSession` is Hive type ID `0` and stores the saved drive plus its
  `RoutePoint` list.
- `RoutePoint` is Hive type ID `1` and currently contains latitude and
  longitude only.
- Existing boxes are `drives`, `career_totals`, `symbolic_routes`, and
  `drive_names`.
- Saves and deletes are performed through `DriveStorageService`. The new
  foundation does not alter either flow.
- No legacy World feature is connected to runtime. The home screen currently
  renders a static `YAKINDA` card, which remains unchanged.

### Phase 1 foundation

- `RoadMatchingProvider` is the provider contract. It contains no Mapbox,
  Google Roads, HTTP, or API-key implementation.
- `RoadMatchingService` converts a provider result into a versioned
  `ValidatedRoad` while preserving the originating `DriveSession.id`.
- `ValidatedRoad` keeps provider-independent geometry, provider metadata,
  confidence, validated distance, processing version, travel-order geometry,
  direction identity, and average heading.
- `WorldDriveProcessingRecord` persists the World processing state separately
  from `DriveSession`.
- `WorldPendingJob` uses `jobType:driveSessionId` as its deterministic key.
  `HiveMyWorldRepository.enqueueIfAbsent` therefore cannot create a duplicate
  logical job for the same drive and operation.
- The minimum valid World distance is defined once as `3000` metres in
  `MyWorldRules.minimumValidDistanceMeters`.

### Hive allocation

The new data is stored in separate boxes, so no `DriveSession` migration or
existing-user data rewrite is needed.

| Type ID | Adapter |
| --- | --- |
| 10 | `MatchedRoadPoint` |
| 11 | `RoadValidationStatus` |
| 12 | `ValidatedRoad` |
| 13 | `WorldProcessingState` |
| 14 | `WorldDriveProcessingRecord` |
| 15 | `WorldJobType` |
| 16 | `WorldJobStatus` |
| 17 | `WorldPendingJob` |
| 18 | `MatchedRoadSection` |

New boxes:

- `my_world_validated_roads`
- `my_world_processing`
- `my_world_pending_jobs`

Type IDs 10-18 are reserved for this feature and must not be reused.

### Verification

- Phase 1 tests: 5 passed.
- Full Flutter test suite: 31 passed.
- `flutter analyze`: no new Phase 1 issue. Five pre-existing `info` findings
  remain in `home_screen.dart`, `map_screen.dart`, and `route_preview.dart`;
  they were not changed because they are outside this phase.

### Ready for Phase 2

The provider boundary, persisted validated-road representation, processing
state, retry metadata, deterministic job identity, versioning, and rebuild
reference to the original drive are ready for a real provider integration.

Intentionally not implemented in Phase 1: map UI, Mapbox requests, a concrete
road provider, a retry runner, Drive Score, record ownership/comparison,
100/500 metre analysis, World index records, and neon animation. No production
score mock or fake provider was added.

## Benim Dunyam v2 - Phase 2 walkthrough

Phase 2 adds GPS preprocessing and the real Mapbox Map Matching provider. It
still does not add a World map, neon rendering, Drive Score, record ownership,
local performance segments, a World index, multiplayer, or an automatic
backfill of old drives.

### GPS preprocessing

Only the latitude and longitude values that actually exist in `RoutePoint` are
used. Invalid/non-finite coordinates split continuity, consecutive points less
than 3 metres apart are removed, and a gap over 500 metres starts a new trace
instead of being connected as a road. The 3 metre value matches the current
recorder's useful-distance threshold. The conservative 500 metre split avoids
claiming continuity that cannot be proven without timestamps, accuracy, or
speed. Those missing telemetry fields remain a future map-matching quality
limitation; `DriveSession` and `RoutePoint` were deliberately not migrated.

All tuning values live in `MyWorldRules`. Clean traces are chunked at Mapbox's
100-coordinate limit with a deterministic 3-point overlap. Matched overlap is
removed when adjacent chunks are merged. Failed or disconnected chunks remain
separate `MatchedRoadSection` records and are never flattened into a fake
continuous road.

### Mapbox provider

`MapboxRoadMatchingProvider` is behind the Phase 1 `RoadMatchingProvider`
contract. It calls the `mapbox/driving` Map Matching v5 endpoint with an HTTP
POST form, requests full GeoJSON geometry, supplies a 25 metre matching radius,
and maps provider JSON into provider-independent domain models. The radius is
within Mapbox's documented 0-50 metre range and is conservative because the
saved `RoutePoint` no longer contains its original accuracy.

The provider safely classifies missing-token, timeout, network, authentication,
rate-limit, server, malformed-response, invalid-input, and Mapbox API failures.
Confidence is stored only when Mapbox actually returns it; no confidence value
is invented. Geometry order is preserved so opposite travel directions remain
distinguishable in later phases.

The access token is read only from a Dart define and is never stored in source:

```powershell
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN
```

Release builds use the same define:

```powershell
flutter build apk --release --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN
```

Without a token, validation becomes retryable/pending and the normal saved
drive remains untouched. The token and individual coordinates are not logged.

### Validation, eligibility, and persistence

The valid distance is calculated from Mapbox-matched road geometry, never from
the raw GPS total. A validated distance below 3000 metres becomes
`rejectedInsufficientValidDistance`; 3000 metres or more becomes
`readyForWorldProcessing`. Phase 2 intentionally stops there and never marks a
drive `processed`.

Retryable errors retain one deterministic `validateRoad:driveSessionId` job.
`retryValidation` can safely run it again. A current validated road for the
same provider and processing version suppresses another API call. Hive cannot
transaction across boxes, so the durable write order is validated road,
processing state, then job marker. If interrupted, the next validation sees
the current road and repairs state/job without calling Mapbox again.

Newly saved drives are only enqueued after `DriveSession` persistence succeeds.
No network call occurs in the save path, and any World queue error is isolated
from the successful drive save. Existing drives are not automatically sent to
Mapbox; controlled backfill remains a later phase to avoid surprise API cost.

### Phase 2 verification

- Phase 1 and Phase 2 focused tests: 23 passed. They cover preprocessing, invalid coordinates,
  jump splitting, chunk overlap, POST parsing, partial matching, response/error
  classification, distance, direction order, 2999/3000 metre eligibility,
  retry idempotency, cached validation, and save isolation.
- Full Flutter test suite: 49 passed.
- `flutter analyze`: no Phase 2 warning or error. Five pre-existing `info`
  findings remain in `home_screen.dart`, `map_screen.dart`, and
  `route_preview.dart`.
- Production code contains no fake Mapbox provider or fake Drive Score.
- Mapbox contract references:
  `https://docs.mapbox.com/api/navigation/map-matching/` and
  `https://docs.mapbox.com/api/navigation/http-post/`.

Intentionally not implemented in Phase 2: map UI, neon drawing/animation,
Drive Score, record comparison, common-road analysis, 100/500 metre local
analysis, World ownership/index, automatic retry runner, old-drive backfill,
and DriveIt Gezegeni.
