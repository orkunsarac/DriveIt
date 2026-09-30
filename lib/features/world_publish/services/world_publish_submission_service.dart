import '../../../models/drive_session.dart';
import '../models/world_publish.dart';
import 'world_publish_processing_service.dart';
import 'world_publish_service.dart';
import 'world_publish_source_upload_service.dart';

enum WorldPublishSubmissionStatus {
  success,
  alreadyReady,
  processing,
  published,
  serverFailed,
  notSignedIn,
  supabaseUnavailable,
  notEligible,
  invalidDrive,
  missingCanonicalTelemetry,
  invalidCanonicalTelemetry,
  publishDriveMismatch,
  uploadFailure,
  attachFailure,
  lookupFailure,
  sourceNotReady,
  processingRetryableFailure,
  processingPermanentFailure,
  processingRefreshFailure,
  createFailure,
}

class WorldPublishSubmissionResult {
  const WorldPublishSubmissionResult(
    this.status, {
    this.publish,
    this.processing,
  });

  final WorldPublishSubmissionStatus status;
  final WorldPublish? publish;
  final WorldPublishProcessingResult? processing;
}

/// Reuses an existing pending row instead of creating a second publish.
class WorldPublishSubmissionService {
  WorldPublishSubmissionService({
    WorldPublishService? publishService,
    WorldPublishSourceUploadService? uploadService,
    WorldPublishProcessingService? processingService,
  }) : _publishService = publishService ?? WorldPublishService(),
       _uploadService = uploadService ?? WorldPublishSourceUploadService(),
       _processingService =
           processingService ?? WorldPublishProcessingService();

  final WorldPublishService _publishService;
  final WorldPublishSourceUploadService _uploadService;
  final WorldPublishProcessingService _processingService;

  bool get isAvailable => _publishService.isAvailable;
  bool get hasSession => _publishService.hasSession;

