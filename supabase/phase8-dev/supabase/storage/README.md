# M1 private staging bucket

Current approved/deployed target (2026-10-15): `DriveIT DEV` / Planet DEV
Project Ref: `viqngnjfgknpxtoapzcg`
Bucket: `phase8-drive-staging`

The original separate-Phase-8-project proposal is superseded by the user's
explicit same-Auth-project deployment approval. No deployment was sent to
`jidyfemjzztlwjmijndx`. See `docs/phase8_m1_planet_dev_deployment.md` for
the actual backup, migration, acceptance and remaining app-activation scope.

Create the bucket only after explicit user approval. It must be **private**,
with file-size limit no greater than 10 MiB and MIME allowlist
`application/json`. Do not create a public URL or add final-object writes.
The migration in this isolated workspace supplies RLS policies for object
insert only under `<verified-auth-uid>/<intent-uuid>/envelope.json` while the
corresponding intent remains in `staging`. There is deliberately no client
list/read/update/delete policy.

The upload adapter must use non-upsert Storage upload. If a retry receives an
object-exists response, it must call the authenticated finalize endpoint for
that same intent; the server downloads the exact object, verifies expected
size and SHA-256, and only then can it return the durable ACK. A mismatching
object must remain a conflict; never overwrite it.

Storage and PostgreSQL are not atomic. A successful upload alone creates no
manifest/change feed row. Only the finalizer may atomically create the
PostgreSQL manifest, ordered change row, finalized intent, and ACK receipt.
The referenced staging object is retained after finalization as the immutable
download source. The bounded cleanup endpoint is deployed with an independent
server-only token and a seven-day inactivity rule. No scheduler was created.
Wrong-token denial was tested remotely. Positive orphan cleanup was previously
tested locally; a global orphan sweep was deliberately not run on shared DEV.
