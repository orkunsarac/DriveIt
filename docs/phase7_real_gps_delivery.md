# Phase 7 — Android GPS to local fake group

## Scope and decision

Map/sharing checkpoint: `eea2241669ae5caece86145ba9f6ff2422efa861` (local and remote HEAD verified).
The following GPS changes remain uncommitted. Production ownership remains disabled.

**Delivery: PARTIAL.** A controlled visible-app Android GPS path is implemented;
background group sharing and physical Android acceptance are not completed.
No real network publication, real user data, new FGS, journal migration, or backend activation.

## Architecture evidence

- `ForegroundService.start()` creates/attaches a recording session; `DriveTaskHandler.onStart()`
  requires an active journal and initializes the recording writer.
- `ForegroundService._stopRecording()` drains recording writes and calls
  `FlutterForegroundTask.stopService()`. It has no independent group consumer lifetime.
- Reusing that service for group-only background GPS would currently start a drive or
  make drive stop terminate group sharing. An independent consumer protocol plus isolate
  communication would be necessary. This delivery does not silently add it or a second FGS.
- `AndroidGroupGpsSource` reuses Geolocator foreground permission and stream APIs, with
  best-navigation/zero-distance/500 ms settings matching the recording producer. It does
  not supply Geolocator foreground notification configuration or call the recording service.
- The cached Geolocator Android implementation stops a handler's own `locationClient`;
  the Dart position stream is broadcast. Cancelling the group's listener is not a call to
  the DriveIt recording service's stop operation. Physical simultaneous-stream acceptance
  is still required; host tests alone do not prove Android plugin lifecycle behavior.

Android target SDK is 36. A background location FGS requires `location` service type,
`FOREGROUND_SERVICE_LOCATION`, enabled location, granted coarse/fine runtime permission,
and compliance with while-in-use/background-start restrictions. A visible-app-started FGS
can support background use under the applicable rules; Android does not categorically forbid
background sharing. The limitation here is the existing DriveIt service composition.

