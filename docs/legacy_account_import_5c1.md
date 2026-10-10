# Phase 5C.1: dormant, verified legacy import

No production caller. `LocalOwnershipGate.production` remains OFF. The Android
channel only registers private-directory capacity/fsync methods; registration
does not open a ledger, import anything, change Auth or start GPS.

## Files added/extended in 5C.1

- lib/services/legacy_import_inventory.dart
- lib/services/legacy_asset_transfer.dart
- lib/services/legacy_claim_ledger.dart
- lib/services/legacy_account_import.dart
- lib/services/owner_scoped_local_store.dart (additive drive_posters group)
- android/app/src/main/kotlin/com/example/driveit_project/LocalImportStorageBridge.kt
- android/app/src/main/kotlin/com/example/driveit_project/MainActivity.kt
- test/support/legacy_import_fixture.dart
- test/legacy_account_import_test.dart
- integration_test/legacy_account_import_android_test.dart
- docs/legacy_account_import_5c1.md
- docs/local_owner_lifecycle_5c_status.md

Earlier uncommitted 5A/5B/5C files are retained; no commit/push/branch change.

## Inventory and provenance

| Source | Durable data / relationship | Import treatment |
|---|---|---|
| drives | DriveSession, original ID, date meaning, route/segment metadata, mapImagePath | Existing binary adapters, including RoutePoint reserved legacy fields; only detached destination mapImagePath changes |
| drive_telemetry | Ordered original samples, versions, coverage/time metadata | Binary copy; key must match source drive |
| drive_scores | Persisted v1 result/category/confidence metadata | Binary copy, no recalculation; source key checked |
| drive_names, drive_details_v1 | Names/detail metadata | Binary copy; unrecognized nonempty file-path fields reject inventory |
| drive_posters | Drive ID, theme/logo/layout/labels, exported PNG and editable background aliases | Lossless raw metadata copy, both alias pairs retargeted together |
| documents/posters | Saved PNG/background, including unreferenced orphan files | Hash-verified private asset copy, no invented drive association; .tmp/.part excluded |
| DriveSession.mapImagePath | Existing persisted preview/map reference | Referenced file is mandatory even if it could theoretically be regenerated |
| career_totals, career_contributions_v1 | Original totals/baseline, drive/score contributions, original metric basis | Preserve raw basis; bundle ownerScope changes in detached destination only |
| symbolic_routes | Legacy route metadata | Preserve exact binary content |
| my_world_validated_roads, my_world_processing | Geometry, section/source IDs and processing metadata | Preserve, validate source/road links |
| my_world_index_snapshots, my_world_index_metadata | Generation history, traces and active pointer | Preserve generations/IDs; verify pointer and trace/source/road/section relationships |
| my_world_source_snapshots_v1 | Independent source, readiness/revisions/history | Preserve raw metadata and bundle contents; explicit ownerScope retargeting |
| my_world_pending_jobs, local_lifecycle_v1, my_world_settings | Jobs, intent/tombstone and world preferences | Private partition copy; no job execution, deletion or rebuild |
| profile | Avatar bytes, profile/preferences, including existing device/onboarding flags | Binary copy; no inferred Auth ownership and no new preference behavior |
| planet_segment_outbox_v1 | Segment ID/source, pending/mock/server facts | Source/payload ID preserved; local owner/key scoped; accepted publication with unproven owner is refused |
| local_publish_state_v1 | Future/local server receipt metadata | Copy only; conflicting embedded owner refused, no server mutation |
| derived_cache_v1 | Rebuildable derived cache | Conservatively copy existing entries, never use cache as ownership proof |
| GPS SQLite v3 + ownership sidecar | Unfinished acquisition/session/transfer facts | NOT imported; existing 5A/5B transfer/recovery contract remains responsible |
| SharedPreferences/foreground storage | Device permission/settings and active GPS flags | NOT account-adopted, cleared or rewritten |

There is no separate production `career` or `world_trace` Hive box: Career uses
totals/contributions; active traces live in World snapshots. Unknown on-disk Hive
boxes cause refusal, not silent omission. Caller must explicitly open/include all
known existing personal boxes with their original typed adapters.

File sources: `PosterStore.save` persists chosen backgrounds to app documents;
share PNGs and diagnostic JSON in temporary storage, unsaved crop/picker previews
and rendered in-memory canvases are cache, not durable editable poster records.
Gallery export returns a `content://` URI but does not persist a readable ownership
source grant. The importer has NO ContentResolver/persistable URI grant fallback:
content URIs, inaccessible/missing files, paths outside explicit private roots,
path traversal and symlinks fail closed. No claim of importing external gallery
contents or undocumented unreferenced directories is made.

Android path-provider roots must be canonicalized by the trusted caller before
constructing this strict importer. The native fixture does so: a system alias
above the sandbox was rejected by the initial symlink guard. The guard is not
weakened to silently follow arbitrary persisted links. Inaccessible/noncanonical
legacy references require explicit review, not a successful import receipt.

