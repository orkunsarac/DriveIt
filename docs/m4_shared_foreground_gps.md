# M4 shared foreground GPS candidate

Base: f8c87fd07bbb3b294c8adc0659cdd4d83d6a237d.

This implements approach B described in `m4_background_gps_feasibility.md`.
It is a release candidate; physical screen-lock delivery is not accepted yet.

## Producer and consumers

The existing flutter_foreground_task service (notification ID 100) and
DriveTaskHandler own one Geolocator subscription. It has no Geolocator
foregroundNotificationConfig, so there is no second Geolocator FGS consumer.

Recording demand retains the existing owner bootstrap descriptor, journal v3,
GPS supervisor, telemetry writer and durable drain/finalization receipt. Group
demand reads only live positions and sends an ephemeral Position map over the
existing isolate port. No journal session or DB is opened for group-only task
startup. Group coordinates, Auth tokens and group grants are never written to
the task preferences.

- Neither demand: no GPS subscription; stop the service.
- Recording only: the existing journal writer consumes the stream.
- Group only: IPC consumes the stream; no journal is created.
- Both: one subscription feeds the writer and the independent group IPC.

Recording can attach to a running group-only task after the existing owner
descriptor is durably written. Its acknowledgement includes the exact session
ID. Stop drains the recording writer before clearing only its demand. Group
detach acknowledges whether recording still needs the service; the UI must
not stop the service on a missing/malformed acknowledgement. Native lifecycle
start/detach operations are serialized in ForegroundService.

## Publication and authorization

GroupDriveSession belongs to OwnerPersonalNavigator, not GroupDriveScreen.
Leaving the page retains an actively consented session; owner invalidation
closes it. The screen observes the same client and GPS controller on return.

Only the explicit background checkbox and a BackgroundGroupGpsSource allow
continuation through hidden/paused. The checkbox defaults off on every new
start/resume. Detached state still revokes publication. Start requires a
resumed Activity, location permission and notification permission. Notification
permission is also rechecked during sharing. No background-location request
or permission expansion was added.

The task receives an unpredictable in-memory subscription token, renewed
every two seconds. It expires after ten seconds without renewal. The UI also
checks task acknowledgements and fails sharing if the task stops responding.
A recreated group-only task opens neither a journal nor GPS and stops after
its startup grace period if no new user-initiated demand arrives. No token or
demand is restored from disk.

The Android FGS keeps the application process active; the UI isolate retains
the real authenticated Supabase client. GroupGpsSharing retains all current
owner/grant/sequence/mock/75m/15s/timestamp checks. The task sends only live
samples to that controller. This avoids storing Auth credentials in service
preferences or creating a second persistent Auth session.

The existing Supabase Flutter SDK still disconnects its receiving WebSocket
while paused. Outbound group publication uses the accepted Edge HTTP endpoint,
which broadcasts to the other foreground device. Existing five-second group
refresh polling and the minimum ten-second heartbeat interval remain unchanged
(a renewal can fall on the third five-second poll). Before HTTP operations,
the group adapter explicitly refreshes an expiring real Auth session, validates
the same UID and owner lease again, and fails closed on refresh failure. The
default client resumes its receiving Realtime socket through its SDK lifecycle.
No server changes were needed.

No assertion that timers/network survive device-specific background limits is
made from host tests. If Android destroys the UI engine, the ephemeral demand
expires; background publication is not silently restarted. Source/task loss,
permission loss, membership/grant revocation and transport failure stop group
sharing without making recording depend on the group transport.

## User control

The persistent notification reads `DriveIt • Grup konumu paylaşılıyor`. When
recording also runs, its text identifies both operations. Tapping the
notification opens the current owner's group route via the existing IPC/app
launch mechanism; Pause/Stop remain the revocation controls. No biometric or
screen-lock bypass is introduced. A restarted application never restores a
group sharing grant automatically.

## Required first physical acceptance

Normal recording OFF. On the group page, explicitly select background sharing
and start sharing. Confirm the Android foreground notification. Keep the
second real device in the foreground in the same group. Lock the first phone
and verify continuing new markers on the second for at least one minute,
including heartbeat renewals. Unlock, Pause and verify updates cease. Do not
accept simultaneous recording from this check; independent-stop physical tests
are a separate next acceptance after this one passes.

No real user sharing is started by automation. No migration, deploy, APK
installation, commit or push is performed implicitly by this document.

## Validation and release artifact

- Existing plus added foreground/group host tests passed. The final full
  `flutter test --timeout=2m` run passed 1043 tests with two conditional skips.
- The tests execute DriveTaskHandler, its real isolate-port/static service
  bridge, independent attach/drain/detach paths and real SQLite writer, with a
  synthetic platform GPS and mocked native service methods. Group-only mode
  opens no journal. Recording bootstrap failure preserves group samples.
- Consent/background lifecycle, route disposal/reopen, permission and owner
  revocation, expiring ephemeral demand, fresh-engine non-restoration, real SDK
  envelope decoding, explicit token refresh and HTTP heartbeat tests passed.
  These are host results, not Android screen-lock delivery acceptance.
- Analyzer: unchanged three existing integration-test warnings and four infos;
  no new issues. `git diff --check` and build-script PowerShell parsing passed.
- Normal release/AOT APK built successfully; package
  `com.example.driveit_project`, versionCode 1 / versionName 1.0.0, target SDK 36,
  no debuggable flag, isolated runtime false and local owner runtime true.
- APK: `build/app/outputs/flutter-apk/app-release.apk`, 91398666 bytes.
- SHA-256: `0E6FAF1ED622980AEAB12B748B3247AC39D2FBC95197C9F02B90E49E531731C0`.
- Signing certificate SHA-256:
  `0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`, matching
  the previously accepted certificate. Live installed-package verification
  remains pending because A55 was absent from `adb devices -l`.
- No device installation or GPS publication was performed. The first physical
  acceptance described above and notification navigation on A55 remain open.
