# Phase 8 M2 Planet DEV deployment — partial acceptance

Historical first-deploy report. The separately approved forward repair and
successful real server acceptance are now recorded in
`phase8_m2_fencing_repair_acceptance.md`. Do not interpret this earlier failure
as the current server status. Normal-app deletion is still OFF.

Date: 2026-10-15. Target: `viqngnjfgknpxtoapzcg` (DriveIT DEV).
Base Git HEAD: `481607ddcb63b5374e247434d6e4654120b05c48`.

## Outcome

**M2 server acceptance: KISMEN.** The approved migration and five functions
were deployed. Synthetic acceptance exposed a real PostgREST compatibility
defect in the chosen fencing SQLSTATE. No normal APK was built/installed and
normal-app cloud deletion remains disabled. No success checkpoint was committed
or pushed, because the user's condition of successful server acceptance was
not satisfied. Existing working-tree changes remain intact.

## Preflight, backup and restore

- Exact project identity/status verified before writes. History contained 13
  existing Planet migrations plus the two M1 migrations; only the new M2 version
  was pending. M1 RPC definitions matched the previously verified restore.
  Local `supabase_admin` versus remote `postgres` owner/grantor identity was
  explicitly normalized; actual role privileges and search paths were checked.
- Fresh roles/schema/data dumps cover `public`, `auth`, `storage` and
  `supabase_migrations`. They were actually restored into the separate local
  database `phase8_planet_m2_restore_20261015`; original row fingerprints and
  M1 function definitions/ACLs matched. M2 was also applied there without changing
  any original row. No container/volume/database reset was used.
- Protected, Git-ignored evidence root:
  `tmp/diagnostic_acceptance/planet-m2-20261015`.
  Backup SHA-256 values:
  - roles.sql: `168A95A9C745AF5ED4679751F90419AC9DC434240A213B03E32A06D5664C2308`
  - schema.sql: `01E8AC032FC7BE02BACD362926B45363D8E920F4C61D5FA72CDFD31D1C439503`
  - data.sql: `A70B320C4FFEC7BD0751B6CC73C3DB87CC0FCFF384A9B7288A24DCE49CB7A623`
- These are database backups, not copies of Storage object bytes. Existing
  Storage objects were never overwritten/deleted. Previous Edge sources,
  versions and configuration were saved under `edge-before` for recovery.
- CLI 2.120.0 used a separate ignored deploy workroot. Explicit linked-project
  checks and dry-run selected only M2. Root Planet `.temp` was not used.

## Actual remote changes

Applied only `202610160001_phase8_m2_deletion_fencing.sql`, SHA-256
`B7817BBDE7307E293237F0C61113DDF693AEA19C72B719B616FA586B6692B1D4`.
History now contains 16 versions. Applied M1 sources were not changed/replayed.

| Function | Final version | JWT | State |
| --- | --- | --- | --- |
| phase8-drive-begin | 2 | required | ACTIVE |
| phase8-drive-finalize | 2 | required | ACTIVE |
| phase8-drive-download | 2 | required | ACTIVE |
| phase8-drive-delete | 1 | required | ACTIVE |
| phase8-drive-lease | 1 | required | ACTIVE |

Existing `process-world-publish` v13, `planet-trace-detail` v2 and
`phase8-drive-cleanup` v1 were unchanged. No bucket/secret was created or
reconfigured. M2 tables have RLS enabled and no direct anon/authenticated SELECT.

## Real acceptance and the blocking defect

The existing synthetic E2E test, explicitly opted into remote M2, exercised
real Auth/Storage/Edge/PostgreSQL. Each run reached successful M1 upload,
finalize/receipt, idempotency, conflict, cursor/download and A/B/anonymous
negative assertions before entering M2. Real logical deletion, replay to the
same tombstone, stale-upload rejection and deletion download assertions also
completed. A lease was acquired and heartbeat renewal retained its token and
three-minute expiry.

