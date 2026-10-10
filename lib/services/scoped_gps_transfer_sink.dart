import '../models/drive_session.dart';
import '../models/canonical_telemetry_point.dart';
import 'gps_hive_transfer_sink.dart';
import 'gps_session_transfer.dart';
import 'gps_session_store.dart';
import 'gps_session_ownership.dart';
import 'owner_scoped_local_store.dart';
import 'owned_gps_session_coordinator.dart';

/// Dormant, immutable destination. Construct only from a ready sidecar binding.
class ScopedGpsTransferSink implements OwnedGpsTransferSink {
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
  Future<void> writeDrive(String id, Map<String, dynamic> manifest) {
    _check(id);
    return store.put(
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
  ) {
    _check(id);
    return store.put(
      store.owner,
      'drive_telemetry',
      id,
      DriveTelemetryRecord(
        driveSessionId: id,
        dataVersion: 1,
        createdAt: DateTime.now(),
        points: points,
        acquisitionMetadata: metadata,
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
    if (binding == null ||
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