  Future<WorldPublishSubmissionResult> submitDriveForPlanet(
    DriveSession drive, {
    void Function()? onProcessingStarted,
  }) async {
    if (!isAvailable) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.supabaseUnavailable,
      );
    }
    if (!hasSession) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.notSignedIn,
      );
    }
    WorldPublish? publish;
    try {
      publish = await _publishService.getPublishForLocalDrive(drive.id);
    } on WorldPublishLookupException {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.lookupFailure,
      );
    }
    if (publish == null) {
      final created = await _publishService.createPendingPublish(drive);
      switch (created.status) {
        case WorldPublishCreateStatus.success:
          publish = created.publish;
        case WorldPublishCreateStatus.alreadyPublished:
          try {
            publish = await _publishService.getPublishForLocalDrive(drive.id);
          } on WorldPublishLookupException {
            return const WorldPublishSubmissionResult(
              WorldPublishSubmissionStatus.lookupFailure,
            );
          }
        case WorldPublishCreateStatus.notSignedIn:
          return const WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.notSignedIn,
          );
        case WorldPublishCreateStatus.supabaseUnavailable:
          return const WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.supabaseUnavailable,
          );
        case WorldPublishCreateStatus.invalidDrive:
          return const WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.invalidDrive,
          );
        case WorldPublishCreateStatus.notEligible:
          return const WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.notEligible,
          );
        case WorldPublishCreateStatus.networkOrServerFailure:
          return const WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.createFailure,
          );
      }
      if (publish == null) {
        return const WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.lookupFailure,
        );
      }
    }
    switch (publish.status) {
      case WorldPublishStatus.processing:
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.processing,
          publish: publish,
        );
      case WorldPublishStatus.published:
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.published,
          publish: publish,
        );
      case WorldPublishStatus.failed:
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.serverFailed,
          publish: publish,
        );
      case WorldPublishStatus.pending:
        break;
    }
    if (publish.sourceReady) {
      return _processReadyPublish(
        drive,
        publish,
        onProcessingStarted: onProcessingStarted,
      );
    }
    final uploaded = await _uploadService.uploadSource(
      drive: drive,
      publish: publish,
      reloadPublish: _publishService.getPublishForLocalDrive,
    );
    final uploadStatus = switch (uploaded.status) {
      WorldPublishSourceUploadStatus.success =>
        WorldPublishSubmissionStatus.success,
      WorldPublishSourceUploadStatus.notSignedIn =>
        WorldPublishSubmissionStatus.notSignedIn,
      WorldPublishSourceUploadStatus.supabaseUnavailable =>
        WorldPublishSubmissionStatus.supabaseUnavailable,
      WorldPublishSourceUploadStatus.missingCanonicalTelemetry =>
        WorldPublishSubmissionStatus.missingCanonicalTelemetry,
      WorldPublishSourceUploadStatus.invalidCanonicalTelemetry =>
        WorldPublishSubmissionStatus.invalidCanonicalTelemetry,
      WorldPublishSourceUploadStatus.invalidDrive =>
        WorldPublishSubmissionStatus.invalidDrive,
      WorldPublishSourceUploadStatus.publishDriveMismatch =>
        WorldPublishSubmissionStatus.publishDriveMismatch,
      WorldPublishSourceUploadStatus.uploadFailure =>
        WorldPublishSubmissionStatus.uploadFailure,
      WorldPublishSourceUploadStatus.attachFailure =>
        WorldPublishSubmissionStatus.attachFailure,
    };
    final readyPublish = uploaded.publish;
    if (uploaded.status == WorldPublishSourceUploadStatus.success &&
        readyPublish != null &&
        readyPublish.sourceReady) {
      return _processReadyPublish(
        drive,
        readyPublish,
        onProcessingStarted: onProcessingStarted,
      );
    }
    return WorldPublishSubmissionResult(
      uploadStatus,
      publish: readyPublish ?? publish,
    );
  }

  /// Recovery action for an already-created pending publish whose source is
  /// attached. This path deliberately performs no create or storage upload.
  Future<WorldPublishSubmissionResult> processReadyPublishForDrive(
    DriveSession drive, {
    void Function()? onProcessingStarted,
  }) async {
    if (!isAvailable) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.supabaseUnavailable,
      );
    }
    if (!hasSession) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.notSignedIn,
      );
    }
    final WorldPublish? publish;
    try {
      publish = await _publishService.getPublishForLocalDrive(drive.id);
    } on WorldPublishLookupException {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.lookupFailure,
      );
    }
    if (publish == null) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.lookupFailure,
      );
    }
    switch (publish.status) {
      case WorldPublishStatus.pending:
        if (!publish.sourceReady) {
          return WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.sourceNotReady,
            publish: publish,
          );
        }
        return _processReadyPublish(
          drive,
          publish,
          onProcessingStarted: onProcessingStarted,
        );
      case WorldPublishStatus.processing:
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.processing,
          publish: publish,
        );
      case WorldPublishStatus.published:
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.published,
          publish: publish,
        );
      case WorldPublishStatus.failed:
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.serverFailed,
          publish: publish,
        );
    }
  }

  Future<WorldPublishSubmissionResult> _processReadyPublish(
    DriveSession drive,
    WorldPublish publish, {
    void Function()? onProcessingStarted,
  }) async {
    onProcessingStarted?.call();
    final processing = await _processingService.process(publish);
    var current = publish;
    if (processing.wasInvoked) {
      try {
        current =
            await _publishService.getPublishForLocalDrive(drive.id) ?? publish;
      } on WorldPublishLookupException {
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.processingRefreshFailure,
          publish: publish,
          processing: processing,
        );
      }
    }
    final status = switch (processing.status) {
      WorldPublishProcessingStatus.success =>
        WorldPublishSubmissionStatus.success,
      WorldPublishProcessingStatus.notAuthenticated =>
        WorldPublishSubmissionStatus.notSignedIn,
      WorldPublishProcessingStatus.retryableFailure =>
        WorldPublishSubmissionStatus.processingRetryableFailure,
      WorldPublishProcessingStatus.permanentFailure =>
        WorldPublishSubmissionStatus.processingPermanentFailure,
    };
    return WorldPublishSubmissionResult(
      status,
      publish: current,
      processing: processing,
    );
  }
}
