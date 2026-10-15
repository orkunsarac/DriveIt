# M2 staging cancellation — real Planet DEV acceptance

Date: 2026-10-15. Only authorized target: `viqngnjfgknpxtoapzcg` (DriveIT DEV).

**Server staging-cancellation acceptance: TAMAMLANDI.** This does not close the
GPS zero-telemetry investigation or authorize a phone update. No APK build,
installation, phone queue retry or real-account drive mutation occurred here.

## Preflight, backup and rollback boundary

- Verified exact project ref/name/healthy status, 17 prior migration versions,
  previous fencing RPC bodies, existing private bucket restrictions and Edge
  versions. Cancellation table was absent before this deployment.
- Fresh roles/schema/data dumps restored into the separate local database
  `phase8_planet_m2_cancel_restore_20261015` in the existing isolated Docker stack.
  All **17 baseline relations** matched their original row fingerprints exactly.
  Role restoration was checked transactionally and rolled back, not applied
  globally. No database reset/drop or container/volume deletion was used.
- Candidate migration applied successfully against that restored live schema.
  Existing RPC signatures, owners, ACLs, SECURITY DEFINER properties and empty
  search paths were preserved. Dry-run selected only the approved new version.
- Private, Git-ignored, user-ACL evidence/backup location:
  `tmp/diagnostic_acceptance/planet-m2-cancel-20261015`.
  SHA-256:
  - roles.sql: `168A95A9C745AF5ED4679751F90419AC9DC434240A213B03E32A06D5664C2308`
  - schema.sql: `4E0FE7ABE9B6AAC6F99C26796F2B2F13177CA342360A865901E0DD170EE784F2`
  - data.sql: `CFFC58E1F0B75DFA6D014B7A13013E4C3CFC825E7EE96FDCED2C27B675D12453`
- Previous three Edge sources and version/JWT metadata were downloaded privately.
  DB dumps do not back up Storage bytes. No existing real object was overwritten
  or deleted. Only three new synthetic temporary objects were removed later.
- Recovery strategy is stop rollout and forward-repair. Previous Edge sources
  are retained for diagnosis/controlled recovery, NOT permission to serve old
  behavior over new cancellation events. After first receipt, never remove
  barriers or revert merged snapshot handling. Database restore is a verified
  recovery artifact, not an automatic destructive rollback instruction.

## Exact deployment

Only new migration `202610160003_phase8_m2_staging_cancellation.sql` applied.
SHA-256: `6DA520A532EA3C849CF7E6C94EF5C65806F9F82F9E738A7F3913839AF0AD1871`.
Remote history is now 18 versions. Applied M1/M2 migration sources were not edited
or replayed. The isolated linked CLI workroot, not the root Planet `.temp`, was
used with pinned CLI 2.120.0 and explicit `--linked` / `--project-ref`.

| Edge function | Before | After | verify_jwt |
| --- | --- | --- | --- |
| phase8-drive-begin | 2 | 3 | true |
| phase8-drive-finalize | 2 | 3 | true |
| phase8-drive-delete | 1 | 2 | true |

All other Edge versions/configuration remained unchanged. No bucket, secret,
download/lease/cleanup Edge, Auth setting, Planet policy or M3/M4 deploy occurred.
Existing public/Storage RLS definitions remained identical. New cancellation
table has RLS and no direct anonymous/authenticated access; the cancellation
RPC is service-only with empty search_path and verified-UID Edge entry.

## Actual hosted acceptance

Existing real GoTrue/Storage/Edge/PostgreSQL suite: **1 passed, 0 failed, 40s**.
New synthetic A/B users and synthetic envelopes only. The test now has a distinct
explicit cancellation opt-in for this exact project and returns BEFORE global
orphan-cleanup code. Ordinary M1/M2 opt-in behavior remains unchanged.

- Authenticated A stages an empty-telemetry synthetic envelope; finalize correctly
  rejects it with 422. Real staging intent/hash can be observed by its owner.
- Cancellation succeeds with an immutable mutation/positive server sequence;
  replay returns the identical receipt, covering lost-ACK retry without a second
  event. Physical staged bytes remain, but client staging read is revoked.
- Old begin and delayed finalize return **409 source_cancelled**. No manifest
  can be created after cancellation. Existing download cursor carries the barrier.
- Concurrent finalize/cancel yields one 200 and one 409; database read-back proves
  exactly one manifest OR cancellation. A separate deterministic finalized-first
  fixture returns **409 source_already_finalized**, then accepts the standard
  causalVersion 1 tombstone using actual manifest evidence.
- B's forged cancellation is rejected 422; anonymous cancellation is rejected
  401. Existing A/B read/write/RPC isolation checks also pass.
- M1 private upload/finalize/durable ACK, same-payload retry, different-hash
  conflict, download/pagination/snapshot checks pass. Standard M2 tombstones,
  anti-resurrection, second-session deletion download, lease/heartbeat/expiry
  and successor fencing pass.
- Wrong fencing Edge request: HTTP 409 `lease_fenced`, **405 ms**. Direct RPC:
  HTTP 409 / `PT409`, **127 ms**. No timeout or retry loop.

## Cleanup and protected real data

Only this new synthetic run was cleaned. Empty B was removed. A is banned with
an in-memory password rotation; sessions/refresh tokens and its generated
profile/snapshots were removed. Three unfinished temporary staging objects
were removed. Retained audit evidence: **3 manifests, 2 standard tombstones,
2 cancellations, 5 private objects**, plus the disabled synthetic A identity.
Immutable triggers/FKs were not bypassed. No global sweep ran.

Final comparison across all 17 baseline relations proves **every original row
unchanged**. Existing Auth users, Planet/profile rows, original successful real
drive and actual staging-only attempts remain intact. No real phone outbox was
opened, altered or retried. Logical cancellation is independent of physical
Storage retention; no finalized/cancelled content purge is enabled here.

## Local/client validation and next authorized action

- Current local pgTAP: M1 **45/45**, M2 **34/34**, cancellation **22/22**.
- Current local real Edge/Storage suite, including finalized-first fallback:
  **1/1 passed**. Affected Edge/test sources pass Deno type-check.
- Fresh full Flutter regression: **997 passed, 2 conditional skips**, exit 0.
  Existing conditional tests are not counted as acceptance. Analyze retains
  the previous **3 warnings + 4 infos**, exit 1, not a clean analyze: warnings
  are in untouched archive Android tests; infos are existing Home/map/route
  preview findings. No new finding comes from this cancellation change.
  `git diff --check` passes. No new Android test/framework was created.
- The existing tested Flutter correction persists cancellation consent/mutation,
  validates the receipt, handles finalized-first using standard tombstones,
  preserves owner epoch checks and blocks stale uploads/re-imports. Empty
  telemetry is local-only and rejected before upload; no data is fabricated.

The real pending phone deletion is deliberately UNTOUCHED. Next task requires
explicit normal-APK update approval. That future update may retry the existing
consented row on bounded startup/resume or user retry: staging -> cancellation
receipt; finalized meanwhile -> observed manifest -> standard tombstone. Never
clear the queue manually or treat 404 alone as completion.

GPS root cause remains **unproven** (`finalSequence=0`, telemetry=0, route=0).
This backend acceptance does not claim to fix recording/provider behavior.