The next assertion (wrong fencing token -> bounded HTTP 409) did **not** finish.
The final bounded run failed with `TimeoutError` after 48 seconds overall,
after `lease_acquired` and `heartbeat_renewed` checkpoints, before receiving
the wrong-fence response. The first unbounded run was interrupted; it is not
a passed test. Three synthetic runs were created in total.

Root cause: `phase8_drive_lease` and `phase8_finalize_drive_upload_fenced`
raise SQLSTATE `40001` for business fencing errors. Remote PostgREST 14.5
interprets this as serialization failure and automatically retries. Read-only
`pg_stat_activity` observations showed repeated short lease transactions rather
than a long blocked SQL statement. This matches Supabase's documented
[40001 infinite retry defect](https://supabase.com/docs/guides/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b).
The local runtime did not reproduce this hosted-version behavior.

**Do not weaken fencing, extend timeouts or edit the applied migration.**
Required next change: a separately approved additive forward migration replacing
the five business-error `40001` raises in those two RPC definitions with a
non-retrying application SQLSTATE (for example `P0001`), retaining messages,
locking, ownership, ACLs, empty search paths and all predicates. Edge continues
mapping the RPC failure to 409. That migration is outside the currently
approved single-version deploy list and was **not** remotely applied.

Expiry/takeover/stale-finalization assertions were not reached remotely and
remain unaccepted. Full remote M2 E2E: **0 passed / 1 bounded failure**;
earlier interrupted attempts are not counted as successes.

## Synthetic cleanup and preservation

- Three empty synthetic B accounts and their temporary snapshot/sequence state
  were removed. Auto-created synthetic profiles were removed.
- Three synthetic A accounts were banned, passwords rotated only in memory,
  and sessions/refresh tokens revoked. They remain solely because immutable
  manifests/tombstones reference their owner IDs.
- Nine unfinalized synthetic object paths were removed and their intents
  expired. Three permanent tombstones, nine finalized synthetic manifests and
  their nine private finalized objects remain as anti-resurrection evidence.
  No immutable trigger or foreign key was bypassed. No global cleanup ran.
- Final read-back: all original row fingerprints across 15 baseline relations
  remain unchanged. Original Auth users: 6 unchanged (plus 3 disabled synthetic
  users); profiles: 5 unchanged; Planet publishes: 11 unchanged; original M1
  manifest: 1 unchanged; original intents: 2 unchanged; original Storage objects:
  13 unchanged. Buckets remain 2 unchanged. Final active lease retry query
  count was zero.
- Deletion is logical History deletion, not Storage erasure. Finalized private
  content remains retained; automatic physical retention cleanup is not enabled.
  World/Career/Planet projections were not deleted or recomputed.

## Tests and rollout boundary

- Local pgTAP: M2 34/34, M1 45/45.
- Existing real local Edge E2E passed 1/1 with the added remote-safe scenarios.
- Flutter frozen regression: 989 passed, 2 conditional skips; targeted sync
  tests 40/40. Analyze: pre-existing 3 warnings + 4 infos, not a clean analyze.
- This deploy turn modified only the existing Deno acceptance test and reports:
  explicit synthetic-only remote M2 opt-in, expiry/fencing checks, bounded fetch
  waits and non-sensitive phase checkpoints. No new test framework was created.
- Existing normal M1 capability response remains compatible by default; M2 is
  explicit negotiation only. Old M1 clients cannot consume tombstones, so a
  supported-client upgrade is required before real deletion is enabled.
- Do not roll back download to unfiltered M1 after tombstones exist. Preserve
  tombstones and use a forward repair. No drop/reset/resurrection rollback.

Next approval required: the narrow forward SQLSTATE repair migration, followed
by the same synthetic remote acceptance. Only after that passes may tested
changes be checkpointed and a separate normal-APK deletion rollout be considered.
No Android action, real-user test, M3/M4 work or other-project operation occurred.
