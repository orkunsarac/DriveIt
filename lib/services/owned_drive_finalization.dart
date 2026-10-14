import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../features/drive_score/services/drive_score_persistence_coordinator.dart';
import '../features/my_world/config/my_world_rules.dart';
import '../features/my_world/models/world_pending_job.dart';
import '../models/drive_session.dart';
import '../models/drive_score_record.dart';
import '../models/canonical_telemetry_point.dart';
import 'drive_score_storage_service.dart';
import 'drive_source_provenance_repository.dart';
import 'gps_session_ownership.dart';
import 'local_source_bundle.dart';
import 'owner_scoped_local_store.dart';

const bool _releaseAcceptanceDiagnostics =
    bool.fromEnvironment('dart.vm.product') &&
    bool.fromEnvironment('DRIVEIT_RELEASE_ACCEPTANCE') &&
    bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST');

/// Privacy-limited breadcrumbs enabled only by the isolated release test build.
/// Never logs coordinates, owner UUIDs, payloads, or exception messages.
void driveItReleaseAcceptanceDiagnostic(
  String stage, {
  GpsOwnershipManifest? binding,
  int? ownerEpoch,
  Object? error,
  StackTrace? stackTrace,
}) {
  if (!_releaseAcceptanceDiagnostics) return;
  final sessionId = binding?.sessionId ?? '<none>';
  final sourceIdentity = binding?.provenance.sourceIdentity ?? '<none>';
  final ownerKind = binding?.owner.wireKind ?? '<none>';
  debugPrint(
    'DRIVEIT_FINALIZATION stage=$stage ownerEpoch=${ownerEpoch ?? '<n/a>'} '
    'ownerKind=$ownerKind sessionId=$sessionId sourceIdentity=$sourceIdentity'
    '${error == null ? '' : ' errorType=${error.runtimeType}'}',
  );
  if (stackTrace != null) {
    for (final line in stackTrace.toString().split('\n')) {
      debugPrint('DRIVEIT_FINALIZATION_STACK $line');
    }
  }
}

/// Only composed inside a pinned owner operation. This is a resumable local
/// finalization, not import/revision visibility and not a second GPS engine.
class OwnedDriveFinalization {
  OwnedDriveFinalization({
    required this.store,
    required this.binding,
    required this.requireCurrent,
    this.ownerEpoch,
  });
  static const group = 'owned_drive_finalization_v1';
  final OwnerScopedLocalStore store;
  final GpsOwnershipManifest binding;
  final void Function() requireCurrent;
  final int Function()? ownerEpoch;
  String get id => binding.sessionId!;
  Map<String, Object?> get identity => {
    'version': 1,
    'sessionId': id,
    'ownerScope': store.scope,
    'sourceIdentity': binding.provenance.sourceIdentity,
  };

  Future<void> prepare() async {
    driveItReleaseAcceptanceDiagnostic(
      'prepare_started',
      binding: binding,
      ownerEpoch: ownerEpoch?.call(),
    );
    requireCurrent();
    store.requireOwner(binding.owner);
    if (binding.state != 'ready' ||
        !binding.provenance.isProven ||
        binding.provenance.ownerScope != store.scope) {
      throw StateError('Owned finalization evidence missing');
    }
    final previous = store.read<Map>(store.owner, group, id);
    if (previous != null &&
        identity.entries.any((e) => previous[e.key] != e.value)) {
      throw StateError('Owned finalization identity conflict');
    }
    // Reflush retry, including an in-memory value left after failed flush.
    await store.put(
      store.owner,
      group,
      id,
      previous ?? {...identity, 'state': 'pending', 'derivedReady': false},
    );
    driveItReleaseAcceptanceDiagnostic(
      'prepare_persisted_pending',
      binding: binding,
      ownerEpoch: ownerEpoch?.call(),
    );
  }

