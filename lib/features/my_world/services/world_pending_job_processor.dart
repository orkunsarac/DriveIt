import 'package:flutter/foundation.dart';

import '../../../models/drive_session.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import '../repositories/my_world_repository.dart';
import 'my_world_validation_service.dart';
import 'world_record_processing_service.dart';

typedef WorldDriveLoader = DriveSession? Function(String driveSessionId);
typedef WorldDriveEligibility = bool Function(String driveSessionId);

/// Drains durable My World validation jobs without owning a scheduler.
///
/// A single in-process future coalesces startup and post-save drains. The
/// durable job remains the recovery source if the process is killed mid-call.
class WorldPendingJobProcessor {
  WorldPendingJobProcessor({
    required this._repository,
    required this._validation,
    required this._recordProcessing,
    required this._driveLoader,
    WorldDriveEligibility? driveEligibility,
  }) : _driveEligibility = driveEligibility ?? ((_) => true);

  static Future<void>? _activeDrain;

  final MyWorldRepository _repository;
  final MyWorldValidationService _validation;
  final WorldRecordProcessingService _recordProcessing;
  final WorldDriveLoader _driveLoader;
  final WorldDriveEligibility _driveEligibility;

  Future<void> drain() {
    final active = _activeDrain;
    if (active != null) return active;
    final future = _drainSafely();
    _activeDrain = future;
    future.whenComplete(() {
      if (identical(_activeDrain, future)) _activeDrain = null;
    });
    return future;
  }

  Future<void> _drainSafely() async {
    try {
      final jobs = await _repository.getPendingJobs();
      for (final job in jobs) {
        if (job.type != WorldJobType.validateRoad) continue;
        await _process(job);
      }
    } catch (error) {
      _log('drain failed safely: $error');
    }
  }

  Future<void> _process(WorldPendingJob originalJob) async {
    final drive = _driveLoader(originalJob.driveSessionId);
    if (drive == null) {
      await _saveJob(
        originalJob.copyWith(
          status: WorldJobStatus.failedPermanent,
          lastError: 'DriveSession was not found.',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      _log(
        'permanent failure driveId=${originalJob.driveSessionId}: drive missing',
      );
      return;
    }
    if (!_driveEligibility(drive.id)) {
      _log('skipping driveId=${drive.id}: Drive Score record is missing');
      return;
    }

    _log('processing validateRoad driveId=${drive.id}');
    try {
      final running = originalJob.copyWith(
        status: WorldJobStatus.running,
        updatedAt: DateTime.now().toUtc(),
        clearLastError: true,
      );
      await _saveJob(running);
      _log('map matching started driveId=${drive.id}');
      final validation = await _validation.validateDrive(drive);
      _log(
        'validation result driveId=${drive.id} state=${validation.state.name} '
        'validatedDistanceMeters=${validation.road?.validDistanceMeters ?? 0}',
      );

      if (validation.state != WorldProcessingState.readyForWorldProcessing) {
        // Validation service has already persisted completed, retryScheduled,
        // or failedPermanent state atomically with its road result.
        return;
      }

      final record = await _repository.getProcessingRecord(drive.id);
      if (record == null || record.validatedRoadId == null) {
        throw StateError('Ready validation has no processing record.');
      }
      await _repository.saveProcessingRecord(
        WorldDriveProcessingRecord(
          driveSessionId: drive.id,
          state: WorldProcessingState.processing,
          validatedRoadId: record.validatedRoadId,
          lastError: null,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      _log('world processing started driveId=${drive.id}');
      final world = await _recordProcessing.processReadyDrive(drive.id);
      if (world.outcome != WorldRecordProcessingOutcome.processed &&
          world.outcome != WorldRecordProcessingOutcome.alreadyProcessed) {
        throw StateError(world.reason ?? 'World processing did not complete.');
      }
      final completed = running.copyWith(
        status: WorldJobStatus.completed,
        clearLastError: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _saveJob(completed);
      _log('world index commit success driveId=${drive.id}');
      _log('completed driveId=${drive.id} traceCount=${world.traceCount}');
    } catch (error) {
      final retry = originalJob.copyWith(
        status: WorldJobStatus.retryScheduled,
        retryCount: originalJob.retryCount + 1,
        lastError: error.toString(),
        updatedAt: DateTime.now().toUtc(),
      );
      await _saveJob(retry);
      _log('retryable failure driveId=${drive.id}: $error');
    }
  }

  Future<void> _saveJob(WorldPendingJob job) => _repository.savePendingJob(job);

  void _log(String message) {
    if (kDebugMode) debugPrint('[WORLD_JOB] $message');
  }
}