`LocalSourceBundle` v1 intentionally removes mapImagePath for independent World/
Career processing. It remains unchanged and is never used as the History backup.
The new version-1 import inventory retains full binary records plus separate file
descriptors, hashes and relationships. Original source paths stay in source
records; destination references point only to that claim's private asset directory.

## Durable claim and visibility

Separate SQLite ledger v1, WAL + FULL + busy_timeout, with foreign keys:

- canonical legacy namespace PRIMARY KEY; operation ID UNIQUE;
- immutable namespace/fingerprint/UUID/operation identity;
- reserved -> copying -> completed, timestamps/attempt count;
- record receipts (source group/key/hash, target key/hash), file receipts
  (identity/hash/size/private relative path); immutable after completion;
- completion evidence and receipts commit in ONE SQLite transaction.

The source namespace comes from the canonical original Hive directory, not a
user-entered ID. A reservation never changes owner, even on failure. A different
fingerprint is not automatically merged into a previous claim. SQLite write
locking serializes staging for a claim across connections/processes. Busy/locked
requests fail safely and may be retried; no lease stealing or memory-only lock.

5B quarantine paths are deliberately refused as claim sources: their old
manifest does not prove canonical original-directory provenance. Import uses the
original preserved legacy store, avoiding a second namespace for the same copy.
Relocated/backed-up sources require a future reviewed provenance contract; they
are not automatically treated as a new account-adoptable inventory.

Staging Hive boxes and assets are physically separated from live owner stores:
`legacy_imports_v1/<deterministic operation SHA>/...`. No partial copy is promoted.
Only `openVerified`, with a completed ledger and a CURRENT matching UUID/epoch
lease, returns a read-only verified partition. It reopens Hive, verifies hashes,
counts/order, relations and files. Actual screens do not consume it yet (5C.2).

The importer checks consent before each write boundary and file chunk, and again
before SQLite commit. All source records/files are retained. Completed imports
are immutable evidence partitions, not writable live repositories.

## Files, capacity and recovery

64 KiB streamed reads/writes and SHA-256, not whole-image reads. Capacity estimate
includes file sizes, 3x serialized Hive payload and max(8 MiB, 10%) safety margin;
each file also rechecks free space. Android uses StatFs, and Os.fsync on private
directories. Temporary .part file is flushed, hashed/read back, then renamed;
directories are synced before completion. Existing differing final file/record
is NEVER silently overwritten. Same-operation partial .part may be truncated
and recopied; originals are never deleted.

SQLite write transaction remains open across staging/verification. This is a
deliberate correctness tradeoff: slow imports block other ledger writers and
can produce safe SQLITE_BUSY retries. It is not a distributed transaction across
Hive/files. Crash rolls back ledger completion/receipts, leaving an invisible
recoverable workspace; retry uses the same fixed owner/operation. Lost UI response
after commit opens the same completed partition instead of copying/counting twice.

Payloads are handled one record at a time (64 MiB per-record safety limit), with
O(record count + asset count) descriptors. Hive itself retains open-box objects
in memory; total-process memory is NOT claimed constant. The large-image test
proves chunk bound, not arbitrary-scale low-memory Android acceptance.

## Remaining acceptance limits

Synthetic failures are not Android process-kill/power-loss tests. Real disk-full,
real-user gallery permissions and real-device import remain untested. Symlink
guards assume an app-private workspace (not an adversarial concurrently writable
shared directory). Scope switching/screens/live GPS remain OFF. Accepted remote
publications with uncertain local ownership and undocumented file schemas require
explicit review; no guesses or bypasses are permitted.

Live activation must also quiesce legacy writers during adoption: fingerprints
are checked before and after the copy, but there is no cross-Hive global read
transaction against unrelated future writers. New data after the approved
snapshot is never deleted or silently merged. Changed manifests require review.

## Verification recorded for this phase

- Initial full Flutter: 702/702. Final full Flutter: 730/730, `--timeout=2m`.
- Import fault/race/file tests: 27/27 in the final full suite. A large image
  (161 x 64 KiB, about 10 MiB) copies in <=64 KiB chunks; 501 metadata rows retain
  the exact source Hive iterator order. No claim of measured peak process RAM.
- Android emulator: 27/27 across separate serial runners: new native import 1,
  existing owner lifecycle/scoped transfer/sidecar/lifecycle/legacy Hive 18,
  GPS/SQLite 8. Real native StatFs, directory fsync and SQLite are exercised.
- Final analyze: only the existing four info diagnostics; no new errors/warnings.
- Initial new-test failures were corrected: Android SDK does not expose
  O_DIRECTORY (opened descriptor is now checked with fstat); trusted Android
  path alias canonicalization; a test wrongly assumed Hive insertion order.
- FFI A/B connection racing may yield a safe SQLITE_BUSY loser; after the writer
  completes, that other owner is definitively refused by the durable claim.
- Crash points are controlled exceptions (including committed-response-lost),
  NOT actual Android process-kill or power-loss. No real-user import, A55 install,
  Supabase operation, production activation, commit or push was performed.
