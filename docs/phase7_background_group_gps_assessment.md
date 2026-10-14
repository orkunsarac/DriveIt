# Phase 7 — Independent background group GPS assessment

Date: 2026-10-12
Branch: `feature/gps-refactor`
GPS visible-app checkpoint: `0231ccff89cb40d13a30c7747a7814a4ea8696f8`

## Decision

**Background-sharing implementation stopped before changing foreground-service code.**
The existing recording foreground task is bound to a SQLite drive session and its
shutdown path drains that session and stops the Android foreground service. A group
location consumer cannot use it without changing the task's ownership and shutdown
contract. A standalone group location FGS would require a second Android service plus
permission, notification, isolate communication, process recovery, and arbitration against
the current plugin service. That is not a small lifecycle adjustment. The request directs
us to stop if both choices require a large refactor, so no service change was made.

## Checkpoint completed

The previously tested visible-app GPS integration was committed and pushed first:

`0231ccff89cb40d13a30c7747a7814a4ea8696f8` — `Add Android GPS group sharing (background acceptance pending)`

Local and `origin/feature/gps-refactor` HEADs matched after fetch. Ten scoped source,
test, and report files were committed. `tatus`, `android/build/`, and the unrelated
pre-existing audit document were not staged. The checkpoint does not represent background
acceptance. Production ownership gate is still disabled.

## Service coupling evidence

- The app manifest declares the Pravera `ForegroundService` with `location` type. Its
  plugin setup starts service ID 100 and supplies the recording task callback.
- `DriveTaskHandler.onStart()` requires an active SQLite journal session; it opens/restores
  that session's writer before consuming position updates. There is no group-only start mode.
- `ForegroundService._stopRecording()` requests a journal drain, checks the durable stopped
  state and final sequence receipt, then calls `FlutterForegroundTask.stopService()`.
  Calling that path to stop group sharing would stop drive recording too.
- The pinned `flutter_foreground_task` package declares one Android `ForegroundService`
  component. A second group consumer needs explicit task/notification/service lifetime
  ownership. Merely calling Geolocator from the visible UI does not keep it alive in the
  background.
- The visible-app path added in the preceding checkpoint uses Geolocator directly, starts
  only after consent and while resumed, and pauses/withdraws on background or screen lock.
  It has no journal writer and does not stop the recording FGS.

The app targets API 36 and already declares a location FGS type and corresponding service
permission. Android 14+ requires the location type and runtime location permission;
Android 14–16 also enforce while-in-use and background FGS start rules. A valid design must
start from the visible consent action and maintain the foreground notification. The exact
remaining work is lifecycle/consumer composition, not merely adding a manifest permission.
See [Android location FGS requirements](https://developer.android.com/develop/background-work/services/fgs/service-types),
[background start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start),
and [Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-all).

## Mode matrix

| Drive recording | Group sharing | Current behavior |
|---|---|---|
| OFF | OFF | No group GPS subscription; no drive recording FGS required. |
| ON | OFF | Existing recording FGS and SQLite writer run. |
| OFF | ON, app visible | Consent-gated Geolocator subscription feeds the local fake group; no drive session/journal is created. |
| ON | ON, app visible | Independent group subscription and drive FGS coexist; stopping either consumer leaves the other intact in host tests. |
| Either | Group requested in background | Group publication is withdrawn and acquisition stops. It does not auto-resume on foreground return. Drive recording retains its own service/session behavior. |

Thus group-only **background** sharing, the new target, is not implemented. The two visible
group combinations and drive-only behavior have host evidence; Android device behavior is
not inferred from those tests.

## Preservation and privacy evidence

The checkpoint tests exercise the visible group source through the actual group UI and fake
map/service. Group points remain out of the recording journal. A recording session survives
group pause; drive stop/save does not stop the group consumer while the UI remains visible.
Owner epoch, membership/publication grant, permission, location age/accuracy, and callback
generation checks reject stale publication. Restart does not persist a grant or coordinates,
so no group stream can auto-start after process death.

There is no real Supabase/Realtime send, production gate activation, journal v3 migration, or
real user data operation. Android runtime permission is app-wide: revoking it also affects
the drive's ability to receive GPS. The group controller never revokes the Android
permission itself.

## Verification state

Before checkpoint: 36 targeted tests passed; full Flutter suite reported 944 passed,
2 conditional skips, 0 failures. Analyze reported only the four prior info findings.
`git diff --check` passed. The two skipped host cases are the isolated-Android Supabase
guard (compile-time define required) and Windows symlink fixture (host cannot create it).

After checkpoint, read-only `adb devices -l` returned an empty device list. No Android
APK was installed, no physical acceptance was performed, and no native test is counted as
passed. A55 acceptance remains open for actual foreground notification, device permission,
lock/background, process-death, and simultaneous drive/group service behavior.

## Not completed

- Group-only background location FGS and visible persistent stop notification.
- Sharing that continues while the app is backgrounded/phone locked.
- A shared foreground task that runs independent drive and group consumers and stops only
  the requested one.
- Physical A55/API 36 acceptance.
- No code for these was attempted in this assessment; no foreground edits were committed.