Official references:
[Location FGS requirements](https://developer.android.com/develop/background-work/services/fgs/service-types),
[background start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start),
[Android 16 changes](https://developer.android.com/about/versions/16/behavior-changes-all).

## Controlled real GPS selection

Pass `groupGpsSourceFactory: () => AndroidGroupGpsSource()` to the existing
owner navigator's explicitly supplied fake group route, or inject that source directly
into `GroupDriveScreen`. No production bootstrap supplies this source automatically.
Null source preserves the existing synthetic UI. The Android source opens no stream
until the user approves the explanation and the permission check succeeds.
Host tests inject fake GPS through the same navigation/source/controller boundaries.

`GroupLocationPoint` separates synthetic and device-GPS origins; old synthetic APIs remain
compatible. The actual source feeds `GroupGpsSharing` → `GroupDriveClient.publishGps()` →
the existing in-memory fake group → Google Maps marker. Only authorized current members
can read/publish points. Device data is not represented as synthetic data in the map.

## Privacy and lifetime

- Default OFF; consent precedes permission requests. Foreground permission denial or
  disabled location prevents start. No background-location request is added.
- Per-sample permission checks and a bounded two-second monitor revoke publication after
  permission/service loss. Checks time out after five seconds; no blind stream retry.
- Positions must be finite/in bounds, not mocked, not future/cached-before-consent, no older
  than 15 seconds, accuracy at most 75 m, and strictly newer than the previous timestamp.
  These are group-publication filters, not a modification of the drive filter/Score.
- Pause/stop clears the fake service point synchronously and cancels the group's subscription.
  Resume needs another interaction/consent. Group membership, publication token, owner epoch,
  and local request generation fence late callbacks.
- Leave/end/expiry and owner invalidation cancel local acquisition when snapshots/lease update.
  Background/lock pauses; returning to the foreground does not restart. Process/reboot stores
  no sharing grant or coordinates and cannot automatically resume.
- Only the latest pending sample is held, not a route/history. Coordinates are not persisted
  to Hive, GPS journal, sync outbox or logs by this publisher.
- Android location permission is application-wide. If a user revokes it while recording,
  normal drive GPS is also affected; the group code cannot promise otherwise. It does not
  revoke permission, stop the recording service or delete the journal.

## Files

- `lib/features/group_drive/group_gps_source.dart`: actual Android permission/provider adapter.
- `lib/features/group_drive/group_gps_sharing.dart`: consent/epoch/lifecycle publication controller.
- `group_drive_models.dart`, `group_drive_service.dart`: typed GPS sample and existing fake publication fences.
- `group_drive_screen.dart`, `group_drive_map.dart`: real-source consent/status/map integration.
- `lib/widgets/owner_personal_navigator.dart`: explicit controlled source selection.
- `test/group_gps_sharing_test.dart`, `test/group_drive_ui_test.dart`: source/service/navigation tests.

## Acceptance evidence

Targeted tests: **36 passed**. Tests cover denial/no consent, validation, pause/resume,
permission loss, owner callback race, background/restart default, group end/leave/expiry,
stream failure without automatic reconnect, and adapter
settings. A real Home → group → consent → injected GPS → fake service → GoogleMap widget
test passes. An initial UI test failure used an illegal Flutter lifecycle transition;
the fixture now follows resumed → inactive → hidden → paused and its reverse, without sleeps
or changed application policy.

The normal recording fixture uses `ForegroundService.start()`, preserves the active session
while group GPS is paused, confirms group points do not enter the journal, and saves a
301-point recording with one sync operation. Stopping recording does not cancel group GPS.
Native channels/GPS are fake in this host test; it is not physical foreground acceptance.

Full regression/analyze/diff results are recorded below after completion.
Final code: `flutter test --timeout=2m --no-pub -r expanded` completed in 1m32s:
**944 passed, 2 skipped, 0 failed**. Before adding the last two privacy regressions,
the complete package also passed 942 tests with the same two skips.
`flutter analyze --no-pub`: only the four pre-existing infos, no errors/warnings/new infos
(tool exits 1 because infos are present). `git diff --check` passed. New untracked
source/test/report files also passed whitespace checks. The staging index is empty.
Local/remote HEAD remains `eea2241669ae5caece86145ba9f6ff2422efa861`.
Existing `tatus`, `android/build/` and the pre-existing untracked audit document were
neither staged nor changed by this delivery.
The two existing conditional skips are the isolated-Android Supabase bootstrap guard
(requires its explicit compile-time define) and the synthetic poster symlink test
(Windows host cannot create the required symlinks). They are not native passes.

ADB device listing succeeded but was empty. No APK was built/installed, no A55 package,
real data, permissions or Supabase were touched. Physical acceptance remains open:
real permission dialog/denial/revocation, real GPS freshness, lock/background pause,
simultaneous recording/group subscriptions, and independent cancellation on Android 16.

## Remaining concrete gaps

1. Shared background FGS consumer lifetime/isolate handoff is absent; sharing intentionally
   pauses outside the visible app. Do not activate background tracking without resolving it.
2. The Android source is explicit controlled composition, not automatically activated production UI.
3. A55 native acceptance and earlier Phase 5 isolated-release acceptance remain pending.
4. Fake groups are process-local, not communication between users/devices. Real backend and
   remote withdrawal/expiry semantics are outside scope.

## Physical GPS diagnosis update — 2026-10-12

The isolated A55 run reached the integration `main`, binding, `testWidgets` body, Home →
Group screen, in-app consent, and Android location permission request. The user confirmed
granting the Android permission. The test then timed out waiting for a fake-group member
state containing a valid `deviceGps` sample. The test withheld coordinates by design.

This proves the flow advanced past test startup and permission request, but does **not**
prove whether Android emitted a provider callback, whether a sample was rejected by the
existing 15-second freshness / 75 m accuracy / timestamp / bounds checks, or whether a
publish reached the fake service. No filter was relaxed and no synthetic coordinate was
substituted for a physical fix.

A later single attempt through `tool/run_android_integration_test.ps1` produced no Flutter
test output and no completion result; it was stopped rather than retried. Test-only,
coordinate-free diagnostics were added for permission/provider state, stream callbacks,
filter decisions, lifecycle/owner fences, fake publish, and member read-back. Those
diagnostics have host coverage, but physical callback evidence remains unavailable.

**Physical visible-app GPS acceptance remains PARTIAL and open.** The independent group-only
background FGS remains a separate open acceptance item. No further Android test is planned
until the user explicitly resumes device acceptance. Production ownership remains disabled;
the real DriveIt package and user data were not targeted.
