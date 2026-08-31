// This file intentionally prints a prefixed diagnostic to the debug terminal.
// ignore_for_file: avoid_print
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../../../models/drive_session.dart';
import '../../../services/drive_score_storage_service.dart';
import '../../../services/drive_storage_service.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import '../config/mapbox_config.dart';
import '../config/my_world_rules.dart';
import '../models/validated_road.dart';
import '../models/world_index_snapshot.dart';
import '../models/world_pending_job.dart';
import '../models/world_processing.dart';
import '../persistence/my_world_hive.dart';
import '../repositories/hive_my_world_index_repository.dart';
import '../repositories/hive_my_world_repository.dart';
import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import 'my_world_runtime.dart';

/// Read-only diagnosis of the latest saved drive and its My World pipeline.
///
/// This service deliberately does not call validation, processing, rebuild, or
/// any network provider. It is only wired from debug startup.
class WorldDiagnosticService {
  const WorldDiagnosticService();

  /// Debug-only, read-only audit for the World rules-version migration.
  Future<void> auditCurrentWorldAfterRulesV3() async {
    if (!kDebugMode) return;
    final pointerBox = Hive.box<WorldIndexPointer>(
      MyWorldHive.indexMetadataBoxName,
    );
    final snapshotBox = Hive.box<WorldIndexSnapshot>(
      MyWorldHive.indexSnapshotsBoxName,
    );
    final pointer = pointerBox.get('active_generation');
    final snapshot = pointer == null ? null : snapshotBox.get(pointer.activeGeneration);
    final need = await MyWorldRuntime.rebuildService().needsRebuild(
      targetVersion: DriveScoreAlgorithmVersion.v1,
    );
    final traces = snapshot?.traces ?? const [];
    final under1 = traces.where((trace) => trace.distanceMeters < 1000).toList();
    final under2 = traces.where((trace) => trace.distanceMeters < 2000).length;
    debugPrint('[WORLD_V3_AUDIT] expectedVersion=${MyWorldRules.worldRulesVersion}');
    debugPrint('[WORLD_V3_AUDIT] pointerExists=${pointer != null} '
        'pointerGeneration=${pointer?.activeGeneration ?? 'none'} '
        'activeSnapshotExists=${snapshot != null} '
        'activeVersion=${snapshot?.validatedRoadProcessingVersion ?? 'none'} '
        'snapshotGeneration=${snapshot?.generation ?? 'none'} '
        'needsRebuild=${need.needsRebuild}');
    debugPrint('[WORLD_V3_AUDIT] activeTraceCount=${traces.length} '
        'activeDistanceMeters=${traces.fold<double>(0, (s, t) => s + t.distanceMeters)} '
        'under1kmTraceCount=${under1.length} under2kmTraceCount=$under2 '
        'uniqueSourceDriveCount=${traces.map((t) => t.sourceDriveSessionId).toSet().length} '
        'displayedWorldDriveCount=${traces.length} '
        'fingerprint=${_snapshotFingerprint(traces)}');
    debugPrint('[WORLD_COUNT] activeTraceCount=${traces.length} '
        'uniqueSourceDriveCount=${traces.map((t) => t.sourceDriveSessionId).toSet().length} '
        'displayedWorldDriveCount=${traces.length}');
    for (final trace in under1) {
      debugPrint('[WORLD_SHORT_TRACE] traceId=${trace.id} '
          'sourceDriveId=${trace.sourceDriveSessionId} '
          'validatedRoadId=${trace.validatedRoadId} '
          'sectionId=${trace.matchedSectionId} '
          'startOffsetMeters=${trace.startOffsetMeters} '
          'endOffsetMeters=${trace.endOffsetMeters} '
          'lengthMeters=${trace.distanceMeters} '
          'snapshotGeneration=${snapshot?.generation ?? 'none'} '
          'creationPath=UNKNOWN under1km=true visible=true');
    }
  }

