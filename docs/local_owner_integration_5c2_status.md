# Phase 5C.2 — integration status (not production-ready)

## Safety decision

Phase 5C.2 is PARTIAL. `LocalOwnershipGate.production` remains disabled. There
is no new production bootstrap, Auth subscription, migration, import, GPS
callback or transfer routing. Previous 5A/5B/5C/5C.1 work remains intact.
Do not enable the gate in the application or proceed to production acceptance
until the missing consumers below have been connected and proven together.

## Implemented and exercised integration boundaries

- `SupabaseLocalOwnerAuth.events` projects actual SDK `AuthState` into UUID/null
  with refresh deduplication; fake SDK streams verify it without Supabase calls.
- `LocalOwnerLifecycle` serializes identity changes, owner operations and store
  transitions. External Auth invalidates the lease immediately even while an
  operation is pending. A failed operation propagates to its caller but does not
  poison the queue. Callbacks must not await `settled` or invoke another fenced
  operation while holding the fence (non-reentrant contract).
- Recovery allows the SAME owner only with durable sidecar evidence. Missing,
  conflicting or unreadable evidence blocks access; it is never guessed guest.
- `LocalOwnerGpsBridge` captures the lease owner, reserves/binds before a native
  start callback, rejects another unfinished journal, and retains the source on
  native startup failure. It does NOT implement/enable the foreground isolate
  bootstrap. Its native callback is injected in tests, not a real GPS service.
- Transfer uses the already-open lease store, immutable sidecar target and
  existing scoped sink/coordinator. Another account is denied, not redirected.
  Receipt/Hive verification remains unchanged; no automatic cleanup is added.
- `LocalOwnerNavigator` puts the ENTIRE private Navigator below the epoch key.
  A pushed old-owner route disappears on switch. Unregistered routes fail
  closed. Route builders must explicitly provide all scoped dependencies;
  this helper alone is not proof that arbitrary existing screens are safe.
- Actual `HistoryScreen`, `CareerScreen` and `DriveScoreSummarySection` accept
  revocable owner leases. Their scoped paths do not read global Hive, recalculate
  scores or derive Career from another scope. History delete delegates to the
  scoped independent deletion primitive with its existing source/Career proofs.
  Detail navigation has NO global fallback if a scoped detail builder is absent.
- `LocalOwnerImportBridge` ties consent to the lease and serializes with GPS
  creation/user identity changes. It requires source writers to pause/drain
  before survey/reservation, verifies consent again, and always releases the
  fence after a completed pause. Pause failures must release their own fence.
  The actual shared-store writer registry/quiescence implementation is NOT yet
  installed. Completed imports stay read-only verified partitions, not live
  store promotion. Normal new scoped records do not require a legacy ledger.

## Remaining consumer inventory / blockers

| Consumer | Current state / necessary work |
| --- | --- |
| `lib/main.dart` | Legacy bootstrap retained. Needs complete explicit owner bootstrap before ANY shared personal Hive read, then scoped recovery/navigation. |
| `lib/services/supabase_account_service.dart` | Production sign-in/out is unchanged. Needs identity-action adapter wired to lifecycle fence; SDK observer helper alone is not enough. |
| `lib/services/foreground_service.dart`, `lib/task_handler.dart`, `lib/screens/map_screen.dart` | Still legacy production entry points. Need one durable native-isolate ownership bootstrap/start/recovery/transfer contract, independent of current Auth. No shared transfer fallback allowed when enabled. |
| `lib/screens/home_screen.dart` | Global profile, Career, History and symbolic-route reads need full scoped providers. |
| `lib/screens/drive_detail_screen.dart` | Needs authoritative lease lookup by ID, scoped names/diagnostics/timing/score/publish and owner-bound nested routes. A provided DriveSession is not ownership proof. |
| Poster editor/preview/export, `lib/features/drive_poster/poster_store.dart` | Needs scoped metadata/store AND file resolver, revoked cache/controller results and nested navigation. Import preserves files but does not replace live poster consumers. |
| Profile/onboarding local fields | Existing global ProfileStorage loaders need owner-scoped provider, not just server profile data. |
| My World map/detail/runtime/rebuild/settings/diagnostics | Static global runtime, source access, generation cache and worker entry points remain. Must use scoped generation/jobs/tombstones and await in-flight jobs before store close. |
| Planet publication preview/outbox/legacy publish status | Must use fixed scoped owner and disabled segment gateway; real accepted server world remains authoritative. No new network path enabled. |
| Legacy consent routing/import visibility | Panel and importer helpers exist; needs complete writer registry, guarded route, completed-partition overlay or verified live-store promotion with conflict policy. |

## Test evidence and limitations

Initial host regression: 730/730. New tests use synthetic Hive/SQLite roots,
fake Auth events and native callbacks. A first targeted run was interrupted
because the new History widget test awaited host I/O in Flutter's fake-async
zone. The harness now uses `tester.runAsync`; this was not a storage data-loss
failure and the interrupted run is not counted as passing.

Controlled exceptions, injected writer drain and simulated native callback
failure are NOT real Android process-kill/power-loss or foreground-isolate
acceptance. No actual user data, credentials or remote operations are involved.
Results of final regression/native reruns are recorded in the task report.

Final host regression: 747/747, including 17 new service/widget integration
tests; full suite passed twice. Final analyze: only the original four info
diagnostics, no new error/warning/info. Tracked and new phase files passed
whitespace checks. No commit, push, remote operation or physical device install.

Native rerun: importer/lifecycle/scoped storage/sidecar/independent lifecycle/
legacy Hive 19/19; GPS/SQLite 8/8 (27/27 combined). The GPS suite intentionally
reproduces the old incorrect busy_timeout `execute` call and verifies the
correct `rawQuery` configuration. Its expected SQLite probe is not an
unexpected application failure. These are existing native regressions, not
proof that the new owner bridge is connected to the real foreground callback.

Changed in this phase: `local_owner_lifecycle.dart`,
`supabase_local_owner_auth.dart`, `local_owner_gps_bridge.dart`,
`local_owner_import_bridge.dart`, `local_owner_navigator.dart`,
`history_screen.dart`, `career_screen.dart`, `drive_score_summary_section.dart`,
`local_owner_integration_test.dart`, `local_owner_import_bridge_test.dart`, and
this document. Prior uncommitted files were not removed or overwritten.

## Next-stage decision

Do not mark 5C.2 complete or advance to 5C.3 on the basis of helper tests.
Complete the listed consumers and native entry points first, then prove the
whole gate-open synthetic application without any global personal data fallback.
