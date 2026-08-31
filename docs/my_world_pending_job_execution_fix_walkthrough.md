# My World pending validation execution fix

## Root cause

`DriveStorageService.saveDrive` correctly called
`MyWorldRuntime.enqueueSavedDrive`, and `MyWorldValidationService` persisted a
`validateRoad:<driveId>` job. However, no production runtime path consumed
`MyWorldRepository.getPendingJobs()`. The validation and World record
processing services existed and were covered by unit tests, but were never
wired to startup or to the successful drive-save path. Consequently the real
device job stayed `pending`, Mapbox was never called, and no `ValidatedRoad`
was created.

## Fix and runtime wiring

`WorldPendingJobProcessor` is a small in-process drain. It reads pending and
retry-scheduled validation jobs, loads the saved `DriveSession`, invokes the
existing `MyWorldValidationService`, and, when the 3 km rule produces
`readyForWorldProcessing`, invokes the existing
`WorldRecordProcessingService`. It does not change the Mapbox request or World
ownership/index algorithms.

The drain is triggered in two places:

1. after a successful save/enqueue (best effort and non-blocking),
2. once after Hive/app startup (also non-blocking).

An in-process shared Future coalesces concurrent startup and save drains. Hive
job idempotency remains the durable cross-process guard. A retryable provider
or index error leaves the DriveSession intact and stores a
`retryScheduled` job with incremented `retryCount` and the error.

Existing validated roads are still handled by the Phase 2 idempotency check;
no unnecessary provider request is made. Missing drives become a permanent
job failure rather than crashing the app.

## Changed files

- `lib/features/my_world/services/world_pending_job_processor.dart`
- `lib/features/my_world/services/my_world_runtime.dart`
- `lib/services/drive_storage_service.dart`
- `lib/main.dart`
- `test/world_pending_job_processor_test.dart`

The existing read-only diagnostic service remains unchanged. No token is
hardcoded or logged. The unrelated pre-existing `driveit_log.txt` remains
untouched.

## Tests

The processor tests cover successful validation and World commit, concurrent
drain coalescing, and retryable provider failure with DriveSession/job
preservation. The full project suite and analyzer should be run before device
verification.

## Device recovery

No new drive is needed. Start the existing installation so startup recovery
finds the durable job:

```text
flutter run -d R5CX42V8GSJ --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_TOKEN
```

Please send terminal lines beginning with `[WORLD_JOB]` and `[WORLD_DIAG]`.
Success is indicated by validation distance at least 3000 m, a completed job,
`processed=true`, `activeTraceCount>0`, and `PRIMARY_DIAGNOSIS=SUCCESS`.