  Future<void> printLatest() async {
    try {
      final drives = DriveStorageService.getAllDrives()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (drives.isEmpty) {
        _printHeader();
        _line('PRIMARY_DIAGNOSIS=DRIVE_NOT_FOUND');
        _line('DETAIL=No saved DriveSession was found.');
        return;
      }
      final drive = drives.first;
      final telemetry = DriveTelemetryStorageService.get(drive.id);
      final score = DriveScoreStorageService.get(driveId: drive.id);
      final repository = HiveMyWorldRepository(
        Hive.box<ValidatedRoad>(MyWorldHive.validatedRoadsBoxName),
        Hive.box<WorldDriveProcessingRecord>(MyWorldHive.processingBoxName),
        Hive.box<WorldPendingJob>(MyWorldHive.pendingJobsBoxName),
      );
      final roads = await repository.getValidatedRoadsForDrive(drive.id);
      final processing = await repository.getProcessingRecord(drive.id);
      final allJobs = Hive.box<WorldPendingJob>(
        MyWorldHive.pendingJobsBoxName,
      ).values.where((job) => job.driveSessionId == drive.id).toList();

      WorldIndexSnapshot? snapshot;
      List<dynamic> activeTraces = const [];
      try {
        snapshot = await HiveMyWorldIndexRepository(
          Hive.box<WorldIndexSnapshot>(MyWorldHive.indexSnapshotsBoxName),
          Hive.box<WorldIndexPointer>(MyWorldHive.indexMetadataBoxName),
        ).getActiveSnapshot();
        activeTraces = snapshot.traces
            .where((trace) => trace.sourceDriveSessionId == drive.id)
            .toList();
      } catch (_) {
        // A missing pointer/snapshot is itself part of the diagnostic result.
      }

      final input = WorldDiagnosticInput(
        driveFound: true,
        canonicalTelemetryPresent: telemetry != null,
        validatedRoads: roads,
        processing: processing,
        pendingJobs: allJobs,
        activeSnapshot: snapshot,
        activeTraceCount: activeTraces.length,
      );
      _printReport(
        drive: drive,
        canonicalPointCount: telemetry?.points.length ?? 0,
        score: score,
        roads: roads,
        processing: processing,
        jobs: allJobs,
        snapshot: snapshot,
        activeTraceCount: activeTraces.length,
        activeTraces: activeTraces,
        activeDistance: activeTraces.fold<double>(
          0,
          (sum, trace) => sum + trace.distanceMeters,
        ),
        diagnosis: WorldDiagnosticClassifier.classify(input),
      );
    } catch (error) {
      _printHeader();
      _line('PRIMARY_DIAGNOSIS=WORLD_PROCESSING_FAILED');
      _line('DETAIL=Diagnostic read failed safely: $error');
    }
  }

