# M1 normal app — controlled manual sync

Date: 2026-10-15. Normal Auth/backend target remains Planet DEV,
`viqngnjfgknpxtoapzcg`. No server migration/deploy was performed in this task.

## Checkpoint

Verified M1 deployment sources, the deploy script and acceptance report were
committed/pushed as `481607ddcb63b5374e247434d6e4654120b05c48`.
`git ls-remote` matched that exact HEAD. Only four M1 files were staged;
unrelated Android test work, local configs, backup data and APKs were excluded.
The new manual-client changes below remain local for review.

## Normal runtime and UI

The existing production factory supplies the real
`SupabaseOwnerDriveSyncAdapter` using the existing Planet Auth client/UID.
`DRIVEIT_ACCOUNT_SYNC_ENABLED=true` now selects this adapter in the normal
Auth release helper. It does NOT enable automatic sending:
`automaticAccountSync=false` is explicitly passed by the production factory
through the existing bootstrap. Startup/resume/Save cannot invoke the real
worker or download. Existing crash-gap/local outbox reconciliation is retained.

Normal Home → Profile (`ProfileSettingsScreen`) → Bulut Senkronizasyonu
opens `/cloud-sync` on the existing owner navigator. Opening the page makes
no sync network request. Guest sees an explanation and disabled controls.
Account sees read-only eligible local candidates, pending count and durable
ACK status. Only completed, durable, proven, non-deleted account drives are
eligible; Guest, legacy archive and sync-imported replicas are excluded.

Every upload requires selecting one row and confirming that its route,
telemetry and details will be sent. Only that outbox operation is sent; no
queue drain or hidden batch follows. Repeating an acknowledged operation
reuses its durable identity/ACK. Offline failures retain both drive and outbox.
Same-owner simultaneous manual operations are rejected rather than raced.
Network waits occur outside the local write barrier; local Save and Auth
revocation are not blocked by a delayed request.

Explicit connection check verifies the deployed owner-bound M1 capabilities.
Explicit download fetches at most one owner-bound cursor page. New drives use
the existing id mapping/import recovery. Existing local drive/telemetry/score
rows are not re-put: an exact canonical match is a duplicate, changed contents
fail closed. Cursor commits only after successful apply. Local History
tombstones remain suppressed. No fake data or missing provenance is invented.

The page explicitly warns: deletion is local-only; cloud/multi-device delete
is not supported. Upload already committed remotely is not undone by a local
delete. No M2/M3/M4 backend, Planet publishing or Group backend was activated.
Guest/Auth sessions, archive authorization and normal GPS/journal are unchanged.

## Validation

- Existing four targeted client/adapter/owner/navigation suites: 57 passed.
- After adding the unflushed-completion exclusion: sync suite 14 passed.
- Final full Flutter regression: 980 passed, two conditional skips.
  Skips: isolated Android define not supplied; Windows symlink capability.
- Final analyze: the existing three Android-test non-null assertion warnings
  and four existing info findings remain; zero new findings in this delivery.
  Analyze exits 1 because those existing warnings were not suppressed.
- git diff --check passed. No new instrumentation or test framework was added.
- Tests cover no automatic upload on start/resume, exactly one selected drive
  despite another pending row, offline/retry/ACK/no duplicate, Guest denial,
  A/B switching, stale result rejection without blocking a local write, zero
  protected storage writes on matching download, durable-source eligibility,
  and normal Profile navigation/old Guest route revocation.
- These new Flutter tests use synthetic data/mock transport. The previous
  real Planet DEV Deno E2E result remains in phase8_m1_planet_dev_deployment.md;
  no real user's upload was triggered by this task.

## Build and physical update

The normal helper validates the ignored public-only Auth config and uses a
release configuration pass before release compilation. It selects local owner
activation plus manual account sync, never an isolated test entrypoint.
Installation metadata and physical result are recorded below after validation.

### Verified normal APK and update

- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Bytes: 90186034
- SHA-256: `0A1AF4BFADCD355699E32B763D7ACF5F8814B43B7AD0B003A1873405261324E9`
- applicationId: `com.example.driveit_project`
- versionCode: 1; versionName: 1.0.0 (installed prior versionCode was also 1).
- release/AOT arm64 libapp.so present; debug kernel absent; debuggable=false.
- Native local-owner marker=true; isolated-owner marker=false.
- AOT contains the manual cloud UI, real Supabase adapter and Planet project.
- Only the ignored public URL/publishable-key config is supplied. A binary
  scan found no PAT/server-secret key patterns; no privileged key was supplied.
- Certificate SHA-256:
  `0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`.
  This is the existing Android Debug test signing certificate, not a Play
  release key; the APK itself is release/non-debuggable. It matches the
  installed app, allowing a same-version in-place DEV update.

A55 R5CX42V8GSJ was authorized/device. Immediately before install, no app
process or recording foreground service was present. The previous installed
APK signature and unchanged bytes were checked. Update used ONLY adb install
-r and returned Success. No uninstall, clear, downgrade or force-stop occurred.

Normal MainActivity cold launch returned Status ok (1685 ms), versionCode 1,
debuggable flag absent. Installed APK SHA-256 exactly matches the new artifact.
Initial main-process fatal/Flutter error scan found zero matching errors.
After launch, only the bound Geolocator helper appeared, not a recording FGS;
no drive or sharing action was performed.

The final screenshot showed the PHONE LOCK SCREEN. Thus Android Activity
launch is verified, but unlocked normal Home/Profile visual acceptance was
not inferred from that screenshot. The user was asked to unlock normally;
no lock/PIN bypass was attempted. Widget route/render acceptance is separate
from the pending physical visual/first-upload acceptance.

No real user's upload/download/check-connection was triggered by the agent.
No account was created or signed in by the agent. Guest/account selection and
local data remain managed by the existing owner runtime without merge/reset.

## User's next manual acceptance

Unlock normally, open DriveIt, use your real Planet DEV account, then choose
Profile → Bulut Senkronizasyonu. Check pending local drives; select ONE newly
saved account drive, press Yükle and explicitly confirm. Confirm its durable
ACK status, then retry that same row to verify no duplicate operation. Other
rows must remain pending. Download is separately explicit, at most one page;
existing local records are preserved. Do not expect cloud deletion or
cross-device World/Career/group synchronization from M1.
