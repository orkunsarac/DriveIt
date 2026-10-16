# M4 normal application activation

The normal Auth DEV release script explicitly enables
`DRIVEIT_GROUP_DRIVE_ENABLED`. The existing production factory constructs only
`SupabaseGroupDriveService`, only after Auth bootstrap succeeds and the URL
matches `https://viqngnjfgknpxtoapzcg.supabase.co`. Other builds remain disabled
by default. The owner navigator uses the existing group screen/map and the
Android GPS source. Guest can open the entry but cannot create a group client;
the screen requires an account. No group or GPS publication starts at bootstrap.

The accepted backend consists of migrations 202610160004/005 and
`phase8-group-publish` with JWT verification. This client delivery changes no
remote SQL, Edge function, Storage or Realtime configuration.

## Visible-app safety and errors

The existing GPS controller still requires consent, permission, a current owner
lease, valid membership and a visible application. Background/lock pauses GPS;
resumption requires another user action. No independent background group FGS
is included, and group samples do not enter the normal drive journal.

Realtime failure clears transient locations, displays an error and offers retry.
A failed channel is eligible for replacement on refresh/retry. Transport errors
never switch to an in-memory group. GPS diagnostics are injected only into the
controlled test composition, not normal production GPS.

## Clock diagnosis

The remote synthetic acceptance initially used a Windows clock approximately
4.5 seconds ahead of PostgreSQL. The server correctly rejected its samples
against the existing +3-second future bound. Its 15-second stale limit remains
unchanged. The successful remote harness used the server observation for its
synthetic timestamps; that adjustment is not applied to real GPS timestamps.

Before granting device GPS publication, the normal adapter compares a server
observation against the local RPC start/end times. A provably incompatible clock
fails closed with an automatic-date/time instruction. Network round-trip time
alone is not treated as clock skew. No coordinate or GPS timestamp is fabricated.

Real two-account phone acceptance remains a manual step after installation.
Do not describe the prior synthetic Realtime acceptance as real A55 GPS acceptance.

## 2026-10-16 delivery evidence

- Full Flutter regression: 1023 passed, 2 conditional skips (single worker).
- Final targeted group/GPS/clock tests: 22 passed.
- Analyze: 3 existing non-null warnings in archive Android tests and 4 existing
  infos elsewhere; no new findings in this delivery's production code/test.
- Normal release 1.0.0 (1), package `com.example.driveit_project`, AOT library
  present, debug kernel absent, debuggable false, native local-owner marker true,
  isolated marker false. Group RPC/Edge symbols and Planet DEV target present
  in the AOT snapshot. Build uses only the ignored public Auth config file.
- APK SHA-256:
  `369519FD703BE390E232DBAF7F650528A4F123A31FD138A1D0FAC26A68CC63AC`.
- Signer matches the installed certificate:
  `0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`.
- A55 `R5CX42V8GSJ` was idle (no process or active services) immediately before
  `adb install -r`; update succeeded and installed APK hash matched.
- Normal launch and account restoration succeeded. Home displayed existing
  drive/Career/Score data, and its Group Drive card opened the live DEV screen
  with Create/Join controls and no error. No group or GPS sharing was started.
- History/World detail screens were not independently accepted in this delivery:
  the phone switched to another app during the additional navigation check.
  The operator stopped UI inputs; those checks remain manual.
- A second physical client was not connected. Two-real-account device/GPS
  acceptance and background sharing remain unproven here.

No remote backend changes, data reset, commit or push were performed in this
normal-app activation task. Prior mixed changes were preserved.
