import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/local_owner_lifecycle.dart';
import 'group_drive_models.dart';
import 'group_drive_service.dart';
import 'group_gps_sharing.dart';
import 'group_gps_source.dart';

/// Kept by the owner navigator, never by a group route or persistent store.
class GroupDriveSession extends ChangeNotifier {
  GroupDriveSession({
    required this.lease,
    required GroupDriveService service,
    required GroupGpsSource source,
  }) {
    client = service.forOwner(lease);
    gps = GroupGpsSharing(
      lease: lease,
      client: client,
      source: source,
      clock: () => service.simulationTime,
    );
    _watch = client.changes.listen(
      (value) {
        if (_closed) return;
        snapshot = value;
        gps.updateGroup(value);
        notifyListeners();
      },
      onError: (Object _) {
        // A lost authorization/transport cannot leave a background publisher live.
        gps.updateGroup(null);
        snapshot = null;
        if (!_closed) notifyListeners();
      },
    );
    lease.changes.addListener(_ownerChanged);
    unawaited(refresh());
  }
  final LocalOwnerLease lease;
  late final GroupDriveClient client;
  late final GroupGpsSharing gps;
  late final StreamSubscription<GroupDriveSnapshot?> _watch;
  GroupDriveSnapshot? snapshot;
  bool _closed = false;

  bool get hasActiveMembership =>
      !_closed &&
      lease.isCurrent &&
      snapshot?.isActive == true &&
      snapshot!.members.any((m) => m.accountId == lease.owner.userId);

  Future<void> refresh() async {
    try {
      final value = await client.current();
      if (_closed || !lease.isCurrent) return;
      snapshot = value;
      gps.updateGroup(value);
      notifyListeners();
    } catch (_) {
      if (_closed) return;
      snapshot = null;
      gps.updateGroup(null);
      notifyListeners();
    }
  }

  void _ownerChanged() {
    if (!lease.isCurrent) unawaited(close());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    lease.changes.removeListener(_ownerChanged);
    await _watch.cancel();
    try {
      await gps.close();
    } finally {
      gps.dispose();
      await client.close();
      dispose();
    }
  }
}
