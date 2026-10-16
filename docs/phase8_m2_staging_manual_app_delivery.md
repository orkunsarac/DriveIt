# M2 staging cancellation — normal A55 client update

Date: 2026-10-15. Base checkpoint: `c2e68bffd67e442bf9e1261666d5f9bb3da078f9`.
The small manual-retry correction is local/uncommitted; no commit/push occurred.

## Manual-only safety correction

Normal production composition now sets `automaticCloudDeletionRetry: false`.
The dependency/bootstrap forwards it to the owner lifecycle. Startup, resume
and owner reopen cannot schedule pending real deletions. Existing M1 automatic
upload remains disabled. This supersedes the earlier rollout notes suggesting
bounded automatic deletion retry after a phone update.

History shows **Silme isteğini yeniden dene** for a pending deletion. It reuses
the existing confirmation and consent-preserving deletion method. No queue
clear, new source identity, invented telemetry or successful local-only ACK is
introduced. A valid cancellation/tombstone receipt is still required before
History removal. Guest and Device Archive remain outside cloud deletion.

## Checks and installation

- Relevant existing Flutter unit/widget/bootstrap suites: **67/67 passed**.
  Manual mode test preserves the exact pending consent across resume/A-B-A and
  completes only after an explicit call. Existing cancellation/replay/empty
  telemetry/owner isolation tests pass. Bootstrap flag forwarding is asserted.
- Analyze: existing **3 warnings + 4 infos**, exit 1, no new finding.
  `git diff --check` passes. No new Android instrumentation framework/test.
- Built with `tool/build_normal_auth_dev_release.ps1`, ignored Planet DEV
  public URL/publishable configuration, owner/M1/M2 flags. No remote API write,
  migration, Edge redeploy or backend acceptance rerun occurred.
- Normal package `com.example.driveit_project`, release/AOT, debuggable=false,
  versionCode **1**, versionName **1.0.0** (same code, no downgrade).
- Native owner marker=true; isolated test marker=false. The actual AOT binary
  contains the new manual-retry label. APK scan found no PAT/secret-key pattern
  or service-role JWT; build configuration permits only public Auth values.
- Certificate SHA-256 matches the existing device APK:
  `0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`.
- APK SHA-256:
  `A8DC81CCB0BF0771CADB3D6A9B0BE2EC8B6F79156DCD5CB8F6EA0898D68E0BBA`.
  Size **90,300,722 bytes**. Preserved artifact:
  `tmp/diagnostic_acceptance/m2-phone-manual/driveit-m2-staging-manual-release.apk`.
- A55 serial `R5CX42V8GSJ` was online. Immediately before install, no DriveIt
  process or package service was running. Existing package/version were checked.
  Only `adb install -r` used; result **Success**. Installed APK was pulled back
  and its hash/certificate matched exactly. Normal Activity resumed; current
  PID logs had zero fatal/ANR/unhandled-exception indicators.

## User acceptance still pending

No real queue/private database was opened or modified by diagnostic tooling.
No upload, delete, GPS recording or sharing was initiated. This is installation
and startup evidence, NOT proof that the user's pending deletion has completed
or that every stored record has been manually inspected.

User: open **Sürüşlerim**, choose only the existing pending test drive, press
**Silme isteğini yeniden dene**, review and confirm the cloud deletion warning.
After a verified receipt, check disappearance and persistence after reopening;
also check that the earlier successful cloud drive remains. Do not select that
successful drive for deletion. Network failure must leave pending status.

Zero telemetry (`finalSequence=0`, telemetry=0, route=0) remains an unresolved
separate recording issue. Its local-only upload guard is retained. No GPS
algorithm or backend schema changed in this client-update task.
