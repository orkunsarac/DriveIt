import '../../../models/drive_session.dart';
import '../../../services/local_owner_lifecycle.dart';
import '../../../services/gps_session_ownership.dart';
import '../../../services/owner_profile_gateway.dart';
import '../models/world_publish.dart';
import 'published_drive_source_builder.dart';
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
  consentRequired,
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
    this._ownerDriveLookup,
    this._requireOwnerCurrent,
  }) : _publishService = publishService ?? WorldPublishService(),
       _uploadService = uploadService ?? WorldPublishSourceUploadService(),
       _processingService =
           processingService ?? WorldPublishProcessingService();

  factory WorldPublishSubmissionService.ownerScoped({
    required LocalOwnerLease lease,
    required OwnerProfileGateway ownerGateway,
  }) {
    lease.requireCurrent();
    if (lease.owner.userId == null ||
        lease.owner.kind != GpsOwnerKind.account ||
        !ownerGateway.isAuthorized ||
        ownerGateway.approvedOwner() != lease.owner.userId ||
        ownerGateway.approvedEpoch() != lease.epoch) {
      throw StateError('Planet publication owner lease unavailable');
    }
    final telemetry = lease.telemetry;
    final scores = lease.score;
    final builder = PublishedDriveSourceBuilder(
      telemetryLoader: telemetry,
      scoreLoader: scores,
    );
    return WorldPublishSubmissionService(
      publishService: WorldPublishService.ownerScoped(
        ownerGateway: ownerGateway,
        savedDriveLookup: (id) {
          if (!lease.isCurrent) throw StateError('Planet owner lease revoked');
          return lease.requireDrive(id);
        },
        telemetryLoader: telemetry,
        scoreLoader: scores,
      ),
      uploadService: WorldPublishSourceUploadService(
        gateway: OwnerScopedWorldPublishSourceGateway(ownerGateway),
        builder: builder,
      ),
      processingService: WorldPublishProcessingService(
        gateway: OwnerScopedWorldPublishProcessingGateway(ownerGateway),
      ),
      ownerDriveLookup: lease.requireDrive,
      requireOwnerCurrent: lease.requireCurrent,
    );
  }

  final WorldPublishService _publishService;
  final WorldPublishSourceUploadService _uploadService;
  final WorldPublishProcessingService _processingService;
  final DriveSession Function(String driveId)? _ownerDriveLookup;
  final void Function()? _requireOwnerCurrent;

  WorldPublishService get publishService => _publishService;

  bool get isAvailable => _publishService.isAvailable;
  bool get hasSession => _publishService.hasSession;

  Future<WorldPublishSubmissionResult> submitDriveForPlanet(
    DriveSession drive, {
    bool confirmedFullDriveShare = false,
    void Function()? onProcessingStarted,
  }) async {
    final authorizedDrive = _authorizedDrive(drive);
    if (authorizedDrive == null) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.invalidDrive,
      );
    }
    drive = authorizedDrive;
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
      if (!confirmedFullDriveShare) {
        return const WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.consentRequired,
        );
      }
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
          try {
            // Insert may have succeeded while its response was lost. Reconcile
            // by the owner's unique drive row before considering a retry.
            publish = await _publishService.getPublishForLocalDrive(drive.id);
          } on WorldPublishLookupException {
            return const WorldPublishSubmissionResult(
              WorldPublishSubmissionStatus.createFailure,
            );
          }
          if (publish == null) {
            return const WorldPublishSubmissionResult(
              WorldPublishSubmissionStatus.createFailure,
            );
          }
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

  /// Recovery action for an already-created publish whose source is
  /// attached. This path deliberately performs no create or storage upload.
  Future<WorldPublishSubmissionResult> processReadyPublishForDrive(
    DriveSession drive, {
    void Function()? onProcessingStarted,
  }) async {
    final authorizedDrive = _authorizedDrive(drive);
    if (authorizedDrive == null) {
      return const WorldPublishSubmissionResult(
        WorldPublishSubmissionStatus.invalidDrive,
      );
    }
    drive = authorizedDrive;
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
        if (publish.sourceReady) {
          return _processReadyPublish(
            drive,
            publish,
            onProcessingStarted: onProcessingStarted,
          );
        }
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
        final refreshed = await _publishService.getPublishForLocalDrive(
          drive.id,
        );
        if (refreshed == null) {
          return WorldPublishSubmissionResult(
            WorldPublishSubmissionStatus.processingRefreshFailure,
            publish: publish,
            processing: processing,
          );
        }
        current = refreshed;
      } on WorldPublishLookupException {
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.processingRefreshFailure,
          publish: publish,
          processing: processing,
        );
      }
      // The process endpoint response is not terminal proof. Only the
      // server-owned status read may report the publication as completed.
      if (current.status == WorldPublishStatus.published) {
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.success,
          publish: current,
          processing: processing,
        );
      }
      if (current.status == WorldPublishStatus.failed) {
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.serverFailed,
          publish: current,
          processing: processing,
        );
      }
      if (current.status == WorldPublishStatus.processing) {
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.processing,
          publish: current,
          processing: processing,
        );
      }
      if (processing.status == WorldPublishProcessingStatus.success) {
        return WorldPublishSubmissionResult(
          WorldPublishSubmissionStatus.processingRetryableFailure,
          publish: current,
          processing: WorldPublishProcessingResult(
            WorldPublishProcessingStatus.retryableFailure,
            errorCode: 'publish_state_unconfirmed',
            wasInvoked: true,
          ),
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

  DriveSession? _authorizedDrive(DriveSession requested) {
    try {
      _requireOwnerCurrent?.call();
      final authorized = _ownerDriveLookup?.call(requested.id) ?? requested;
      if (authorized.id != requested.id) return null;
      _requireOwnerCurrent?.call();
      return authorized;
    } catch (_) {
      return null;
    }
  }
}
