# M4 background GPS: first controlled review

Baseline: `f8c87fd07bbb3b294c8adc0659cdd4d83d6a237d`,
`feature/gps-refactor`. Two-device foreground GPS acceptance was reported by
the user. It does not establish background GPS acceptance.

## Decision

Do not enable approach A with the currently locked dependency. No production
code, dependency, native configuration, APK or backend was changed in this
review. The user's explicit stop condition applies: A cannot currently meet
the independent drive/group stop requirement safely. This is an installed
plugin implementation limitation, not a claim that Android forbids two
location services.

Locked versions inspected: geolocator 14.0.3, geolocator_android 5.0.3,
supabase_flutter 2.17.2, and the existing flutter_foreground_task dependency.

## Concrete cancellation collision

The installed geolocator_android Java sources establish this path:

1. `GeolocatorPlugin.java:148-168` binds each Flutter engine to the same
   application's `GeolocatorLocationService` instance and passes its binder to
   that engine's `StreamHandlerImpl`.
2. `StreamHandlerImpl.java:127-143` distinguishes a foreground-notification
   stream from a direct stream only during startup. The foreground stream
   calls `startLocationService`; the direct stream creates its own
   `LocationClient` without incrementing the service's listener counter.
3. `GeolocatorLocationService.java:106-114` increments `listenerCount` only for
   the service-backed stream. With group FGS + normal drive direct stream,
   the service counter is therefore one, not two.
4. `StreamHandlerImpl.java:147-155` handles cancellation from either engine
   with the same `disposeListeners(true)` path. It does not check whether that
   handler started a foreground stream before invoking the service stop.
5. `GeolocatorLocationService.java:86-90` permits cancellation when
   `listenerCount == 1`; `:127-132` stops the service's current location client,
   and `:154-165` removes foreground mode and releases wake locks.

DriveIt's real recording path uses a direct Geolocator stream without a
foregroundNotificationConfig (`lib/services/task_handler.dart:130-136`). Its
`onDestroy` awaits `_gps.close()`; `GpsStreamSupervisor.close()` awaits
subscription cancellation (`lib/services/gps_stream_supervisor.dart:120-131`).
Thus stopping recording while a proposed group FGS is running would enter
the plugin path that stops the group producer as well. The group Dart stream
need not receive an onDone event when that native producer stops, so retaining
an active-sharing UI would also be unsafe.

This is source-level evidence. No real-device cancellation experiment was
performed, and no mock result is presented as physical proof.

## Other lifecycle work required by either approach

- `GroupGpsSharing._valid` requires resumed state and its lifecycle observer
  intentionally pauses on hidden/paused/detached. This remains correct for
  the current foreground-only feature.
- `GroupDriveScreen` creates its client and GPS controller and closes both
  when disposed. Background ownership must move to a lease-scoped runtime
  controller, with the screen observing it instead of owning the session.
- `supabase_flutter-2.17.2/lib/src/supabase.dart:256-318` disconnects the default
  Realtime WebSocket on paused/detached; `supabase_auth.dart:170-181` stops
  automatic refresh. Edge publication is HTTP (`_publishGps`), so the socket
  disconnect alone does not prove outbound publication stops. However, token
  lifetime, heartbeat and reconnect must be owned explicitly for a background
  session; keeping a widget alive is insufficient.
- The current group client polls every five seconds and refreshes the
  publication heartbeat no more often than every ten seconds. Those existing
  server grant/generation/fencing checks must remain in place.
- Geolocator's FGS notification ID is 75415; DriveIt's recording notification
  uses service ID 100. IDs do not collide. Geolocator's notification opens the
  application, but has no group-specific stop action. A runtime-owned stop
  control reachable from that notification is still needed.
- Geolocator's service returns START_STICKY. That does not itself recreate a
  Dart Auth session or publication grant. No restart persistence or automatic
  group consent may be introduced.

## Android boundary

Android supports user-initiated location FGS startup while an Activity is
visible, with location permission and the location FGS declarations. A group
feature should not request ACCESS_BACKGROUND_LOCATION merely to continue
such a session. The existing manifest already declares it for prior code;
this review neither adds nor requests it. Notification permission/visibility
must be checked before promising a visible persistent control.

References:
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/develop/background-work/services/fgs/changes
- https://pub.dev/documentation/geolocator_android/latest/geolocator_android/ForegroundNotificationConfig-class.html

## Minimum separate B implementation

This is a proposed next task, not implemented or physically accepted:

1. Reuse the existing flutter_foreground_task service/engine as the producer
   lifetime, with two independent revocable consumer demands: drive and
   group. Start from visible explicit consent; keep the native producer only
   while at least one demand exists. Do not restart group demand after process
   death, reboot or package update.
2. Preserve the existing journal writer, sequence and finalization contract.
   Only the drive demand writes GPS to SQLite. Drive stop drains/finalizes that
   writer and releases only drive demand; it must not stop a group-only
   producer. Group stop releases only group demand and clears its ephemeral
   data. Group samples are never reconstructed from saved drive routes.
3. Give the group consumer an in-memory Auth/owner/membership/publication
   capability with epoch and generation checks, foreground-start provenance,
   explicit token refresh, existing heartbeat and fail-closed revocation.
   Reuse GroupDriveClient and the accepted Edge publication protocol. Do not
   persist GPS points or add a second backend.
4. Move group sharing ownership from GroupDriveScreen to the owner runtime;
   the UI and notification expose independent stop controls. On lost source,
   permission, Auth, membership or grant, stop the group demand and display
   failure. Do not revive it when returning to the app.
5. Use existing host tests for the four demand combinations and independent
   stops, then one controlled group-only screen-lock test with two phones.
   Accept simultaneous recording only after physical independent-stop checks.

B touches the producer's service lifetime and task bootstrap; it exceeds a
notification-setting patch and is intentionally not started here. An upstream
or narrowly maintained fix of the Geolocator cancellation ownership defect
could permit reconsidering A, but no plugin fork/upgrade was made implicitly.

## Acceptance status

- Current foreground feature: previously physically accepted by the user.
- Approach A group-only background behavior: NOT PHYSICALLY TESTED.
- Independent drive/group cancellation with A: blocked by the source path above.
- Background Realtime/token continuity, notification behavior and process-death
  behavior: NOT PHYSICALLY TESTED.
- No new APK was built or installed because the safety stop was reached before
  a candidate implementation. No active device session was interrupted.

Validation during this review: the existing `group_gps_sharing_test.dart`,
`supabase_group_drive_service_test.dart` and `group_drive_ui_test.dart` suite
passed 30/30. These cover consent, publication/grant revocation, the actual SDK
envelope callback, UI freshness and synthetic independent recording/sharing
behavior. They do not execute Geolocator's native cancellation implementation
and therefore cannot establish native FGS independence. `git diff --check`
passed. No full Flutter regression, Android build or device installation was
needed after the pre-implementation safety stop; only this report was added.
