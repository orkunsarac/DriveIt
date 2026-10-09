import 'gps_failure.dart';
import 'gps_session_store.dart';

enum DriveRecoveryKind {
  none,
  verifiedSession,
  storageUnavailable,
  legacyPossible,
}

class DriveRecoveryStatus {
  const DriveRecoveryStatus(
    this.kind, {
    this.session,
    this.failure,
    this.legacyPoints = const [],
  });
  final DriveRecoveryKind kind;
  final GpsSession? session;
  final GpsFailure? failure;
  final List<Map<String, dynamic>> legacyPoints;
  bool get canStartNewDrive => kind == DriveRecoveryKind.none;
  bool get hasVerifiedSession => kind == DriveRecoveryKind.verifiedSession;
}

/// Read-only decision. A failure is unknown, never "active" or "empty".
Future<DriveRecoveryStatus> inspectDriveRecovery({
  required Future<GpsSession?> Function() loadActive,
  required Future<bool> Function() legacyActive,
  required Future<List<Map<String, dynamic>>> Function() loadLegacy,
}) async {
  try {
    final session = await loadActive();
    if (session != null) {
      if (session.state != 'recording' && session.state != 'stopped') {
        throw GpsFailure(GpsErrorCode.recovery);
      }
      return DriveRecoveryStatus(
        DriveRecoveryKind.verifiedSession,
        session: session,
      );
    }
    if (await legacyActive()) {
      return DriveRecoveryStatus(
        DriveRecoveryKind.legacyPossible,
        failure: GpsFailure(GpsErrorCode.legacyRecovery),
        legacyPoints: await loadLegacy(),
      );
    }
    return const DriveRecoveryStatus(DriveRecoveryKind.none);
  } catch (error) {
    final failure = GpsFailure.from(error, GpsErrorCode.recovery);
    failure.report('recovery_probe');
    return DriveRecoveryStatus(
      DriveRecoveryKind.storageUnavailable,
      failure: failure,
    );
  }
}
