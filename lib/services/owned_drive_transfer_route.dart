import '../config/local_ownership_gate.dart';

typedef OwnedDriveTransfer =
    Future<void> Function(String, Map<String, dynamic>);

/// Pure storage routing seam. No foreground/plugin/importer dependency enters
/// the legacy Hive sink or standalone recovery tools. Not installed normally.
abstract final class OwnedDriveTransferRoute {
  static OwnedDriveTransfer? _transfer;
  static OwnedDriveTransfer? get transfer => _transfer;
  static void attachForTesting(
    LocalOwnershipGate gate,
    OwnedDriveTransfer transfer,
  ) {
    if (!LocalOwnershipGate.debugBuild || !gate.enabled || _transfer != null) {
      throw StateError('Controlled transfer unavailable');
    }
    _transfer = transfer;
  }

  static void detachForTesting(OwnedDriveTransfer transfer) {
    if (!identical(_transfer, transfer)) {
      throw StateError('Controlled transfer conflict');
    }
    _transfer = null;
  }
}
