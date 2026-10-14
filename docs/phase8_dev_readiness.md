# Phase 8 DEV provisioning readiness

Current evidence (2026-10-15) is recorded in
`phase8_m1_normal_runtime_delivery.md`. The historical preparation/tool-blocker
notes below do not supersede the newer real local PostgreSQL and Edge results.

Status: preparation only. User-created separate project details were supplied
on 2026-10-12; no remote project was queried and no migration, bucket, user, or
function was created/deployed. Production ownership remains disabled.
Review date: 2026-10-12.

## 1. Phase 7 acceptance hold

The visible-app physical GPS acceptance remains **PARTIAL**. On A55 the isolated
test reached the test body, owner-controlled Group screen, consent, and Android
permission request; the user granted permission, but no valid `deviceGps`
member sample was observed before `_waitForMember` timed out. The callback vs
filter vs publish boundary is still unproven. A later safe-script attempt did
not return test output and was stopped. Coordinate-free diagnostics now exist
in the controlled test path, but there will be no further Android attempt in
this work item. The independent group-only background FGS is still missing.
See [Phase 7 physical diagnosis](phase7_real_gps_delivery.md#physical-gps-diagnosis-update--2026-10-12).

## 2. Existing local state and tools

- The approved backend contract is [phase8_backend_contract.md](phase8_backend_contract.md).
  It defines four backend milestones, first being new proven drive upload and
  same-owner second-device download with Owner B denied.
- The local client already has canonical sync v2 JSON/SHA-256, persistent
  owner-scoped outbox, idempotency, staged-upload interface, bounded retry,
  fake remote, and synthetic two-store upload/download tests. It is not a
  Supabase transport and is not wired as a production worker.
- The repo has `supabase/config.toml`, existing Planet/World Edge Function
  entries, 13 existing Planet/World migrations and SQL tests. There is no
  Phase 8 schema/function or migration yet.
- A local Supabase CLI `.temp` link marker exists. Its contents were not read;
  the linked project identity is therefore intentionally unknown. No Supabase
  CLI command was run. Until a separately approved target is explicit, do not
  run `supabase link`, `db push`, migration, function deploy, or Storage setup
  in this checkout: the existing link may point at the Planet project.
- `supabase`, Docker, Deno, and PostgreSQL CLI tools (`psql`/`pg_isready`) were
  not found on PATH. Flutter is installed, but `flutter --version` did not
  return within the environment command window; package code already uses
  `supabase_flutter` and compile-time configuration.
- Flutter config accepts only the client `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY` Dart defines. No project-specific Phase 8 DEV
  values were supplied for this task. No `.env`, `.env.local`, `.env.dev`, or
  `supabase/.env` file exists at the checked paths. The isolated-test define
  explicitly disables Supabase initialization; it is not a DEV networking
  switch. Service-role credentials must never enter Flutter/Dart defines.

### Tool necessity

| Tool | First milestone | Decision |
|---|---|---|
| Supabase CLI | Migration lifecycle, local stack, DB tests, Edge Function serve/deploy targeting | Required before backend implementation/remote operations; currently absent. |
| Docker Desktop/Engine | Run the local Supabase stack and exercise migrations/RLS before remote application | Required for the agreed local DB/RLS validation; currently absent. |
| Deno | Type-check and test the Edge Function implementation locally | Required if the server API is implemented as the contract's Edge Functions; currently absent. |
| PostgreSQL `psql` | Ad hoc direct DB interaction | Not independently required if CLI local stack plus `supabase test db` is available; useful, not a provisioning prerequisite. |
| Flutter | Existing host client/fake regression | Present; no backend credentials are needed for the fake tests. |

Do not install tools or mutate the local linked-project state as part of
preparation without a separate authorization. The first safe backend coding
gate is: isolated project approved, local CLI/Docker/Deno validation available,
and tests target a local disposable stack rather than the current Planet link.

## 3. Separate project request (not executed)

Required project name: **DriveIt Phase 8 DEV**. It must be a distinct Supabase
project, not a schema/bucket added to Planet DEV. Before provisioning, confirm
organization, region, plan/cost, and disposable account ownership in the
Dashboard. Recommended starting region is **Europe / Central EU (Frankfurt)**
for this Turkey-based development workflow, subject to the user's data-location
choice; the available exact-region list and final selection must be checked at
creation time. This is a latency-oriented suggestion, not a residency/legal
determination. Supabase documents one primary region per project and notes that
the chosen region determines where primary data is stored ([regions](https://supabase.com/docs/guides/platform/regions)).

Minimum first-milestone capabilities:

- PostgreSQL database and Auth, with two disposable test accounts for the same
  owner-transfer check and a third account for Owner B denial. Disable unused
  providers; no production identities or data.
- Private Storage bucket for staged drive envelopes. Do not make it public;
  restrict object access with `storage.objects` RLS and keep final manifests
  inaccessible until DB finalization. Supabase private buckets enforce access
  on both upload and download; Storage object rows should be managed through
  the Storage API, not direct SQL ([private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals),
  [Storage access control](https://supabase.com/docs/guides/storage/security/access-control),
  [Storage schema guidance](https://supabase.com/docs/guides/storage/schema/design)).
- Edge Functions for authenticated begin-upload/finalize and bounded snapshot/
  page APIs. The service-role secret is configured only in server-side function
  secrets and never returned to the client.
- Realtime is **not needed** for milestone 1; it is reserved for group milestone
  4 after its membership revocation protocol is implemented. PostGIS and push
  services are also not first-milestone prerequisites.
- A private bucket/object cap compatible with the contract's 10 MiB maximum
  envelope and synthetic 2-hour / 8,000-point fixture. Verify actual project
  limits before the cap is treated as rollout-approved.

Cost cannot be certified from repository state. Current Supabase billing docs
describe up to two Free projects, included usage quotas, and project compute
charges on paid organizations; verify the organization plan, free-slot count,
pause behavior and current price in the dashboard immediately before creating
anything ([billing](https://supabase.com/docs/guides/platform/billing-on-supabase),
[Realtime quotas](https://supabase.com/docs/guides/realtime/limits)). Do not
start a paid compute resource without explicit user approval.

## 4. Milestone 1 implementation file plan

No backend code was added in this readiness pass. The following additive files
are the minimum candidate layout once the isolated environment and local test
tools are authorized and available:

1. `supabase/migrations/<timestamp>_phase8_drive_sync.sql`: additive owner
   sequence, upload intent/idempotency reservation, immutable finalized drive
   manifest, ordered owner change-feed rows, ACK receipt, and bounded snapshot
   metadata. Every exposed table gets explicit grants and RLS; ownership is
   `auth.uid()`-derived, never trusted from a client owner field. Use a narrow
   transaction finalizer with unique constraints and row locks. Do not edit or
   rename Planet/World migrations.
2. `supabase/functions/drive-sync-begin-upload/index.ts` and
   `supabase/functions/drive-sync-finalize-upload/index.ts`: authenticated
   intent binding and finalization. Finalizer verifies the exact private staged
   object byte count/SHA-256, parses the canonical v2 envelope, validates the
   owner/source/idempotency/payload fingerprint, and invokes one PostgreSQL
   transaction that creates the manifest, ordered change row, finalized intent,
   and durable ACK.
3. `supabase/functions/drive-sync-snapshot/index.ts` or bounded Postgres RPCs:
   owner-bound opaque snapshot cursor/high-water mark, ordered pages and
   replay-safe acknowledgements. Never use wall-clock time as a cursor.
4. `supabase/tests/phase8_drive_sync_rls.test.sql` plus Deno canonical vectors
   and handler tests: authenticated A allow, B deny, anon deny, same-key replay
   returns identical ACK, changed bytes/claims conflict, unfinished staging is
   never downloadable, and cursor replay produces neither gaps nor duplicates.

### Storage/Postgres split protocol

Storage and PostgreSQL do not share a transaction. A begin operation first
commits an owner-bound intent/idempotency reservation in Postgres; then the
client uploads canonical bytes to the exact private staging path for that
intent. The object is not a drive and is not in the download feed. Finalize
re-reads and hashes that exact object, then performs the manifest/feed/receipt
transition atomically in Postgres. Only after the returned owner/key/fingerprint
receipt is verified and persisted locally can the client mark its outbox row
acknowledged. Lost responses retry the same object bytes and idempotency key.

Orphan cleanup must not scan/delete arbitrary bucket objects. After the agreed
inactivity window, a DB lock changes only an unfinalized intent to
`cleanup_pending`; a cleanup worker deletes only its referenced staging object,
then changes that intent to `expired`. Delete failure stays retryable. The
idempotency tombstone remains; finalized objects/manifests are not in this
cleanup path. Partial upload, missing object, hash mismatch, and finalize
response loss each have distinct retryable/fail-closed cases.

## 5. Safe work completed / deliberately not done

- Existing local contract and fake staged client are sufficient to preserve the
  first milestone's client identity and staged-upload flow; no parallel client
  architecture is needed.
- Phase 7's partial physical result is recorded above; GPS source and test
  diagnostics were preserved. No Android test was run for this Phase 8 task.
- Production gate remains off. No import, remote sync, account write, existing
  Planet project operation, migration, project creation, credential read,
  APK operation, commit or push occurred.
- Backend SQL/Edge Function implementation is deliberately deferred: the local
  CLI/Docker/Deno validators are absent and a local Supabase project link marker
  exists but its target was not read. Writing/deploying unvalidated schema in
  that state would risk coupling Phase 8 to Planet or presenting untested RLS as
  safe.

## 6. Single next action

User approval is required before the first remote write: creating the private
bucket and applying/deploying the local M1 migration/functions to the explicit
Phase 8 target. Do not use the root Supabase workspace or its existing link.
The actual project region, current plan/quotas, project health, and disposable
test-account readiness have not been verified from the Dashboard. The local
Project Ref alone does not prove that the remote target is healthy or isolated.

## 7. Preparation update — separate project and M1 candidate files

The user supplied Project Ref `jidyfemjzztlwjmijndx` for the Dashboard-created
**DriveIt Phase 8 DEV** Free project. A Git-ignored local config at
`config/supabase.dev.json` contains only this ref and its derived project URL;
it contains no publishable key or secret. No command has contacted this ref.
The existing root `supabase/.temp` link marker was not read, overwritten, or
used.

An isolated CLI candidate workspace is prepared at `supabase/phase8-dev/` so
only its migrations/functions are selected. Candidate artifacts:

- `config.toml` with isolated project id and only the three M1 client-facing
  Edge Functions; root Planet config is unchanged.
- One additive `phase8_*` schema migration. It creates upload intents,
  immutable manifests, per-owner sequence/change rows, and bounded snapshot
  records; all tables have RLS enabled and no direct anon/authenticated table
  grants. Owner identity is passed only by the Edge layer after JWT validation.
- Private staging object RLS policy for exact owner/intent path insert only;
  there is no public access, client list/read/update/delete policy. The bucket
  itself must be created private through the Storage API/Dashboard after
  explicit approval, not by direct SQL against Storage metadata.
- Begin, finalize, and download Edge Function candidates plus a scheduled
  orphan cleanup candidate. Finalize re-reads exact staging bytes, verifies
  size/SHA-256/canonical v2/provenance, then calls a transactional DB finalizer.
  The DB transaction atomically writes manifest, one ordered change row,
  finalized intent, and receipt. Upload alone is never visible in download.
- Orphan recovery marks only >7-day unfinished intents `cleanup_pending` under
  row lock, removes only that exact object, and then marks the durable
  idempotency tombstone `expired`; failures remain retryable. Finalized objects
  are never selected for cleanup.
- Snapshot pages are fixed to an owner and high-water mark; the page endpoint
  verifies every object before returning any changes/cursor. A failed or
  oversized page returns no advanced cursor.
- Local SQL privilege checks and Deno canonicalization vectors are included.

These are **unvalidated candidates**, not deployment-ready evidence. This
Windows environment currently exposes Node.js and npx, but not Supabase CLI,
Docker, Deno, `psql`, or `pg_isready`. No dependency was installed. Therefore
SQL parser/RLS tests, Edge type checks, cross-language canonical vectors, and
local Supabase integration were not run. Do not deploy before those local
checks pass and the exact isolated target is explicitly approved. No Android
test or full Flutter suite was run for these server-only candidate files.

Node's TypeScript strip/parser check passed for the six candidate `.ts` files;
this is syntax-only and does not resolve imports or type-check Deno/Supabase
APIs. A targeted existing Flutter sync-client test was started but produced no
output and was stopped; it is not counted as passed. `git diff --check` and a
trailing-whitespace scan of the newly added artifacts passed.

Bucket creation, applying the migration, setting a server-only cleanup token,
and deploying the functions are all remote writes. Before any one of them,
show the user the target Project Ref and exact operation list and obtain
approval. No Auth accounts are created in this preparation step.
