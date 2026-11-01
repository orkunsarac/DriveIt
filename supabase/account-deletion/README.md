# P-GR6A account deletion candidate

P-GR6A local acceptance: **PASS**; current P-GR6B evidence is linked below. No DEV/PROD deployment is included. Seventeen forward migrations live here intentionally outside the default deployment chain; apply only after the reviewed 25-migration baseline. P-GR6B changes only two reviewed compiler source hashes in the preparation inventory; baseline SQL and the nine-function deployment list are unchanged.

## Protocol

`delete-account` is a custom-auth Edge endpoint (`verify_jwt=false` in the isolated test config). It must not be exposed with weaker server logic:

- `request`: verified current user JWT, explicit `DELETE_MY_ACCOUNT`, current email/password reauthentication to the same UID, random request UUID and 256-bit receipt. `expectedOwner` must match the verified JWT subject; it is a stale-account precondition, never authority to select a deletion target. A strong configured `ACCOUNT_DELETION_WORKER_TOKEN` is required before accepting a new request.
- `run`: private receipt capability bound to the existing job. This can resume after logout/Auth deletion; it cannot create a deletion job or choose another subject. A lease prevents competing workers. One pass handles at most 100 listed objects from one bucket. SDK calls time out after 15 seconds.
- `worker`: independent 256-bit server secret in `x-driveit-deletion-worker`. It chooses one already-consented pending job, never a body-selected subject. Failures back off two minutes. Blocked Planet jobs are excluded from automated retries. No polling/cron/paid service is created by these files.

Database entry points are service-only except the narrow policy helper. Job/event tables have RLS and no client/table grants. Immutable deletion bypass is definer-only, transaction-local and bound to the job owner. Old JWT subjects must still exist in Auth before private RPC/Storage access is allowed.

Storage is removed before relational purge, and Auth last. Completion requires absence of Auth/Storage and successful managed Auth/audit erasure. Completion clears owner/email identifiers. Minimal random receipt/status records are pruned after 24 hours on new request or worker invocation. Scheduler/monitoring must be configured before real rollout so an abandoned device does not prevent continued work or pruning.

## Planet boundary

P-GR6B adds a bounded survivor replay in candidates 012–017. See [P-GR6B acceptance](../../docs/account_deletion_pgr6b_acceptance.md) for the current shared-contribution contract, resource limits, artifact regeneration evidence and remaining rollout gates. The original P-GR6A evidence below remains historical. The current candidate chain has seventeen migrations; default deployment still excludes it.

No shared-contribution retention or legally verified anonymization is assumed. When another owner's validated road exists, candidates 012–017 require verified replay of surviving canonical sources before purge. The derived trace index (including historical splits potentially influenced by the withdrawing account) is replaced atomically within the captured generation; survivor canonical roads/sections/sources and private drives remain intact. Unsupported/missing/oversized or concurrent-deletion contexts remain `blocked_planet`, never completed. Public Planet reads and derived writes fail closed while affected publication data remains. This can temporarily pause Planet globally.

Unshared source/publish/geometry/trace data is erased. Neutral generation ordering needed by remaining records has its source ID/session/distance/time erased; a new deletion generation invalidates stale plans. This is a technical state change, not a legal declaration about anonymization or retention.

## Reproduction and evidence

`tool/run_pgr6a.ps1 -Initialize` creates a unique disposable project, copies only reviewed function sources, disables signup and automatic migration/seed execution, pins physical PGDATA/system identity and applies the baseline/candidates explicitly. Existing volumes are not reset or deleted. `-BootstrapEmpty` resumes an interrupted empty bootstrap only after verifying Auth/public tables are empty. `-PrepareOnly` prepares the explicit descriptor target without running tests; `-Filter` selects a test. No implicit default stack or remote database is selected.

Local secrets are generated only under ignored `tmp/pgr6a-*`, referenced via `[edge_runtime.secrets]` and never printed. If CLI reports partial lifecycle, recover only that descriptor's stack with documented data-preserving stop/start. Raw stack JSON contains credentials and must stay suppressed.

Final evidence: [acceptance record](../../docs/account_deletion_pgr6a_acceptance.md), 14 real-service tests, 9 new Flutter controller/widget tests, full host 1176 PASS/2 skip, unchanged 3 warning/4 info baseline, Android debug Kotlin/resource build PASS. No physical-device test or APK installation occurred.

Deletion revokes an ordinary group member by rotating the surviving group's generation/revision, while preserving the other administrator's group. New publications use the new topic; immediate disconnection of a previously authorized socket is not claimed.

## Real rollout remains separately authorized

The UI define `DRIVEIT_ACCOUNT_DELETION_ENABLED` defaults to FALSE. The endpoint is not in the current nine-function PROD deployment manifest. Before deployment/activation: review hashes/order/owner permissions for this separate candidate chain, verify actual Auth managed-schema compatibility, configure the private worker secret and secure scheduling/monitoring, complete physical KeyStore/owner/GPS acceptance, and resolve Planet withdrawal plus provider logs/backups/cache/legal policy. Do not open signup or Group Drive as part of this feature. Do not treat local PASS as beta authorization.
