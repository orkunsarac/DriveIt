import '../../../models/drive_session.dart';
import '../config/my_world_rules.dart';
import '../models/validated_road.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import '../repositories/my_world_repository.dart';
import 'road_matching_service.dart';

class MyWorldValidationResult {
  final WorldProcessingState state;
  final ValidatedRoad? road;
  final bool providerCalled;
  final String? errorMessage;

  const MyWorldValidationResult({
    required this.state,
    required this.road,
    required this.providerCalled,
    required this.errorMessage,
  });
}

class MyWorldValidationService {
  final MyWorldRepository repository;
  final RoadMatchingService roadMatching;
  final DateTime Function() _clock;

  MyWorldValidationService({
    required this.repository,
    required this.roadMatching,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<void> enqueueDrive(DriveSession drive) async {
    final roads = await repository.getValidatedRoadsForDrive(drive.id);
    if (_currentRoad(roads) case final existing? when !existing.requiresRetry) {
      return;
    }
    final now = _clock();
    final job = WorldPendingJob.pending(
      driveSessionId: drive.id,
      type: WorldJobType.validateRoad,
      now: now,
    );
    await repository.enqueueIfAbsent(job);
    await repository.saveProcessingRecord(
      WorldDriveProcessingRecord(
        driveSessionId: drive.id,
        state: WorldProcessingState.pendingValidation,
        validatedRoadId: null,
        lastError: null,
        updatedAt: now,
      ),
    );
  }

  Future<MyWorldValidationResult> validateDrive(
    DriveSession drive, {
    bool forceRebuild = false,
  }) async {
    final roads = await repository.getValidatedRoadsForDrive(drive.id);
    final existing = _currentRoad(roads);
    if (!forceRebuild && existing != null && !existing.requiresRetry) {
      return _repairFromExisting(drive.id, existing);
    }

    await enqueueDrive(drive);
    final now = _clock();
    var job =
        await repository.getPendingJob(drive.id, WorldJobType.validateRoad) ??
        WorldPendingJob.pending(
          driveSessionId: drive.id,
          type: WorldJobType.validateRoad,
          now: now,
        );
    job = job.copyWith(
      status: WorldJobStatus.running,
      updatedAt: now,
      clearLastError: true,
    );
    await repository.savePendingJob(job);

    final outcome = await roadMatching.validate(drive);
    final road = outcome.road;
    final finishedAt = _clock();
    if (road != null) {
      final retryablePartial = road.requiresRetry || outcome.isRetryable;
      final state = retryablePartial
          ? WorldProcessingState.pendingValidation
          : _eligibleState(road.validDistanceMeters);
      final updatedJob = job.copyWith(
        status: retryablePartial
            ? WorldJobStatus.retryScheduled
            : WorldJobStatus.completed,
        retryCount: retryablePartial ? job.retryCount + 1 : job.retryCount,
        lastError: retryablePartial ? outcome.errorMessage : null,
        clearLastError: !retryablePartial,
        updatedAt: finishedAt,
      );
      final processing = WorldDriveProcessingRecord(
        driveSessionId: drive.id,
        state: state,
        validatedRoadId: road.id,
        lastError: retryablePartial ? outcome.errorMessage : null,
        updatedAt: finishedAt,
      );
      await repository.saveValidationBundle(
        road: road,
        processing: processing,
        job: updatedJob,
      );
      return MyWorldValidationResult(
        state: state,
        road: road,
        providerCalled: true,
        errorMessage: outcome.errorMessage,
      );
    }

    final retryable = outcome.isRetryable;
    final state = retryable
        ? WorldProcessingState.pendingValidation
        : WorldProcessingState.failedPermanent;
    final updatedJob = job.copyWith(
      status: retryable
          ? WorldJobStatus.retryScheduled
          : WorldJobStatus.failedPermanent,
      retryCount: retryable ? job.retryCount + 1 : job.retryCount,
      lastError: outcome.errorMessage,
      updatedAt: finishedAt,
    );
    await repository.saveValidationBundle(
      processing: WorldDriveProcessingRecord(
        driveSessionId: drive.id,
        state: state,
        validatedRoadId: null,
        lastError: outcome.errorMessage,
        updatedAt: finishedAt,
      ),
      job: updatedJob,
    );
    return MyWorldValidationResult(
      state: state,
      road: null,
      providerCalled: true,
      errorMessage: outcome.errorMessage,
    );
  }

  Future<MyWorldValidationResult> retryValidation(DriveSession drive) =>
      validateDrive(drive);

  Future<MyWorldValidationResult> _repairFromExisting(
    String driveSessionId,
    ValidatedRoad road,
  ) async {
    final now = _clock();
    final state = _eligibleState(road.validDistanceMeters);
    final existingJob = await repository.getPendingJob(
      driveSessionId,
      WorldJobType.validateRoad,
    );
    final job =
        (existingJob ??
                WorldPendingJob.pending(
                  driveSessionId: driveSessionId,
                  type: WorldJobType.validateRoad,
                  now: now,
                ))
            .copyWith(
              status: WorldJobStatus.completed,
              clearLastError: true,
              updatedAt: now,
            );
    await repository.saveValidationBundle(
      road: road,
      processing: WorldDriveProcessingRecord(
        driveSessionId: driveSessionId,
        state: state,
        validatedRoadId: road.id,
        lastError: null,
        updatedAt: now,
      ),
      job: job,
    );
    return MyWorldValidationResult(
      state: state,
      road: road,
      providerCalled: false,
      errorMessage: null,
    );
  }

  ValidatedRoad? _currentRoad(List<ValidatedRoad> roads) {
    final expectedProvider = roadMatching.provider.providerId;
    final expectedVersion = MyWorldRules.validatedRoadProcessingVersion;
    for (final road in roads.reversed) {
      if (road.providerId == expectedProvider &&
          road.processingVersion == expectedVersion) {
        return road;
      }
    }
    return null;
  }

  WorldProcessingState _eligibleState(double validDistanceMeters) =>
      validDistanceMeters >= MyWorldRules.minimumValidDistanceMeters
      ? WorldProcessingState.readyForWorldProcessing
      : WorldProcessingState.rejectedInsufficientValidDistance;
}
