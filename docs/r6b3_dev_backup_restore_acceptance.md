# R6-B3 — DEV manual backup and restore acceptance

**Status: PASS for the encrypted backup and isolated database restore.**

**R6-B4 qualification:** The restored SQL/data and Storage bytes remain verified, but subsequent catalog inspection found that the captured SQL omitted event-trigger definitions and `extensions` schema grants. Current DEV has the `ensure_rls` event trigger and service-role USAGE on `extensions`, neither present in the restored test database. The exact DEV event-trigger state at backup time was not separately recorded. This backup alone is therefore not a complete security-configuration restore; see [R6-B4 evidence](r6b4_security_http_acceptance.md).

Scope was limited to DEV project `viqngnjfgknpxtoapzcg`. No DEV or PROD write, migration, Function deployment, account change, or plan change was performed.

## Encrypted artifact

- Local location: `%LOCALAPPDATA%\DriveIt\Recovery\R6B3-DEV-20261103-013444-8089709d\driveit-dev-full-backup.zip.dpapi`
- Encryption: Windows DPAPI, CurrentUser scope; the same Windows user profile is required to decrypt.
- Size: 2,406,294 bytes.
- SHA-256: `d0d893b62f95e9d461b5f23c66f3c2e6af453fa1a0e22b48fe4ea474d3cbf286`
- The adjacent `manifest.json` records the artifact hash, size, creation time, scope, and ACL checks. The encrypted archive contains a per-file manifest with SHA-256, byte size, UTC modification time, and scope for all 80 payload files. The archive's DPAPI decrypt/hash round trip matched its pre-encryption hash; all 80 payload files were verified against the internal manifest.
- Backup directory inheritance is disabled. Its access list contains only the current Windows user and `SYSTEM`.
- Plaintext staging files were removed after verification. The isolated restore stack was stopped without deleting its data.

## Backup coverage

- PostgreSQL 17.6 role settings and schema/data dumps for `public`, `auth`, `storage`, `realtime`, `supabase_migrations`, `vault`, `graphql`, `graphql_public`, and `pgbouncer`.
- Auth users and related Auth rows, database migration history, RLS flags and policies, public RPCs, triggers, grants/revokes, and Storage metadata are present in the SQL exports.
- DEV inventory at export: 16 Auth users; 22 applied migration rows; 17 public tables; 39 public functions; 11 policies; 41 RLS-enabled tables; 17 non-internal triggers; 2 Storage buckets; 49 Storage objects totaling 10,875,036 bytes; 0 Vault secrets.
- The 31 database roles were Supabase-provided roles; no custom role definitions were present. The role dump contains role settings and a parameter grant, not role passwords.
- All 49 Storage object byte files were downloaded separately with Supabase CLI. Their paths and aggregate byte count matched the remote metadata inventory. Object files are not included in a database dump alone.
- Source for all 9 deployed Edge Functions (24 files), function versions/status/`verify_jwt` inventory, secret names, and the Auth-settings availability result are included. Secret values are excluded. Auth/provider settings could not be read through the unauthenticated public settings endpoint.
- The bundle does not contain provider credentials, Edge Function secret values, Auth/SMTP configuration, JWT signing secrets, or extension binaries. Those settings must be restored from a separately secured source or rotated/recreated. Compatible extension versions must be installed by the target Supabase image.

## Isolated restore evidence

A unique local Supabase stack and a new `r6b3_restore` database created from `template0` were used. No existing local test database was reset, dropped, truncated, or restored over. The SQL role settings, required extensions, schema, and data restored successfully in transactions.

Source DEV and restored database matched on aggregate counts, migration history fingerprint, complete Auth user row fingerprint, complete canonical row fingerprints across all 17 public tables, and complete Storage object metadata row fingerprint:

- Migration history fingerprint: `b5699e799aad140892389370ca7ca98f`
- Auth user row fingerprint: `510982c1125188217322a20cf5d6212e`
- Public-table row fingerprint: `877c1950cd11e7c53d7660f2a9f81aa0194f8d21b1ff539f9805342e7303b6f7`
- Storage object metadata fingerprint: `cda72919ca315134dbc2cf570afbb27f`

The restore reproduced 16 Auth users, 22 migration rows, 2 buckets, 49 objects, and 10,875,036 object bytes. The restored Vault contained zero secrets. The local stack was stopped after acceptance; its test data remains isolated in its own Docker volume.

## Recovery limits and references

This artifact supports recovery from a database loss and Storage object loss when the encrypted bundle and Windows user profile remain available. It does not protect against loss of this PC/profile because the only copy is local. A second encrypted copy in an access-controlled off-device location would be needed for that failure case. DPAPI CurrentUser is tied to this Windows profile.

Supabase documents that Free projects have no automatic backups, that database backups omit Storage object bytes, and that Auth settings, Edge Functions, and Storage files need separate recovery steps:

- [Database backups](https://supabase.com/docs/guides/platform/backups)
- [Supabase CLI `db dump`](https://supabase.com/docs/reference/cli/global-flags)
- [Storage object download](https://supabase.com/docs/guides/storage/management/download-objects)
- [Backup and restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
- [Restore to a new project](https://supabase.com/docs/guides/platform/clone-project)
