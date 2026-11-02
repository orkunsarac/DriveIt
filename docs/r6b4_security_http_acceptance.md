# R6-B4 — DEV privilege baseline and isolated HTTP acceptance

**R6-B4: PASS for the six effective privileges and the isolated HTTP deletion path.** DEV was queried only for catalog metadata; no DEV/PROD write or deployment was performed. The pre-existing restored 52-migration database and its 20 finalized manifests remain intact.

## Six service-role differences

The six effective denials in the R6-B3 restore exactly match current DEV. They did not arise from this restore. Current DEV `postgres` default ACLs in `public` differ from the clean local reference: new tables do not receive `service_role` UPDATE/DELETE by default, and new functions do not receive its EXECUTE by default. PostgreSQL default privileges affect creation of future objects and do not establish when an existing grant changed; the historical intent and exact timing cannot be inferred from the present catalog. The observed permissions match the narrow explicit migration grants and the exercised runtime contract. No grants were added.

| Effective DEV denial | Source and runtime evidence |
| --- | --- |
| `phase8_drive_leases` DELETE | The fencing migration explicitly grants service SELECT/INSERT/UPDATE. Real HTTP lease acquisition and heartbeat succeeded; the owner-bound `account_deletion_purge` definer removed the lease during B's official deletion. |
| `phase8_drive_tombstones` DELETE and UPDATE | The fencing migration explicitly grants service SELECT/INSERT; the tombstone trigger protects mutation. Real HTTP tombstone creation succeeded and A's account purge removed the tombstone under the owner-bound definer. |
| `phase8_can_access_staging_object(text)` EXECUTE | The migration grants authenticated EXECUTE for the owner-scoped Storage insert policy. Authenticated staged uploads and real finalize succeeded; service-role direct EXECUTE remained denied. |
| `phase8_group_command(text,uuid,text,uuid,boolean)` EXECUTE | The migration grants authenticated EXECUTE. The authenticated HTTP RPC reached the server gate and rejected create with `group_feature_disabled`; the publisher uses `phase8_group_accept_location` instead. Service-role direct EXECUTE remained denied. |
| `world_section_geometry_length_meters(extensions.geometry)` EXECUTE | Service direct EXECUTE remained denied. An isolated synthetic zero-distance section caused service-callable `world_map_section_prefix` to invoke the helper inside its `postgres` SECURITY DEFINER boundary and return a positive length. |

`tool/r6b4_role_runtime_test.sql` also executes all six denied direct operations under `service_role` and checks SQLSTATE `42501`; its synthetic geometry fixture rolls back. `account_deletion_purge` was verified `SECURITY DEFINER`, owned by `postgres`, executable by `service_role` and not by `authenticated`; the HTTP test exercised its purge of actual lease, tombstone and finalized rows. The source-to-default-ACL explanation does not claim a provable historical creation timestamp. [PostgreSQL default-privilege documentation](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html) explains the creation-time scope.

## `rls_auto_enable` and backup qualification

Current DEV has `public.rls_auto_enable()`, owner `postgres`, SECURITY DEFINER, `search_path=pg_catalog`, default PUBLIC EXECUTE and `event_trigger` return type. Its normalized function-definition MD5 is `6998ea6b4c2480f5d2e34b5dcf3f8d36`. Its catalog dependency is the enabled `ensure_rls` event trigger, owned by `postgres`, on `ddl_command_end` for `CREATE TABLE`, `CREATE TABLE AS` and `SELECT INTO`. No textual function references were found in `public`, `auth`, `storage` or `realtime`; dynamic external callers cannot be ruled out. No defining migration was found in the reviewed repository sources, so the origin is not established.

The function attempts to enable RLS for new `public` tables and logs/skips other schemas. Its exception handler logs failures rather than aborting table creation, so it is not a fail-closed substitute for explicit RLS verification. A transaction in the isolated HTTP stack reproduced the live function body and a matching event trigger with function owner `postgres`; a newly created public table had RLS enabled. The transaction rolled back. The trial did not grant additional function permissions.

Current DEV has `ensure_rls`; the R6-B3 restored database does not. Inspecting the encrypted `full-schema.sql` showed no `CREATE EVENT TRIGGER` and no `extensions` schema GRANT statements. Current DEV grants `service_role` USAGE on `extensions`; the R6-B3 restore test database did not. The function body itself was captured. These facts qualify the previous R6-B3 result: the SQL/data and Storage byte restore passed, but it was not a complete reconstruction of event-trigger or extension-schema ACL security configuration. The exact event-trigger state at backup time was not separately recorded. Recreate and verify this metadata through a separately reviewed recovery procedure before relying on the backup for full service/security restoration. No backup was changed during R6-B4.

## Real local HTTP acceptance

In a separate, pinned loopback Supabase stack with the six DEV restrictions reproduced by REVOKE only, the test used real Auth, Storage and the `delete-account`, Phase8 begin/finalize/download/lease/delete Edge Functions. No FK, RLS, trigger or replication-role bypass was used. Signup and Group Drive remained closed.

- Two synthetic users had three real finalized drives created through begin/upload/finalize; A also had a real file in a second private bucket. B could not read A's staged source.
- Wrong password and mismatched owner were rejected. A's valid password-authenticated request succeeded; a wrong receipt was rejected.
- The first receipt run removed one bucket and returned pending while A's Auth user and finalized rows remained. Subsequent receipt resume removed A's Storage objects and owner-scoped private rows, then Auth, and returned completed.
- B's Auth, finalized drive, Storage object and lease survived A's deletion; B's official download succeeded. B was then removed through its own password request and receipt workflow. Both synthetic Auth accounts and their owner-scoped private data were absent afterward.
- A repeated completed receipt returned completed idempotently; a new request with A's stale token was rejected. Existing local 52-migration restore still had 52 ledger entries and 20 unchanged manifest rows.

The first test attempted direct client download of a finalized Storage object and failed because the contract deliberately permits direct client access only during staging. The check was corrected to inspect stored bytes with the server client and use the official authenticated download Edge Function. Its encrypted journal enabled B's official cleanup; a fresh full test then passed, followed by a second full run with lease and tombstone coverage.

## Local synthetic credential output incident

During recovery of the first local fixture, a PowerShell console-output/pipeline mistake printed synthetic test credentials and receipt values into a tool result. Both affected synthetic Auth accounts were subsequently confirmed deleted through the official local flow; the receipt applies only to the isolated loopback stack. No DEV/PROD credential or user was involved, and no secret was committed. The journal reader was changed to use capturable pipeline output and now verifies its restricted Windows ACL. Future test journals remain encrypted under the current Windows user profile.

## Reproduction

`tool/r6b4_catalog.sql` and `tool/r6b4_event_catalog.sql` are read-only metadata queries. `tool/r6b4_test_dev_restrictions.sql` applies only narrower permissions to the unique isolated HTTP stack. `tool/r6b4_role_runtime_test.sql`, `tool/r6b4_event_runtime.ps1`, and `tool/run_r6b4_http.ps1` provide the targeted local checks. The HTTP runner checks loopback URL, stack label and physical PostgreSQL identity and writes an encrypted local recovery journal. The existing local preparation runner was fixed to tolerate the copied Function directory and avoid a duplicate config section.
