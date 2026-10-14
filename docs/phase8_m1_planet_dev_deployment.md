# Phase 8 M1 — Planet DEV deployment and real-server acceptance

Date: 2026-10-15 (Europe/Istanbul). Source HEAD remains
`90168c887b0197682c4f8278f59b1c313df72925`; this delivery is not committed.

## Result and target

**M1 backend DEV acceptance: TAMAMLANDI.** This does not enable app cloud sync,
certify physical two-device Flutter acceptance, or complete M2/M3/M4.

User explicitly approved the existing process PAT and additive M1 deployment
to Planet DEV. Management API returned HTTP 200, exact ref
`viqngnjfgknpxtoapzcg`, name `DriveIT DEV`, status `ACTIVE_HEALTHY`.
The separate `jidyfemjzztlwjmijndx` project was neither queried nor changed.
No PAT, server key, account password or cleanup-token value is included here.

## Preflight and restore-verified backup

Remote baseline: exactly 13 historical Planet migrations, seven existing
public/Storage RLS policies, two existing Edge Functions, private bucket
`world-drive-sources`, six Auth users and 11 World publish rows. No M1 table,
RPC, policy, bucket or function name collision was found. Migration sources
already recorded on the server were not edited, replayed or repaired.

The platform backup list was empty and PITR disabled. Nevertheless, the PAT
successfully supported CLI's temporary database login; no database password
reset or password input was needed. Supabase CLI was pinned to **2.120.0**.

Logical backup directory (Git-ignored, Windows ACL restricted to the current
user): `tmp/diagnostic_acceptance/planet-m1-backup-20261015/`.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| roles.sql | 370 | 168A95A9C745AF5ED4679751F90419AC9DC434240A213B03E32A06D5664C2308 |
| schema.sql | 234263 | 914DCCAF0FCE5E4300411914292FD31D886DC50E6D7055F99D2CB0B7472B3B42 |
| data.sql | 1357517 | 6D85EFB3A9E2463CAF849E7CACA34B886D172084F7434AF568638FEB60B24DDD |

Included schemas: public, auth, storage, supabase_migrations. The backup has
private Auth data: do not commit, upload, or share these files. Storage object
**bytes** are not included in a database dump. Existing World bucket/object
metadata was preserved; no existing World object was written or removed.

Restore was actually executed, not inferred from file existence: all three SQL
files restored with ON_ERROR_STOP into a NEW database
`phase8_planet_m1_restore_20261015` in the existing local PostgreSQL container.
PostGIS/crypto extensions were prepared in that database. No existing database,
container or volume was reset/deleted. Restore had zero SQL failures and
returned six Auth users, 13 migration records and 11 World publishes.
Both M1 SQL files then applied successfully to this restored copy. Complete
row fingerprints for existing Auth users/profiles/World tables matched remote.
`restore-verification.json` binds the restore result, project, hashes and time.

## Applied M1 changes

CLI deployment workspace: `tmp/diagnostic_acceptance/planet-m1-cli/`.
It contains the 13 historical migration files as history context plus exactly
the two approved new M1 files. Explicit --workdir and exact isolated project-ref
checks prevent using repository-root Planet .temp. CLI dry-run selected ONLY:

1. `202610120001_phase8_drive_sync.sql`
   SHA-256 BF7AEAB76A39D075876C0C4CE02546782EBEB2F8374C0D521CD36977F8BFFD11
2. `202610150001_phase8_m1_forward_repair.sql`
   SHA-256 B1BAF05304E01ABA3D0E04654ED266B5130D2A8C14BB712C59237B591BD61F1C

Real write used `db push --linked --yes`. Read-back confirmed exactly 15
migrations. All five M1 tables have RLS enabled; anon/authenticated raw table
SELECT is denied. Server-only RPCs deny anon/authenticated EXECUTE and use an
empty search_path. The staging predicate alone is authenticated-callable and
binds the exact object path to auth.uid(). No existing RLS policy was changed.

Private bucket `phase8-drive-staging` read-back: public=false, file_size_limit
10485760, allowed_mime_types exactly [application/json].

Four functions deployed ACTIVE, version 1:

- phase8-drive-begin: verify_jwt=true
- phase8-drive-finalize: verify_jwt=true
- phase8-drive-download: verify_jwt=true
- phase8-drive-cleanup: verify_jwt=false, independent server token required

