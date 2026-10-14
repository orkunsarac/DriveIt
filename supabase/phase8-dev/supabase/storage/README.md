# Phase 8 DEV staging bucket (manual remote write; not performed)

Target project name: `DriveIt Phase 8 DEV`
Target Project Ref: `jidyfemjzztlwjmijndx`
Bucket: `phase8-drive-staging`

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
download source. Orphan cleanup (seven-day inactivity) is intentionally not
deployed in Milestone 1; it needs a separately tested bounded cleanup worker.
