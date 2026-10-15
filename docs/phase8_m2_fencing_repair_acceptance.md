# M2 fencing forward repair — real Planet DEV acceptance

Date: 2026-10-15. Approved target: `viqngnjfgknpxtoapzcg` only.

**M2 server acceptance: TAMAMLANDI** for the bounded synthetic M1/M2 contract
suite. Normal-app deletion remains OFF. No APK/device operation occurred.
The earlier partial deployment report remains an accurate historical record.

## Exact repair

Applied only `202610160002_phase8_m2_fencing_sqlstate.sql`.
SHA-256: `8EC883826838ACCBA27DA774F03195585224C406297C47689545D03E842D5034`.

Two RPCs:

- `phase8_drive_lease(uuid,uuid,uuid,text,text,bigint)`
- `phase8_finalize_drive_upload_fenced(uuid,uuid,text,text,text,integer,uuid,text,bigint)`

The four business-error raises now use `PT409`, not `40001`. Messages remain
`lease_fenced`, `lease_held` and `lease_missing`. Genuine PostgreSQL serialization
failures are not caught, translated or disabled. Function signatures, defaults,
body predicates, locks, owners, ACLs, SECURITY DEFINER and empty search paths
were compared before/after and preserved. The exact remote body diff is only
the SQLSTATE substitution. No table, policy, trigger or Storage change was made
by this repair. Applied M1 and initial M2 migration files remain unchanged.

[PostgREST documents PTxyz as an explicit HTTP status](https://docs.postgrest.org/en/v14/references/errors.html).
`PT409` does not signal serialization retry. Existing Edge handlers keep their
public HTTP 409 error contract; Flutter maps it to `OwnerSyncConflict`, not
transport retry. **No Edge redeploy or Flutter behavior change was needed.**
Existing five function versions remain begin/finalize/download v2, delete/lease
v1. Existing Planet and cleanup function versions/JWT configuration are unchanged.

## Preflight and restorable backup

- Verified exact project ref/name/status, 16-entry pre-repair migration history,
  and exact previous RPC bodies. Source comparison rejected any change beyond
  the SQLSTATE substitution. CLI 2.120.0 linked workroot remained isolated from
  root `.temp`; dry-run selected only the new repair. History is now 17 entries.
- Fresh roles/schema/data backups restored successfully into the new local DB
  `phase8_planet_m2_fix_restore_20261015` in the existing isolated Docker stack.
  All 15 baseline relation row fingerprints matched exactly. The repair also
  applied successfully against that restored schema. No reset/drop was used.
- Private Git-ignored evidence directory:
  `tmp/diagnostic_acceptance/planet-m2-fix-20261015`.
  Backup hashes:
  - roles: `168A95A9C745AF5ED4679751F90419AC9DC434240A213B03E32A06D5664C2308`
  - schema: `BDBDCAC292E9CE2116DB82E33325FDFD2E343BC158896FDE8C69C48E538AB687`
  - data: `00172328F58D185EE85ED46F70F41FDFFAA2C2DB0CC1949B42479FDA6A9C3E9D`
- DB dumps do not contain Storage object bytes. Existing real object paths and
  bytes were never overwritten/deleted. Prior Edge rollback sources/config are
  still preserved in the earlier deployment's private evidence directory.

## Real server results

Existing real GoTrue/Storage/Edge/PostgreSQL E2E: **1 passed / 0 failed, 24s**.
Only synthetic owner A/B and synthetic drive envelopes were used.

| Check | Actual result |
| --- | --- |
| Previous wrong-token Edge timeout | HTTP **409**, `lease_fenced`, **312 ms**, no timeout |
| Direct wrong-token PostgREST RPC | HTTP **409**, SQLSTATE **PT409**, **61 ms** |
| Lease acquisition / valid heartbeat | Token 1 retained, expiry exactly heartbeat + 180s |
| Expired heartbeat | Rejected 409; cannot revive old lease |
| Successor session acquisition | Fencing token increments to 2 |
| Old-session finalized ACK replay | Rejected 409 |
| Current fenced finalized ACK replay | Accepted, no duplicate manifest |
| Delete replay / permanent tombstone | One tombstone, same durable receipt |
| Old upload/finalize retry | Rejected; deleted source not resurrected |
| Old snapshot / second A session | Redacted tombstone and cursor deletion converge |
| M1 regression | Upload, private staging, finalize/ACK, replay, hash conflict, download/cursor passed |
| B / anonymous / forged owner | Rejected; no unauthorized read/delete/RPC bypass |

The test uses one request per fencing probe and a 30s network deadline. Both
application conflicts completed promptly. Final read-only server check found
zero active lease requests; no retry loop was observed after the repair.

## Synthetic cleanup and real-data preservation

Only run `2deac123-82cb-4e6d-a78c-8139fc4046b9` was cleaned. Empty B account,
temporary snapshots/sequence state and auto-created profiles were removed.
A is banned, its password rotated only in memory, sessions/refresh tokens
revoked. Its owner row remains because immutable tombstone/manifest evidence
references it. Three temporary staging paths were removed and their intents
expired. One tombstone, three finalized manifests and three private finalized
objects are deliberately retained. No immutable trigger or FK was bypassed.
No global orphan cleanup ran. Earlier retained tombstones remain unchanged.

Every pre-repair row hash across the 15 baseline relations remains unchanged.
Profiles remain 5, Planet publishes remain 11, both buckets remain unchanged.
Auth count 9 -> 10 is only the newly retained disabled synthetic A. Manifest
count 10 -> 13 and Storage object count 22 -> 25 are only retained synthetic
evidence. The original real user's manifest and content were not modified.

Logical History deletion is not physical Storage erasure. Finalized content and
independent World/Career evidence remain retained; physical retention/purge is
not activated here. Never roll back to an unfiltered M1 download after tombstones
exist and never remove tombstones to make a rollback appear successful.

## Local/client regression and remaining rollout

- M2 pgTAP **34/34**, M1 pgTAP **45/45**, real local Edge E2E **1/1**.
  Local fencing Edge 409: 49ms; direct RPC PT409: 3ms.
- Existing Flutter sync/causality/adapter tests **40/40**.
- Full Flutter regression **989 passed, 2 conditional skips**.
- Analyze: pre-existing **3 warnings + 4 infos**, exit 1; not a clean analyze.
  All three warnings are in the untouched archive Android integration tests;
  the four infos are in existing Home/map/route-preview code. No new finding
  belongs to the M2 changes. Five Edge entrypoints pass cached Deno type-check.
- No new framework, instrumentation, Android test or alternative stack.
- Production factory still has `cloudDeletionEnabled:false` and adapter
  `deletionEnabled:false`; automatic account sync remains disabled.

Server acceptance is complete, not a client rollout approval. Next: separately
approve normal-client M2 activation/build/update and manual multi-device delete
convergence using disposable user-approved drives. All participating clients
must understand tombstones; old M1 clients fail closed on deletion events.
Real Android background heartbeat behavior remains a separate acceptance gap.
No real-user deletion, APK change, M3 or M4 deployment occurred.