PHASE8_CLEANUP_TOKEN was generated with a cryptographic RNG in process memory
and sent via HTTPS request body BEFORE cleanup deployment. It was not placed in
CLI arguments, files, Git, Flutter or logs. Exact secret-name read-back passed.
No scheduler/global orphan sweep was started.

The shared project's existing process-world-publish revision changed 12→13
and planet-trace-detail 1→2 during server-secret configuration. No deploy command
targeted either existing function. Read-only source downloads were audited:
13 process-world-publish source files matched the repository; Planet trace
sources matched after formatting/whitespace normalization. Existing sources
were not rewritten or redeployed by this delivery. Their JWT checks remain on.

## Actual test results and narrow fixes

- Windows PowerShell 5.1 parser: zero errors, script UTF-8 BOM.
- Deploy fail-closed SelfTest: **32/32**; target/pins/workdir/migration allowlist
  remain enforced. The forbidden separate project is explicitly rejected.
- Deno type-check passed for the existing extended E2E file.
- Deno canonical JSON/SHA-256 tests: **2/2**.
- Final real Planet DEV E2E: **1/1 passed**, 13 seconds, with many assertions:
  actual GoTrue synthetic A/B creation/sign-in; server capability/UID binding;
  anonymous and forged-owner rejection; service-only RPC and direct manifest
  denial; staging invisibility; valid private upload; B/anon read denial AFTER
  the object exists; finalize/owner-bound receipt; lost-ACK replay; same-key
  different-hash conflict; independent second A session download with exact
  canonical bytes; bounded cursor pages, renewal and expired partial recovery;
  B feed/cursor isolation; missing, malformed and wrong-hash object rejection;
  wrong cleanup token rejected 401; finalized content still available server-side.

Two actual issues were fixed without weakening product checks:

1. Native CLI progress/version notices on stderr contaminated JSON secret-list
   parsing under Windows PowerShell 5.1. JSON operations now parse stdout only,
   still checking CLI exit code. Initial deployment safely stopped after the
   verified migration/bucket stage; explicit resume verified that stage and
   finished secret/functions WITHOUT replaying migrations or overwriting bucket.
2. The test expired a synthetic snapshot using Windows now minus one second.
   Windows was measured about three seconds ahead of the remote server, so this
   was not reliably expired remotely. Only the fixture now uses epoch expiry;
   no production cursor/expiry logic was changed. Initial failed acceptance was
   not counted as passed. Both failed-run users and fixtures were cleaned.

No Flutter/app source changed in this delivery. Full Flutter was not rerun;
the preceding 975 passed / two conditional skips remains historical evidence,
not a fresh result. No Android/instrumentation/APK work was performed.

## Cleanup and preservation evidence

All three remote runs had their own random synthetic A/B accounts, envelopes,
intents, snapshots and feed entries. Only exact run-email/UUID-bound objects
were removed. An administrator-only transaction used LOCAL replication-role
override to remove those synthetic immutable rows; it did not alter any trigger,
function, RLS definition or grant, and the override ended with the transaction.
Synthetic Auth users were then deleted through Auth admin API. Security audit
logs generated by these operations were not deleted.

Final server read-back: six original Auth users, 11 World publishes, zero
remaining run accounts, zero M1 intents/manifests/changes/snapshots/sequences
and zero M1 Storage objects. Existing Auth/profile/World row fingerprints and
existing Storage object/bucket metadata fingerprints match the restored backup.
Existing 19 public non-M1 RPC definitions and seven policies also match after
using the same catalog search_path (different schema qualification is not drift).

## Stop / rollback and remaining app work

No destructive down migration was created or run. If an M1 defect appears,
keep the APK sync flag off, stop M1 calls and, with operational authorization,
disable only the four M1 endpoints. Preserve all tables/objects/receipts; repair
with a new additive migration, never reset Planet or replay applied versions.
The verified logical backup is the recovery baseline; do not restore it over
live DEV without separately scoped recovery approval and an up-to-date backup.

Normal app's DRIVEIT_ACCOUNT_SYNC_ENABLED remains false. Guest, account,
archive, History and GPS storage/runtime were not changed. To expose real sync:
explicitly approve activation, build with the existing tested real adapter and
same Planet Auth project, then verify new proven account-owned drives through
real Flutter upload/download and account switching before wider rollout.
No legacy/Guest automatic transfer is enabled. Physical two-device Flutter
acceptance, cleanup scheduling, M2 deletion/lease, M3 projections and M4 group
Realtime are not claimed complete. No commit/push was performed.
