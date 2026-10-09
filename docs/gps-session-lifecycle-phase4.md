# GPS reliability Phase 4 — journal lifecycle

## Audit and scope

Phase 1–3 already provided WAL/FULL durability, session-scoped monotonic append,
checkpoint restart parity, explicit stop/drain receipts, segment gaps and a
recoverable stopped journal. This stage does not alter their filters, sequence
allocation, Hive field IDs (including RoutePoint 254), scoring or World rules.

Gaps found: unverified save acknowledgements; deleting partially written Hive
telemetry on save failure; changing the save date on retry; independent career
counter writes; unbounded pending GPS futures; no archived-session retention
policy or explicit selection of orphaned pending sessions.

## Lifecycle

`GpsSessionStore.lifecycle` deterministically derives ACTIVE (producer running),
RECOVERABLE (recording, producer absent), PENDING_SAVE (stopped, no intent),
SAVING (stopped with intent), VERIFIED (saved with verified receipt) and
RECOVERY_REQUIRED (error/unknown/unverified legacy archive). Acquisition's
recording/stopped/saved columns keep their existing meanings.

Schema v3 is additive metadata only: `session_transfers` and immutable
`journal_maintenance`. Upgrades do not rewrite any point or historical Hive
record. Session events record save/verification and producer start/drain epochs.
Legacy saved journals without proof stay ineligible for deletion.

## SQLite → Hive

A stopped journal must have contiguous sequence 1..N and a drained receipt N.
Before writes, persist an immutable manifest with stable session/drive ID and the
first save's summary/date. Source telemetry is read from that ID's journal, not
the UI list. The route projection uses the existing first/break/positive-distance
policy, so route count intentionally differs from telemetry count.

The coordinator checks route, distance, any existing drive and full canonical
telemetry content, including microsecond times, UTC flag and quality. It writes
only missing Hive records, flushes both boxes, reads them back and verifies
content before the atomic SQLite VERIFIED receipt and pointer release.
Canonical transfer/UI reads page 128 raw rows at a time and omit checkpoint
objects from their in-memory projection. Stored checkpoints and the producer's
single-tail recovery read remain untouched; no Android JSON1 dependency added.
Conflicting records are never overwritten. Partial records are never deleted.
Local in-flight coalescing prevents duplicate save actions. Across restarts the
durable intent/IDs prevent duplicates and preserve the original date. A legacy
partial Hive drive may supply the original manifest only after its projection
and telemetry pass verification against the journal.

Hive/SQLite do not share a transaction. This is an idempotent recovery protocol,
not a claim of cross-database atomicity. Hive readback normally uses its cache
after flush; tests additionally close/reopen boxes to prove serialized fidelity.
Four child-process exits cover intent, telemetry commit, drive commit and SQLite
verification commit. Existing WAL process-death tests cover transaction rollback.

The existing career box gets a single atomic totals/count-ID snapshot on save;
legacy values remain readable. Score/World processing remain secondary existing
flows, not part of the primary journal-to-Hive verification receipt.

## Recovery UI

Stopped sessions offer “Kurtar ve Kaydet” or leave without deletion. Missing
pointer plus unfinished journals blocks new acquisition rather than assuming
empty storage. Pending journals are listed deterministically and selected only
explicitly. Selection cannot steal a recording session's pointer. Storage errors
retain a safe exit, never an automatic new drive. No legacy preferences cleared.

## Capacity and interruptions

Default pending raw queue is 128 samples, including the in-progress retry. The
exact admitted canonical point/checkpoint retries without rerunning its filter.
Beyond capacity, samples are rejected with a critical GPS_QUEUE_LIMIT warning,
never reported as committed. Repeated identical task errors don't enqueue
unbounded status writes. After disk recovery, overflow evidence is persisted and
remains visible across writer restart. Producer start/drain events also leave
unclean-restart evidence in diagnostic export metadata.

There is no way to durably preserve new samples on a genuinely full/unavailable
disk. A process kill loses RAM-only samples, not the committed journal prefix.
If disk failure also prevents writing an overflow marker, its exact count cannot
be recovered; an unmatched producer epoch still indicates an unclean boundary.
No synthetic locations or distance are invented to fill it.

## Retention — NOT enabled in production

Only VERIFIED, error-free, non-current sessions after at least 30 days qualify.
`removeVerifiedJournal` requires a fresh Hive-verification callback and rechecks
the receipt inside an atomic SQLite transaction. A permanent session-scoped
audit receipt authorizes only that archived journal's deletes. Normal append-only
update/delete protections remain active; no trigger is disabled during cleanup.
Points, events and bulky transfer manifest are removed together; compact session,
transfer and immutable audit tombstones remain. Any error rolls back all deletes.

No production scheduler, UI delete action or startup cleanup invokes this method.
Only named synthetic test data has been cleaned. Actual cleanup activation needs
separate approval and quiescent Hive mutation/backup policy; SQLite cannot lock
an independently modified Hive box across the verification boundary. Audit
tombstones grow with session count but large GPS/checkpoint payload is reclaimable.

## Acceptance limits

Android 16 tests use real sqflite MethodChannel/headless foreground engine and
synthetic Hive/session data. Full physical A55 movement, real storage exhaustion,
OEM task kills and recovery UX remain separate acceptance. No phone installation,
real data cleanup, cloud operation, Git commit or push performed in this stage.

## Phase 4 files

Added:
- `lib/services/gps_session_transfer.dart`
- `lib/services/gps_hive_transfer_sink.dart`
- `test/gps_session_lifecycle_test.dart`
- `test/drive_pending_save_ui_test.dart`
- `test/support/gps_transfer_crash_probe.dart`
- `docs/gps-session-lifecycle-phase4.md`

Updated on top of the existing uncommitted Phase 1–3 work:
- `lib/services/gps_session_store.dart`
- `lib/services/gps_recording_writer.dart`
- `lib/services/gps_failure.dart`
- `lib/services/task_handler.dart`
- `lib/services/foreground_service.dart`
- `lib/services/drive_storage_service.dart`
- `lib/screens/drive_recovery_screen.dart`
- `lib/widgets/drive_summary_dialog.dart`
- `integration_test/gps_android_test.dart`
