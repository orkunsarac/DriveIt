# Phase 5B: dormant local ownership storage v1

## Activation boundary

No production bootstrap, Auth listener, screen, foreground isolate, global Hive
path or GPS transfer caller opens this layer. There is no remote gateway.
Phase 5A files remain intact. SQLite acquisition journal stays version 3 and
the ownership sidecar stays version 1. No real data preparation runs at startup.
This is local isolation, not a server authorization or encryption boundary.

## Inventory and namespace

Current production opens `drives`, `career_totals`, `symbolic_routes`,
`drive_names`, `profile`, `drive_telemetry`, `drive_scores`,
`my_world_validated_roads`, `my_world_processing`, `my_world_pending_jobs`,
`my_world_index_snapshots`, `my_world_index_metadata`, `my_world_settings`,
`my_world_source_snapshots_v1`, `career_contributions_v1`, `local_lifecycle_v1`
and `planet_segment_outbox_v1`. Active traces live inside index snapshots, not
in an independently opened `world_trace` box. There is no opened `career` box.
Unknown historical box names require explicit inventory review, not omission.

Consumers include DriveStorageService/history/detail/poster, telemetry and score
storage, Career, MyWorldRuntime/rebuild, independent deletion and Planet segment
publishing. These still use their existing shared stores. MyWorldRuntime's static
generation cache must NOT be reused when Phase 5C activates scoped stores.

`GpsOwner.targetStore` is the canonical versioned scope, derived only from kind
and canonical Supabase UUID. Guest and legacy are distinct. A separate HiveImpl
instance is opened at `<explicit root>/owner_stores_v1/<sha256(scope)>` with its
own exact identity marker. Existing unmarked/conflicting files fail closed.
All adapter types are reused. New dynamic detail/publication/cache groups do not
change old adapters. Hive 2.x internal registry and binary-clone APIs are confined
to this seam; dependency upgrades require compatibility regression tests.

Each store is frozen to an owner. Read/write APIs require matching context and
return binary-detached objects. Career/World/outbox facade freezes this owner;
contribution and source bundle owner must also match. Identical `drive:<id>`
identities in different directories cannot combine. World index receives its own
lifecycle journal/queue; its validation/CAS/flush ordering remains the existing
implementation. Pure tombstone filtering is shared with the old global journal.
History deletion requires an independent source and verified Career basis before
the durable deletion intent; it never purges other owners or World/Career data.
Canonical trace tombstones require full span metadata; the simple intent API
explicitly refuses to invent it.

## Legacy copy-only preparation

Caller supplies a stable source identity and a read-only inventory of **all**
personal boxes. The service never closes, flushes or modifies source boxes.
Capture serializes current adapter-visible fields (including RoutePoint legacy
pass-through), not an invented JSON summary. Embedded owner IDs and legacy outbox
keys are retained, never relabeled. Existing account ownership is not inferred
from current Auth. All unproven imports are quarantined, not enabled as account or
guest records. Old source files are always retained.

Order: fingerprint + durable intent → conflict-checked copy + flush → complete
record/count read-back → source fingerprint recheck → pointer/road/section relation
checks → versioned `verified_quarantine` manifest. `activationAllowed=false` is
always retained. Whole adapter payload comparison covers geometry, metadata,
scores, contribution basis, pending jobs, tombstones and snapshot history.
Missing pointer/active road/section relations fail closed, without inventing data.
Source changes, unknown groups or destination conflicts require review.
Preparation serializes per namespace and repeating it does not add records.
Flush acknowledgement faults leave resumable copies. The tests separately reopen
Hive to verify disk recovery; the regular read-back is from the flushed open box.

This is not automatic migration, account adoption or consent UI. Non-Hive files
(poster images/avatar paths) are not copied; stored paths are preserved and sources
are not removed. Future activation needs a complete external-file inventory too.

## GPS transfer and cleanup

ScopedGpsTransferSink captures a ready sidecar binding and refuses other session
IDs or destinations. OwnedGpsSessionCoordinator still validates the persisted
binding before touching the sink. Auth is not reread during save. Stable session
ID and existing journal transfer intent prevent duplicate saves. Handoff uses the
existing projection and telemetry verification; no score/GPS rules are changed.

Cleanup remains explicit and dormant. It requires the matching persisted binding,
verified sidecar receipt, verified journal receipt, fresh exact Hive evidence and
the existing 30-day maintenance/active-session guards. It rechecks owner/evidence
inside the existing cleanup callback. Errors are propagated, not treated as proof
of success. Two SQLite files and Hive are NOT one transaction; an incomplete
handoff retains the journal and is retried into the same destination.

## Caches, jobs, outbox and future activation gates

OwnerViewBarrier captures scope + epoch; even A→B→A invalidates the old future.
Errors from an obsolete read view are also fenced; current-owner errors propagate
unchanged. This UI read fence must never be used for durable write operations.
Cache keys include scope (and callers must include data/generation versions).
Frozen repositories let jobs finish only in their original namespace. Logout
is not deletion. Real Auth switching and active-drive switching guards are not
installed until Phase 5C.

Outbox uses unchanged segment payloads/IDs, a frozen owner and a permanently
disabled gateway in this facade. Legacy owner-uncertain entries remain quarantine
evidence. Neither queued/mock/awaitingValidation entries nor local copies become
public Planet traces. Existing accepted server records are never changed.

Before Phase 5C: explicit consent/ownership-conflict review, full external-file
inventory, app-private Android backup/rollback strategy, auth/UI epoch wiring,
active-session switching policy, and native synthetic interruption acceptance.
Cross-box atomicity and pointer-flush uncertainty remain the existing limitations;
controlled exceptions are not Android process-kill or power-loss proof.
The detached legacy inventory currently lives in memory; large real collections
need a bounded/chunked preparation strategy before production activation. This
does not authorize opening or preparing the user's existing A55 stores.
