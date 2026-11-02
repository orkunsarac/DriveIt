# R6-B2 — local DEV restore migration rehearsal

**Overall: BLOCKED on security-catalog parity and full Edge/Storage acceptance.** No DEV or PROD SQL, deployment, or account operation was performed.

## Planet bootstrap parity — PASS

A new local reference was built from the two hash-checked Planet bootstrap files followed by the 22 existing migrations. `tool/r6b2_planet_catalog.sql` and `tool/r6b2_planet_parity.ps1` compared 122 catalog records with a fresh DEV backup restore: all matched. The comparison covers the four bootstrap tables, columns and collations, constraints, indexes, four bootstrap functions and effective ACLs, triggers, RLS and policies. Function line endings and equivalent default ACL ordering are normalized. The bootstrap files were never applied to the DEV restore copy.

## 52-migration rehearsal — partial PASS

On the separate restore database, the two bootstrap ledger entries were recorded only after parity passed. The Group Drive gate migration and 27 deletion migrations were applied in order with manifest SHA-256 checks. The ledger has 52 records. Group Drive's gate is false; synthetic create and publish calls returned SQLSTATE `42501` / `group_feature_disabled`. The 20 existing finalized drive manifests had identical count and canonical row fingerprint before and after the migration chain.

The first local run used `supabase_admin`, causing the existing Planet security test to report `unsafe_planet_rpc_definition`: 11 security-definer functions were owned by `supabase_admin` rather than `postgres`. A new restore was created and the chain was rerun under `postgres`. Initially, its fresh database was owned by `supabase_admin`, so the gate failed with SQLSTATE `42501`, `permission denied for schema public`. After setting the **new local database** owner to `postgres`, the existing 24 ledger entries and their bootstrap SQL hashes were verified, the absent gate was confirmed, and the forward chain completed. No production or existing local stack ACL was altered.

## Security catalog — BLOCKED

`tool/r6b2_security_catalog.ps1` compares the restored 52-migration catalog with a second clean, hash-checked 52-migration reference built under `postgres`, using the existing production policy-audit query. All 16 policies and all 29 public triggers matched; 22 public tables were present in each. Function bodies matched after line-ending normalization. The comparison found the following real effective privilege differences, all on `service_role`:

| Object | Clean reference | Restore copy |
| --- | --- | --- |
| `phase8_drive_leases` DELETE | allowed | denied |
| `phase8_drive_tombstones` DELETE, UPDATE | allowed | denied |
| `phase8_can_access_staging_object(text)` EXECUTE | allowed | denied |
| `phase8_group_command(text,uuid,text,uuid,boolean)` EXECUTE | allowed | denied |
| `world_section_geometry_length_meters(extensions.geometry)` EXECUTE | allowed | denied |

The restore also contains `public.rls_auto_enable()` (owner `postgres`, security definer, default ACL), which is absent from the clean reference; no event trigger references it in the restored catalog. There are 74 reference functions and 75 restored functions. The catalog comparison raises a PowerShell mismatch error, not a PostgreSQL SQLSTATE. The difference was not repaired by granting privileges or dropping the extra function. The precise required follow-up is to establish the approved DEV-specific/default-privilege contract and managed origin of the extra function, then verify whether the narrower grants support the official runtime. Any server-side correction requires its own reviewed change and authorization.

## Targeted tests

- Existing `planet_rebuild_security.sql`: PASS, 11 worker/Planet RPC owner, security-definer, search-path and effective-grant checks.
- Existing `audit_retention.sql`: PASS, transactional synthetic fixture and rollback.
- Existing `planet_rebuild_test.ts`: 10/10 PASS.
- `tool/r6b2_group_gate_test.sql`: PASS for create and publish rejection; synthetic fixture rolled back.
- `tool/r6b2_deletion_isolation_test.sql`: PASS for synthetic A/B finalized drives, request, wrong-receipt rejection, correct claim, owner A purge, refusal to complete while Auth exists, and preservation of B. The transaction was rolled back.

These SQL tests do not exercise Edge Function password verification, actual Storage object removal, or HTTP receipt recovery. The existing full HTTP test fixture uses `session_replication_role=replica` during cleanup, so it was not run under this task's prohibition on weakening FK/trigger protections. A compliant isolated HTTP fixture that cleans up through the official flow is still required before claiming that full path passes.

Scripts and tests touch only the explicitly named local rehearsal/reference containers. The immutable encrypted backup and pre-existing local test stacks were preserved.