  void _printReport({
    required DriveSession drive,
    required int canonicalPointCount,
    required dynamic score,
    required List<ValidatedRoad> roads,
    required WorldDriveProcessingRecord? processing,
    required List<WorldPendingJob> jobs,
    required WorldIndexSnapshot? snapshot,
    required int activeTraceCount,
    required List<dynamic> activeTraces,
    required double activeDistance,
    required WorldDiagnosticDiagnosis diagnosis,
  }) {
    _printHeader();
    _line('DRIVE SESSION');
    _line('driveId=${drive.id}');
    _line('date=${drive.date.toIso8601String()}');
    _line('storedDistanceMeters=${drive.distance}');
    _line('durationSeconds=${drive.durationSeconds}');
    _line('routePointCount=${drive.route.length}');
    _line('canonicalTelemetryPresent=${canonicalPointCount > 0}');
    _line('canonicalTelemetryPointCount=$canonicalPointCount');
    _line('driveScoreRecordPresent=${score != null}');
    _line('algorithmVersion=${score?.algorithmVersion ?? 'unavailable'}');
    _line('totalDriveScore=${score?.totalScore ?? 'unavailable'}');

    _line('MAPBOX / VALIDATED ROAD');
    _line(
      'MAPBOX_ACCESS_TOKEN configured: ${MapboxConfig.accessToken.isNotEmpty}',
    );
    _line('validatedRoadCount=${roads.length}');
    if (roads.isEmpty) {
      _line('ValidatedRoad: NOT FOUND');
    } else {
      for (final road in roads) {
        _line(
          'validatedRoad id=${road.id} status=${road.status.name} '
          'processingVersion=${road.processingVersion} sections=${road.sections.length} '
          'matchedPoints=${road.geometry.length} '
          'validatedDistanceMeters=${road.validDistanceMeters} '
          'worldMinimumPassed=${road.validDistanceMeters >= MyWorldRules.minimumValidDistanceMeters} '
          'requiresRetry=${road.requiresRetry} '
          'error=${road.status == RoadValidationStatus.failed ? 'validation failed' : 'none'}',
        );
      }
    }

    _line('WORLD PROCESSING RECORD');
    if (processing == null) {
      _line('processingRecord: NOT FOUND');
    } else {
      _line('state=${processing.state.name}');
      _line('validatedRoadId=${processing.validatedRoadId ?? 'none'}');
      _line('processingReason=${processing.lastError ?? 'none'}');
      _line('algorithmVersion=unavailable in processing record');
      _line('attemptRetryInfo=see pending jobs');
      _line('lastError=${processing.lastError ?? 'none'}');
      _line('updatedAt=${processing.updatedAt.toIso8601String()}');
      _line('processed=${processing.state == WorldProcessingState.processed}');
      _line(
        'failedRetryable=${processing.state == WorldProcessingState.failedRetryable}',
      );
      _line(
        'pending=${processing.state == WorldProcessingState.pendingValidation || processing.state == WorldProcessingState.processing}',
      );
    }

    _line('WORLD PENDING JOBS');
    if (jobs.isEmpty) {
      _line('pendingJobs: none');
    } else {
      for (final job in jobs) {
        _line(
          'job id=${job.id} type=${job.type.name} status=${job.status.name} '
          'retryCount=${job.retryCount} createdAt=${job.createdAt.toIso8601String()} '
          'updatedAt=${job.updatedAt.toIso8601String()} lastError=${job.lastError ?? 'none'}',
        );
      }
    }

    _line('WORLD INDEX');
    _line('activeSnapshotPresent=${snapshot != null}');
    if (snapshot == null) {
      _line('sourceDrivePresentInActiveIndex=false');
    } else {
      _line(
        'snapshotGeneration=${snapshot.generation} snapshotId=${snapshot.operationId}',
      );
      _line('activeTraceCount=${snapshot.traces.length}');
      _line('processedDriveCount=${snapshot.processedDriveSessionIds.length}');
      _line('uniqueSourceDriveCount=${snapshot.traces.map((t) => t.sourceDriveSessionId).toSet().length}');
      _line('displayedWorldDriveCount=${snapshot.traces.length}');
      _line('driveProcessed=${snapshot.hasProcessedDrive(drive.id)}');
      _line('sourceTraceCount=$activeTraceCount');
      _line('sourceActiveDistanceMeters=$activeDistance');
      _line('sourceDrivePresentInActiveIndex=${activeTraceCount > 0}');
      for (final trace in activeTraces) {
        _traceAudit(trace);
      }
    }

    final detail = WorldDiagnosticClassifier.detail(
      diagnosis,
      roads,
      processing,
    );
    _line('PRIMARY_DIAGNOSIS=${diagnosis.label}');
    _line('DETAIL=$detail');
  }

  void _printHeader() {
    _line('==================================================');
    _line('DRIVEIT WORLD DIAGNOSTIC');
    _line('==================================================');
  }

  void _line(String value) => print('[WORLD_DIAG] $value');

  void _traceAudit(dynamic trace) {
    final length = trace.distanceMeters as double;
    // ActiveWorldTrace does not persist mutation provenance. Do not infer a
    // challenger violation from a short remainder; report it explicitly as
    // unknown so the ownership engine is never changed based on guesswork.
    print('[WORLD_TRACE_AUDIT] traceId=${trace.id}');
    print('[WORLD_TRACE_AUDIT] sourceDriveId=${trace.sourceDriveSessionId}');
    print('[WORLD_TRACE_AUDIT] startOffsetMeters=${trace.startOffsetMeters}');
    print('[WORLD_TRACE_AUDIT] endOffsetMeters=${trace.endOffsetMeters}');
    print('[WORLD_TRACE_AUDIT] lengthMeters=$length');
    print('[WORLD_TRACE_AUDIT] origin=UNKNOWN_NO_PERSISTED_PROVENANCE');
    print('[WORLD_TRACE_AUDIT] minimumWinningRegionViolation=false');
  }

