# M2 normal-app cloud deletion activation

Date: 2026-10-15. Base checkpoint:
`79fa6ed0d798f91bde30dccca238f15c14108599`.
Auth and sync target remains Planet DEV `viqngnjfgknpxtoapzcg` only.

## Narrow activation

The existing production dependency factory now passes M2 activation only when
both `DRIVEIT_ACCOUNT_SYNC_ENABLED` and `DRIVEIT_ACCOUNT_DELETE_ENABLED` are
explicitly true. The existing normal Auth release helper supplies both flags,
plus the existing owner activation flag, to config-only and release builds.
Default/M1-only builds remain deletion-disabled. No fake Auth, isolated runtime,
new backend, server change or new test framework was introduced.

The existing History delete route and owner-aware persistent deletion client
are reused. Account-owned cloud evidence triggers the explicit warning:
“Bu sürüş hesabınızdan ve senkronize cihazlarınızdan silinecek.” Cancel sends
nothing. Consent is durably recorded before network work. Offline failure keeps
the drive locally and displays pending status; only validated server ACK applies
the local deletion. Repeated attempts retain the deletion UUID and mutation.
Existing source tombstones prevent re-import/resurrection on later downloads.
Guest and Device Archive are outside M2. World/Career contributions are not
deleted by History deletion.

M1 uploads/downloads remain explicit and selected-drive based. No startup,
resume or Save upload batch is enabled. Resume/startup retries only already
consented deletion rows, at most four, stopping at the first transport failure.
No existing real drive was selected, uploaded or deleted in this task.

Existing owner epoch, source identity, device/session lease, 30-second heartbeat
and three-minute server expiry remain unchanged. HTTP 409 `lease_fenced` maps to
`OwnerSyncConflict`, with no unbounded transport retry or bypass. Manual upload
uses the existing persisted device/session binding to acquire current lease
evidence. A conflicting live lease remains a conflict. Owner change stops the
heartbeat and rejects late results. Android background heartbeat is not physically
accepted and no background service was added.

## Verification and delivery

Existing tests cover explicit consent/cancel, pending/offline retry, ACK/replay,
cursor anti-resurrection, A/B/Guest isolation and M1 transport. Two assertions
were added to existing test files: production M2 requires both build opt-ins;
the real adapter maps a synthetic 409 lease_fenced to conflict with one request.
No real-user deletion or Android instrumentation test is run.

Results:

- Targeted existing tests with both production M1/M2 defines: **59/59**.
- Full Flutter regression: **991 passed, 2 conditional skips**.
- Analyze: existing **3 warnings + 4 infos**, exit 1; no new M2 finding. Three
  warnings are in untouched archive integration tests; four infos are existing
  Home/map/route-preview findings. Build helper parser: zero errors.
- `git diff --check` passes. No commit/push was performed.

Normal APK: `build/app/outputs/flutter-apk/app-release.apk`, **90,300,722 bytes**.
SHA-256: `1BCA712939A58BCAFA976116C6CCEB406EB83252F282F461AFEE749DC0AD7641`.
Package `com.example.driveit_project`, versionCode 1 / versionName 1.0.0.
Fresh release build, ARM64 ELF AOT library present, debuggable/testOnly absent.
Native `driveit.local_owner_runtime=true`, `driveit.isolated_owner_runtime=false`.
The actual guarded build supplied owner, M1 sync and M2 deletion defines true.
Factory and build helper source paths were verified; fake Auth/GPS were not used.
Exact Planet DEV URL and configured publishable key were found in AOT without
printing the key. No PAT/secret-key prefixes were detected in the AOT scan;
the guarded build config permits only the public URL and publishable key.

APK certificate SHA-256:
`0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`.
This matches the installed application's existing development signing key;
release build mode is not a claim of a new production signing identity.

A55 `R5CX42V8GSJ` was connected. Before installation there was no package
process and `dumpsys activity services` reported no service. No active recording
or sharing producer was present; private journal/recovery data was not opened.
Installed only via `adb install -r`: **Success**, with no uninstall, clear,
force-stop, downgrade or data reset. MainActivity was launched normally and
became top-resumed. A read-only copy of the installed public APK has the exact
same hash as the validated build. Recent logs for both reported package PIDs
contained zero fatal/ANR indicators. This is a startup check, not prolonged
physical acceptance or proof of every stored drive's integrity.

No user account was created or signed in by automation; no GPS sharing, new
drive, upload/download selection or deletion was triggered. Existing data was
not moved/merged; normal user manual verification is pending.

## Manual acceptance boundary

The user will create a NEW disposable account drive, manually upload it, then
delete that new drive through History and confirm the cloud deletion warning.
The pre-existing real cloud drive must remain untouched. Offline deletion may
remain visibly pending until a successful server ACK. Other devices converge
on their next explicit download, not automatically via Realtime.

Permanent logical tombstones do not erase finalized private Storage bytes or
World/Career evidence. Physical retention/purge, M3/M4 and multi-device manual
acceptance are outside this rollout. Existing uncommitted Android/config work
and local data are preserved.
