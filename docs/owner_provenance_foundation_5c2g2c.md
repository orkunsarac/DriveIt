# DriveIt — Provenance Foundation 5C.2G.2C

## Status and boundaries

This is a gated provenance foundation, not the World/Career import merge. The
central `LocalOwnershipGate.production` remains disabled. No production
bootstrap, normal foreground callback, real local data, account, or cloud path
was migrated or enabled. The acquisition journal remains SQLite schema v3;
the separate, dormant ownership sidecar is now schema v3 (sidecar v1 → v2 → v3
additive upgrades).

## Source identity model

`DriveSourceProvenance` (`lib/services/drive_source_provenance.dart`) separates
three concepts:

- `sourceIdentity`: random UUID v4, immutable and independent of `drive.id`;
- `ownerScope`: current local namespace, not part of source identity;
- `status`: `proven`, `unproven`, or `conflict`.

The source namespace/version is `drive_source_v1` / 1. A content fingerprint
may identify a particular archived bundle for retry bookkeeping, but is never
used to claim that two archives are the same actual drive. Missing old evidence
stays null/`unproven`; malformed identity is a conflict and fails closed.

The controlled GPS coordinator reserves owner + source identity + a planned
session UUID before creating the journal row. It then creates the journal under
that exact planned ID and binds the ownership row. If the process exits between
journal creation and binding, recovery can bind only when the exact planned ID
exists in that journal. An unrelated or old session cannot consume the
reservation. Existing v1 sidecar rows receive nullable columns only and stay
unproven; the v3 `planned_session_id` is not backfilled. The source UUID and
owner are immutable after preparation/binding.

## GPS → Hive proof

In the controlled owner-scoped path, transfer includes source identity/version
and namespace in the telemetry acquisition metadata and writes a second
owner-scoped `drive_source_provenance_v1` record. Read-back requires the two
identity values to agree. If interrupted after telemetry but before the second
record, retry can recover the identity from telemetry and durably complete the
separate record; disagreement blocks the transfer. The existing drive,
telemetry, journal, and receipt checks still apply before transfer completion
or journal cleanup. No Hive type ID or `DriveSession` Hive field changed.

This owner-scoped transfer is dormant/test-only today. The normal production
`GpsSessionStore.create()` keeps its pre-existing local-ID format and the
existing shared Hive transfer path has not been redirected. Consequently a
new ordinary production drive is **not yet guaranteed** to receive this source
identity; wiring it while the central gate is closed would violate the task's
production behavior constraint.

## World and Career references

`LocalSourceBundle` reads legacy v1 unchanged and optionally writes v2 with
typed provenance. World source snapshots preserve that optional evidence when
validation enriches a bundle. Current World source maps, validated roads,
traces, processed-drive lists, jobs, tombstones, lifecycle records, and rebuild
references still use local drive/road/trace IDs. No bulk remap or worldRules v6
algorithm change was made. Same local drive ID collisions remain a fail-closed
boundary for World source storage until a complete reference-closure mapping is
implemented.

Career can persist explicitly proven contributions under `source:<UUID>`;
legacy contributions retain `drive:<id>`, and old `countedIds`/aggregates are
untouched. Repeating the same identity/content is idempotent; same identity
with different content conflicts; distinct identities do not collapse just
because their local drive IDs match. Proven rows are exposed separately by
`provenContributions()` and are intentionally not folded into the existing
visible statistics, which still consume legacy `drive:<id>` rows. Legacy
cumulative-only totals remain unchanged and unresolved; no synthetic
contributions are generated.

Tombstones do not yet carry typed source identity. Existing owner revision
records can carry a source identity/namespace, but the generic revision
verifier is not connected to these new GPS/World/Career records. Therefore
this foundation does not establish World tombstone scope, trace remapping,
score provenance, or publishable revision verification.

## Files changed in this task

- `lib/services/drive_source_provenance.dart` — typed identity/status model,
  secure UUID v4, archive fingerprint helper.
- `lib/services/gps_session_ownership.dart` — sidecar v3, additive migrations,
  planned-session recovery binding, immutable identity.
- `lib/services/gps_session_store.dart` — optional caller-specified opaque ID
  for controlled coordinator; ordinary generated ID behavior unchanged.
- `lib/services/owned_gps_session_coordinator.dart` — identity reservation,
  deterministic binding/recovery, provenance-required controlled transfer.
- `lib/services/gps_session_transfer.dart` — provenance-aware optional transfer
  contract and exact read-back verification.
- `lib/services/scoped_gps_transfer_sink.dart` — owner-scoped provenance record
  and telemetry evidence cross-check.
- `lib/services/owner_scoped_local_store.dart` — provenance box included in
  owner namespace/inventory.
- `lib/services/local_source_bundle.dart` — backward-compatible optional v2
  provenance.
- `lib/features/my_world/repositories/world_source_snapshot_repository.dart`
  — retain optional provenance when attaching validation data.
- `lib/services/career_contribution_repository.dart` — separate proven source
  contribution key space and strict conflict handling.
- `lib/services/owned_foreground_bootstrap.dart` and
  `lib/services/local_owner_gps_bridge.dart` — recover exact planned binding.
- `test/gps_session_ownership_test.dart` — sidecar upgrade, identity persistence
  and crash-window tests.
- `test/scoped_gps_transfer_test.dart` — sink persistence and owner isolation.
- `test/drive_source_provenance_test.dart` — legacy/v2 bundle and Career
  provenance tests.

Pre-existing A5 changes and untracked files were preserved; `tatus` was not
read, edited, staged, or deleted.

## Verification and remaining work

Targeted tests cover UUID/owner separation, sidecar reopen, v1 sidecar upgrade
to unproven, planned binding recovery, transfer retries and target-owner
isolation, v1 bundle compatibility, v2 provenance round-trip, archive-fingerprint
non-identity, and Career source-key idempotency/conflict. No real Android
process-kill, device, backend, or account test was run.

Final verification: `flutter test --timeout=2m` passed 839 tests with 2
conditional skips; `flutter analyze` reported only the repository's 4 existing
info-level notices (no new warnings/errors); `git diff --check` passed.

Before World/Career merge, add typed provenance to all source/road/trace/job/
tombstone/lifecycle references, define and test complete deterministic remap
closure, connect production source creation under a separately approved gate,
make score/career/history references provenance-aware, and implement real
World/Career revision staging plus domain verifiers. The old public views and
aggregates must remain unchanged until those verifiers all pass.