  String _snapshotFingerprint(Iterable<dynamic> traces) {
    final values = traces
        .map((trace) => '${trace.sourceDriveSessionId}|${trace.validatedRoadId}|'
            '${trace.matchedSectionId}|${trace.startOffsetMeters.toStringAsFixed(3)}|'
            '${trace.endOffsetMeters.toStringAsFixed(3)}')
        .toList()
      ..sort();
    var hash = 2166136261;
    for (final code in values.join(';').codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

enum WorldDiagnosticDiagnosis {
  driveNotFound,
  canonicalTelemetryMissing,
  worldJobNotEnqueued,
  validatedRoadNotCreated,
  mapMatchingPending,
  mapMatchingFailedRetryable,
  mapMatchingFailedPermanent,
  validatedDistanceBelow3km,
  validatedReadyButWorldNotProcessed,
  worldProcessingPending,
  worldProcessingFailed,
  worldIndexCommitMissing,
  traceExistsButUiNotShowing,
  success,
}

extension WorldDiagnosticDiagnosisLabel on WorldDiagnosticDiagnosis {
  String get label => switch (this) {
    WorldDiagnosticDiagnosis.driveNotFound => 'DRIVE_NOT_FOUND',
    WorldDiagnosticDiagnosis.canonicalTelemetryMissing =>
      'CANONICAL_TELEMETRY_MISSING',
    WorldDiagnosticDiagnosis.worldJobNotEnqueued => 'WORLD_JOB_NOT_ENQUEUED',
    WorldDiagnosticDiagnosis.validatedRoadNotCreated =>
      'VALIDATED_ROAD_NOT_CREATED',
    WorldDiagnosticDiagnosis.mapMatchingPending => 'MAP_MATCHING_PENDING',
    WorldDiagnosticDiagnosis.mapMatchingFailedRetryable =>
      'MAP_MATCHING_FAILED_RETRYABLE',
    WorldDiagnosticDiagnosis.mapMatchingFailedPermanent =>
      'MAP_MATCHING_FAILED_PERMANENT',
    WorldDiagnosticDiagnosis.validatedDistanceBelow3km =>
      'VALIDATED_DISTANCE_BELOW_3KM',
    WorldDiagnosticDiagnosis.validatedReadyButWorldNotProcessed =>
      'VALIDATED_READY_BUT_WORLD_NOT_PROCESSED',
    WorldDiagnosticDiagnosis.worldProcessingPending =>
      'WORLD_PROCESSING_PENDING',
    WorldDiagnosticDiagnosis.worldProcessingFailed => 'WORLD_PROCESSING_FAILED',
    WorldDiagnosticDiagnosis.worldIndexCommitMissing =>
      'WORLD_INDEX_COMMIT_MISSING',
    WorldDiagnosticDiagnosis.traceExistsButUiNotShowing =>
      'TRACE_EXISTS_BUT_UI_NOT_SHOWING',
    WorldDiagnosticDiagnosis.success => 'SUCCESS',
  };
}

class WorldDiagnosticInput {
  const WorldDiagnosticInput({
    required this.driveFound,
    required this.canonicalTelemetryPresent,
    required this.validatedRoads,
    required this.processing,
    required this.pendingJobs,
    required this.activeSnapshot,
    required this.activeTraceCount,
  });

  final bool driveFound;
  final bool canonicalTelemetryPresent;
  final List<ValidatedRoad> validatedRoads;
  final WorldDriveProcessingRecord? processing;
  final List<WorldPendingJob> pendingJobs;
  final WorldIndexSnapshot? activeSnapshot;
  final int activeTraceCount;
}

class WorldDiagnosticClassifier {
  const WorldDiagnosticClassifier._();

  static WorldDiagnosticDiagnosis classify(WorldDiagnosticInput input) {
    if (!input.driveFound) return WorldDiagnosticDiagnosis.driveNotFound;
    if (!input.canonicalTelemetryPresent) {
      return WorldDiagnosticDiagnosis.canonicalTelemetryMissing;
    }
    final processing = input.processing;
    final roads = input.validatedRoads;
    if (roads.isEmpty) {
      if (processing?.state == WorldProcessingState.pendingValidation ||
          input.pendingJobs.any(
            (job) =>
                job.status == WorldJobStatus.pending ||
                job.status == WorldJobStatus.retryScheduled,
          )) {
        return WorldDiagnosticDiagnosis.mapMatchingPending;
      }
      if (processing?.state == WorldProcessingState.failedRetryable) {
        return WorldDiagnosticDiagnosis.mapMatchingFailedRetryable;
      }
      if (processing?.state == WorldProcessingState.failedPermanent) {
        return WorldDiagnosticDiagnosis.mapMatchingFailedPermanent;
      }
      return processing == null
          ? WorldDiagnosticDiagnosis.worldJobNotEnqueued
          : WorldDiagnosticDiagnosis.validatedRoadNotCreated;
    }
    if (roads.any(
      (road) =>
          road.status == RoadValidationStatus.failed && road.requiresRetry,
    )) {
      return WorldDiagnosticDiagnosis.mapMatchingFailedRetryable;
    }
    if (roads.any((road) => road.status == RoadValidationStatus.failed)) {
      return WorldDiagnosticDiagnosis.mapMatchingFailedPermanent;
    }
    final validDistance = roads.fold<double>(
      0,
      (sum, road) => sum + road.validDistanceMeters,
    );
    if (validDistance < MyWorldRules.minimumValidDistanceMeters) {
      return WorldDiagnosticDiagnosis.validatedDistanceBelow3km;
    }
    if (processing?.state == WorldProcessingState.pendingValidation) {
      return WorldDiagnosticDiagnosis.mapMatchingPending;
    }
    if (processing?.state == WorldProcessingState.processing) {
      return WorldDiagnosticDiagnosis.worldProcessingPending;
    }
    if (processing?.state == WorldProcessingState.failedRetryable) {
      return WorldDiagnosticDiagnosis.worldProcessingFailed;
    }
    if (processing?.state == WorldProcessingState.failedPermanent) {
      return WorldDiagnosticDiagnosis.worldProcessingFailed;
    }
    if (input.activeTraceCount > 0) return WorldDiagnosticDiagnosis.success;
    if (input.activeSnapshot?.hasProcessedDrive(roads.first.driveSessionId) ??
        false) {
      return WorldDiagnosticDiagnosis.worldIndexCommitMissing;
    }
    return WorldDiagnosticDiagnosis.validatedReadyButWorldNotProcessed;
  }

  static String detail(
    WorldDiagnosticDiagnosis diagnosis,
    List<ValidatedRoad> roads,
    WorldDriveProcessingRecord? processing,
  ) {
    final distance = roads.fold<double>(
      0,
      (sum, road) => sum + road.validDistanceMeters,
    );
    switch (diagnosis) {
      case WorldDiagnosticDiagnosis.validatedDistanceBelow3km:
        return 'Validated road distance = ${distance.toStringAsFixed(1)} m; minimum required = ${MyWorldRules.minimumValidDistanceMeters.toInt()} m.';
      case WorldDiagnosticDiagnosis.mapMatchingFailedRetryable:
        return 'Map matching is retryable. ${processing?.lastError ?? 'See failed road/job metadata.'}';
      case WorldDiagnosticDiagnosis.mapMatchingFailedPermanent:
        return 'Map matching failed permanently. ${processing?.lastError ?? 'See validation metadata.'}';
      case WorldDiagnosticDiagnosis.worldProcessingFailed:
        return 'World processing failed. ${processing?.lastError ?? 'No error recorded.'}';
      case WorldDiagnosticDiagnosis.canonicalTelemetryMissing:
        return 'No canonical telemetry record is stored for this drive.';
      case WorldDiagnosticDiagnosis.success:
        return 'Active World trace exists for this drive.';
      default:
        return processing?.lastError ??
            'Pipeline state requires inspection of the sections above.';
    }
  }
}
