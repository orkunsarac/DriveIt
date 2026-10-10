# Phase 5C — partial, NOT activation-ready

Phase 5C.1 now supplies a separate dormant claim ledger, full-record/file inventory,
streamed verified import and read-only completed partitions. See
`legacy_account_import_5c1.md`. The historical safety-stop findings below describe
the earlier 5C checkpoint; 5C.1 does not activate screens, Auth or GPS routing.

## Implemented in an isolated synthetic harness

- `LocalOwnershipGate.production` is a constant disabled gate; no dart-define
  enables the new behavior. The debug-only synthetic gate is dependency-injected.
- Supabase Auth adapter reduces session events to UUID/null without logging.
- Lifecycle revokes leases synchronously, serializes store transitions, waits for
  started writes in the captured namespace, closes old stores, drops stale reads
  and safely blocks views on storage/Auth/GPS uncertainty.
- A same-UUID token refresh does not recreate a ready context.
- The personal subtree boundary keys navigation/map state by epoch and never
  renders a personal subtree before the scoped store is ready.
- User-requested identity changes have a GPS guard. External changes block the
  personal view without changing or deleting the GPS journal/owner.
- Explicit consent binds UUID, epoch and manifest fingerprint. Guest approval,
  changed context, changed source and missing copy proof are rejected. Skip has
  no storage effect. The preview panel has no automatic approval.

These components are NOT installed into main, the existing Auth service, GPS
producer/transfer or the personal screens. Existing production paths remain
unchanged; this is not complete screen/GPS integration.

## Safety stop before real account adoption

Existing 5B preparation is a byte-preserving **quarantine**, not account adoption.
It captures the whole inventory in memory and leaves embedded ownership intact.
Its manifest cannot be treated as proof of completed account import:

1. `PosterStore` uses `drive_posters`, exported PNG and optional background files
   under the app documents `posters` directory. That box/directory is not in the
   5B personal inventory. `DriveSession.mapImagePath` is also a file reference.
2. `LocalSourceBundle.toMap` deliberately clears `mapImagePath` for independent
   World/Career processing. It is not a lossless History/poster copy mechanism.
3. Ready World sources and Career contributions contain `ownerScope`; outbox
   keys/payloads and pending jobs need explicit ownership/provenance validation,
   not a blind relabel of serialized records.
4. There is not yet a durable cross-account claim ledger for legacy ownership,
   a verified disk-capacity provider, a streaming record/file copier with hashes,
   or a full cross-box/file import receipt.

Consequently production migration, account adoption and scoped GPS routing stay
disabled. `copyContractVerified` defaults false; no production code sets it true.
Synthetic tests may supply a verified preview to exercise consent expiry, but do
not prove actual durable import, disk failure or file preservation.

## Remaining before 5C can be called complete

- Full screen/provider adapters for History/detail/poster/Career/My World/profile/
  Planet, with independent deletion and async/epoch guards at every entry point.
- GPS bootstrap/start/recovery/transfer wiring through persistent sidecar owner;
  safe recovery UX while external Auth differs, without exposing old personal data.
- Atomic or fail-closed durable claim reservation across all legacy relations,
  then bounded-memory copy/flush/hash/read-back of records and referenced assets.
- Consent importer must re-check its fixed token before each write boundary and
  never mark partial copies complete. Same-owner retry and other-owner rejection
  must survive restart, even after the UI response is lost.
- Synthetic native integration tests for those complete paths and import faults.

No real migration, cloud operation, journal schema change, APK install or commit
on a physical phone is performed by this phase's partial implementation.
Controlled tests are not
Android process-kill or power-loss acceptance.

## Recorded verification

- Before changes: Flutter 673/673.
- After changes: Flutter 702/702, including 29 new lifecycle/consent tests.
- Emulator: 26/26 = new lifecycle 1, scoped transfer 1, sidecar 1,
  independent lifecycle 14, legacy Hive 1, GPS/SQLite 8.
- The obsolete `busy_timeout` non-query exception is an intentional negative
  test; the corrected native sqflite configuration and headless recovery pass.
- The first widget run stalled on actual Hive I/O under fake async; the harness
  now uses `tester.runAsync` for native file-backed setup. The final suite passes.
- Actual Google Maps rendering, real account adoption, filesystem import,
  disk-full import, bounded-memory import and an Auth-aware complete GPS UI flow
  are NOT validated by these new tests.
