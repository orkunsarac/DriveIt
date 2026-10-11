import 'drive_source_provenance.dart';
import '../models/canonical_telemetry_point.dart';
import 'owner_scoped_local_store.dart';

/// Read boundary for future World/Career consumers. A provenance identity is
/// trusted only after both the dedicated record and telemetry metadata have
/// been durably written and agree for this owner-scoped drive key.
abstract interface class DriveSourceProvenanceReader {
  Future<DriveSourceProvenance> readForDrive(String driveId);
}

class OwnerScopedDriveSourceProvenanceRepository
    implements DriveSourceProvenanceReader {
  OwnerScopedDriveSourceProvenanceRepository(this.store);

  final OwnerScopedLocalStore store;

  @override
  Future<DriveSourceProvenance> readForDrive(String driveId) async {
    if (driveId.isEmpty) {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'drive_identity_missing',
      );
    }

    final record = store.read<Map>(
      store.owner,
      'drive_source_provenance_v1',
      driveId,
    );
    final telemetry = store.read<DriveTelemetryRecord>(
      store.owner,
      'drive_telemetry',
      driveId,
    );
    if (record == null &&
        (telemetry == null ||
            !const [
              'sourceIdentity',
              'sourceIdentityVersion',
              'sourceNamespace',
              'provenanceStatus',
            ].any(telemetry.acquisitionMetadata.containsKey))) {
      return DriveSourceProvenance.unproven(ownerScope: store.scope);
    }
    if (record == null) {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'provenance_evidence_incomplete',
      );
    }

    final DriveSourceProvenance stored;
    try {
      stored = DriveSourceProvenance.fromMap(record);
    } on FormatException {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'stored_provenance_invalid',
      );
    } on StateError {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'stored_provenance_invalid',
      );
    } on ArgumentError {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'stored_provenance_invalid',
      );
    } on TypeError {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'stored_provenance_invalid',
      );
    }
    if (stored.ownerScope != store.scope) {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'provenance_owner_conflict',
      );
    }
    if (stored.status == DriveProvenanceStatus.conflict) return stored;
    final telemetryHasIdentity = telemetry != null &&
        const [
          'sourceIdentity',
          'sourceIdentityVersion',
          'sourceNamespace',
          'provenanceStatus',
        ].any(telemetry.acquisitionMetadata.containsKey);
    if (stored.status == DriveProvenanceStatus.unproven) {
      if (telemetryHasIdentity) {
        return DriveSourceProvenance.conflict(
          ownerScope: store.scope,
          conflictCode: 'provenance_evidence_conflict',
        );
      }
      return stored;
    }
    if (telemetry == null) {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'provenance_evidence_incomplete',
      );
    }
    final fromTelemetry = DriveSourceProvenance.fromTransferMetadata(
      telemetry.acquisitionMetadata,
      ownerScope: store.scope,
    );
    if (!stored.isProven ||
        !fromTelemetry.isProven ||
        fromTelemetry.ownerScope != store.scope ||
        stored.sourceIdentity != fromTelemetry.sourceIdentity) {
      return DriveSourceProvenance.conflict(
        ownerScope: store.scope,
        conflictCode: 'provenance_evidence_conflict',
      );
    }
    return stored;
  }
}
