import 'package:flutter/material.dart';
import '../services/local_owner_lifecycle.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/career_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../screens/drive_detail_screen.dart';
import 'local_owner_navigator.dart';
import 'local_owner_view.dart';
import '../screens/my_world_map_screen.dart';
import '../screens/world_trace_detail_screen.dart';
import '../features/drive_poster/poster_screens.dart';
import '../services/device_drive_archive.dart';
import '../services/android_device_archive_authorizer.dart';
import '../screens/owned_drive_screen.dart';

/// Controlled harness only. Unfinished routes deliberately remain unregistered
/// rather than falling back to a global personal data consumer.
class OwnerPersonalNavigator extends StatelessWidget {
  const OwnerPersonalNavigator({
    super.key,
    required this.runtime,
    required this.legacyChild,
    this.deviceArchive,
    this.deviceArchiveSnapshot,
  }) : assert(deviceArchive == null || deviceArchiveSnapshot == null);
  final LocalOwnerLifecycle runtime;
  final Widget legacyChild;
  final DeviceDriveArchiveAccess? deviceArchive;

  /// Verified device snapshot only; no account/global-store fallback discovery.
  final DeviceDriveArchiveSnapshot? deviceArchiveSnapshot;
  @override
  Widget build(BuildContext context) => LocalOwnerNavigator(
    runtime: runtime,
    legacyChild: legacyChild,
    routes: {
      '/': (_, lease, _) => HomeScreen(ownerLease: lease),
      '/history': (_, lease, _) => HistoryScreen(
        ownerLease: lease,
        deviceArchive:
            deviceArchive ??
            (deviceArchiveSnapshot == null
                ? null
                : androidDeviceDriveArchiveAccess(
                    gate: runtime.gate,
                    snapshot: deviceArchiveSnapshot!,
                  )),
        ownedDetailBuilder: (lease, id) =>
            OwnedDriveDetailScreen(lease: lease, driveId: id),
      ),
      '/drive': (_, lease, _) => OwnedDriveScreen(lease: lease),
      '/career': (_, lease, _) => CareerScreen(
        ownerLease: lease,
        ownedDetailBuilder: (lease, id) =>
            OwnedDriveDetailScreen(lease: lease, driveId: id),
      ),
      '/profile': (_, lease, _) => ProfileSettingsScreen(ownerLease: lease),
      '/world': (_, lease, _) => MyWorldMapScreen(ownerLease: lease),
      '/world-trace': (_, lease, id) => id is String
          ? OwnedWorldTraceDetailScreen(lease: lease, traceId: id)
          : const OwnerAccessUnavailable(),
      '/detail': (_, lease, id) => id is String
          ? OwnedDriveDetailScreen(lease: lease, driveId: id)
          : const OwnerAccessUnavailable(),
      '/posters': (_, lease, _) => PosterCenterScreen(ownerLease: lease),
    },
  );
}