  Future<void> derive(Map<String, dynamic> manifest) async {
    driveItReleaseAcceptanceDiagnostic(
      'derive_started',
      binding: binding,
      ownerEpoch: ownerEpoch?.call(),
    );
    try {
      requireCurrent();
      final drive = store.read<DriveSession>(store.owner, 'drives', id);
      final telemetry = store.read<DriveTelemetryRecord>(
        store.owner,
        'drive_telemetry',
        id,
      );
      final provenance = await OwnerScopedDriveSourceProvenanceRepository(
        store,
      ).readForDrive(id);
      if (drive == null ||
          telemetry == null ||
          !provenance.isProven ||
          provenance.sourceIdentity != binding.provenance.sourceIdentity ||
          drive.id != id ||
          manifest['id'] != id) {
        throw StateError('Owned finalization read-back failed');
      }
      driveItReleaseAcceptanceDiagnostic(
        'owner_readback_verified',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
      // Source date, projection and telemetry are the already-frozen transfer
      // intent's data. A later save UI proposal never replaces that snapshot.
      final fingerprint = sha256
          .convert(
            utf8.encode(
              jsonEncode(
                LocalSourceBundle(
                  drive: drive,
                  telemetry: telemetry,
                  ownerScope: store.scope,
                  sourceProvenance: provenance,
                ).toMap(),
              ),
            ),
          )
          .toString();
      final previous = store.read<Map>(store.owner, group, id)!;
      if (previous['fingerprint'] != null &&
          previous['fingerprint'] != fingerprint) {
        throw StateError('Owned finalization source conflict');
      }
      await store.put(store.owner, group, id, {
        ...previous,
        'fingerprint': fingerprint,
      });
      driveItReleaseAcceptanceDiagnostic(
        'fingerprint_persisted',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
      requireCurrent();
      await const DriveScorePersistenceCoordinator().calculateAndPersist(
        driveId: id,
        existing: store.read<DriveScoreRecord>(
          store.owner,
          'drive_scores',
          DriveScoreStorageService.keyFor(
            id,
            DriveScoreRecord.currentAlgorithmVersion,
          ),
        ),
        telemetry: telemetry,
        persist: (record) => store.put(
          store.owner,
          'drive_scores',
          DriveScoreStorageService.keyFor(id, record.algorithmVersion),
          record,
        ),
      );
      requireCurrent();
      // All consumers use the durable adapter round-trip, never a transient
      // calculator object with a different DateTime precision on retry.
      final score = store.read<DriveScoreRecord>(
        store.owner,
        'drive_scores',
        DriveScoreStorageService.keyFor(
          id,
          DriveScoreRecord.currentAlgorithmVersion,
        ),
      );
      driveItReleaseAcceptanceDiagnostic(
        'score_persisted',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
      final source = LocalSourceBundle(
        drive: drive,
        telemetry: telemetry,
        score: score,
        ownerScope: store.scope,
        sourceProvenance: provenance,
      );
      final repositories = store.repositories(store.owner);
      await repositories.prepareSource(source);
      driveItReleaseAcceptanceDiagnostic(
        'source_prepared',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
      requireCurrent();
      await repositories.contribute(source);
      driveItReleaseAcceptanceDiagnostic(
        'career_contribution_persisted',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
      // Validate visible accounting now, not only the append-only write.
      repositories.careerStatistics();
      requireCurrent();
      if (score != null &&
          drive.distance >= MyWorldRules.minimumValidDistanceMeters) {
        final world = store.worldSources(store.owner);
        // Persist the job before acknowledging the GPS source. Network matching
        // and generation writes belong to the independent owner-pinned worker.
        final inserted = await world.enqueueIfAbsent(
          WorldPendingJob.pending(
            driveSessionId: id,
            type: WorldJobType.validateRoad,
            now: DateTime.now().toUtc(),
          ),
        );
        driveItReleaseAcceptanceDiagnostic(
          'world_job_durable inserted=$inserted',
          binding: binding,
          ownerEpoch: ownerEpoch?.call(),
        );
      }
      // Independent Hive boxes are not one transaction. Reflush/read-back via
      // store before releasing SQLite's active stopped-session pointer.
      await store.flush(store.owner);
      driveItReleaseAcceptanceDiagnostic(
        'owner_boxes_flushed',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
      requireCurrent();
      await store.put(store.owner, group, id, {
        ...store.read<Map>(store.owner, group, id)!,
        'derivedReady': true,
        'scoreAvailable': score != null,
        // Queue durability is not evidence of validation or World ownership.
        'worldQueued':
            score != null &&
            drive.distance >= MyWorldRules.minimumValidDistanceMeters,
      });
      driveItReleaseAcceptanceDiagnostic(
        'derived_ready_persisted',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
      );
    } catch (error, stackTrace) {
      driveItReleaseAcceptanceDiagnostic(
        'derive_failed',
        binding: binding,
        ownerEpoch: ownerEpoch?.call(),
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Only call after fresh journal + sidecar + destination receipt verification.
  Future<void> complete() async {
    driveItReleaseAcceptanceDiagnostic(
      'complete_started',
      binding: binding,
      ownerEpoch: ownerEpoch?.call(),
    );
    requireCurrent();
    final record = store.read<Map>(store.owner, group, id)!;
    if (record['derivedReady'] != true) {
      throw StateError('Finalization incomplete');
    }
    await store.put(store.owner, group, id, {...record, 'state': 'completed'});
    driveItReleaseAcceptanceDiagnostic(
      'completed',
      binding: binding,
      ownerEpoch: ownerEpoch?.call(),
    );
  }
}
