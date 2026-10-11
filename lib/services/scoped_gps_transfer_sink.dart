import 'dart:convert';

import '../models/drive_session.dart';
import '../models/canonical_telemetry_point.dart';
import 'gps_hive_transfer_sink.dart';
import 'gps_session_transfer.dart';
import 'gps_session_store.dart';
import 'gps_session_ownership.dart';
import 'drive_source_provenance.dart';
import 'owner_scoped_local_store.dart';
import 'owned_gps_session_coordinator.dart';
import 'owned_drive_finalization.dart';

/// Dormant, immutable destination. Construct only from a ready sidecar binding.
class ScopedGpsTransferSink
    implements OwnedGpsTransferSink, ProvenanceGpsTransferSink {
  ScopedGpsTransferSink(this.store, GpsOwnershipManifest binding) {
    if (binding.state != 'ready' || binding.targetStore != store.scope) {
      throw StateError('GPS destination ownership conflict');
    }
    sessionId = binding.sessionId!;
  }
  final OwnerScopedLocalStore store;
  late final String sessionId;
  @override
  String get targetStore => store.scope;
  void _check(String id) {
    if (id != sessionId) throw StateError('GPS session identity conflict');
  }

  @override
  Future<Map<String, dynamic>?> readDrive(String id) async {
    _check(id);
    final drive = store.read<DriveSession>(store.owner, 'drives', id);
    return drive == null ? null : driveTransferManifest(drive);
  }

  @override
  Future<List<CanonicalTelemetryPoint>?> readTelemetry(String id) async {
    _check(id);
    return store
        .read<DriveTelemetryRecord>(store.owner, 'drive_telemetry', id)
        ?.points;
  }

  @override
  Future<String?> readSourceIdentity(String id) async {
    _check(id);
    final metadata = store.read<Map>(
      store.owner,
      'drive_source_provenance_v1',
      id,
    );
    final telemetry = store.read<DriveTelemetryRecord>(
      store.owner,
      'drive_telemetry',
      id,
    );
    final recorded = metadata?['sourceIdentity'] as String?;
    final telemetryIdentity =
        telemetry?.acquisitionMetadata['sourceIdentity'] as String?;
    if (recorded != null &&
        telemetryIdentity != null &&
        recorded != telemetryIdentity) {
      throw StateError('Drive provenance evidence conflicts');
    }
    return recorded ?? telemetryIdentity;
  }

  @override
  Future<void> persistSourceIdentity(String id, String sourceIdentity) async {
    _check(id);
    final existing = await readSourceIdentity(id);
    if (existing != null && existing != sourceIdentity) {
      throw StateError('Drive source identity is immutable');
    }
    final telemetry = store.read<DriveTelemetryRecord>(
      store.owner,
      'drive_telemetry',
      id,
    );
    if (telemetry?.acquisitionMetadata['sourceIdentity'] != sourceIdentity ||
        telemetry?.acquisitionMetadata['sourceIdentityVersion'] != 1 ||
        telemetry?.acquisitionMetadata['sourceNamespace'] !=
            'drive_source_v1' ||
        telemetry?.acquisitionMetadata['provenanceStatus'] != 'proven') {
      throw StateError('Telemetry source identity evidence missing');
    }
    final provenance = DriveSourceProvenance.proven(
      sourceIdentity: sourceIdentity,
      ownerScope: store.scope,
    ).toMap();
    final saved = store.read<Map>(
      store.owner,
      'drive_source_provenance_v1',
      id,
    );
    if (saved != null && jsonEncode(saved) != jsonEncode(provenance)) {
      throw StateError('Stored source identity conflict');
    }
    if (saved == null) {
      await store.put(
        store.owner,
        'drive_source_provenance_v1',
        id,
        provenance,
      );
    }
  }

  @override
  Future<void> writeDrive(String id, Map<String, dynamic> manifest) async {
    _check(id);
    final date = {
      'dateMicros': manifest['dateMicros'],
      'dateIsUtc': manifest['dateIsUtc'],
    };
    final existing = store.read<Map>(
      store.owner,
      'drive_details_v1',
      'gpsTransferDate:$id',
    );
    if (existing != null && jsonEncode(existing) != jsonEncode(date)) {
      throw StateError('Drive transfer date conflict');
    }
    await store.put(
      store.owner,
      'drive_details_v1',
      'gpsTransferDate:$id',
      date,
    );
    await store.put(
      store.owner,
      'drives',
      id,
      driveFromTransferManifest(manifest),
    );
  }

  @override
  Future<void> writeTelemetry(
    String id,
    List<CanonicalTelemetryPoint> points,
    Map<String, dynamic> metadata,
  ) async {
    _check(id);
    final sourceIdentity = metadata['sourceIdentity'] as String?;
    if (sourceIdentity != null &&
        (!RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ).hasMatch(sourceIdentity) ||
            metadata['sourceIdentityVersion'] != 1 ||
            metadata['sourceNamespace'] != 'drive_source_v1' ||
            metadata['provenanceStatus'] != 'proven')) {
      throw StateError('Invalid source identity metadata');
    }
    await store.put(
      store.owner,
      'drive_telemetry',
      id,
      DriveTelemetryRecord(
        driveSessionId: id,
        dataVersion: 1,
        createdAt: DateTime.now(),
        points: points,
        acquisitionMetadata: {
          ...metadata,
          'preserveCanonicalTimestampV1': true,
        },
      ),
    );
  }

  @override
  Future<void> flush() => store.flush(store.owner);

  /// Never infer cleanup permission from a single receipt or saved flag.
  Future<bool> cleanup({
    required GpsSessionStore journal,
    required GpsOwnershipStore ownership,
    required String journalId,
    required DateTime now,
  }) async {
    final binding = await ownership.get(journalId, sessionId);
    final finalization = store.read<Map>(
      store.owner,
      OwnedDriveFinalization.group,
      sessionId,
    );
    if (binding == null ||
        !store.writeDurable(OwnedDriveFinalization.group, sessionId) ||
        (finalization != null && finalization['state'] != 'completed') ||
        binding.targetStore != targetStore ||
        !await ownership.verified(journalId, sessionId) ||
        !await GpsSessionTransfer(journal, this).verify(sessionId) ||
        !await journal.maintenanceEligible(sessionId, now)) {
      return false;
    }
    await journal.removeVerifiedJournal(
      sessionId,
      now: now,
      verifyHive: (_) async {
        final current = await ownership.get(journalId, sessionId);
        return current?.targetStore == targetStore &&
            await ownership.verified(journalId, sessionId) &&
            await GpsSessionTransfer(journal, this).verify(sessionId);
      },
    );
    return true;
  }
}
