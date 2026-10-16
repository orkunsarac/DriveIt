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
import '../screens/world_mode_selection_screen.dart';
import '../screens/world_trace_detail_screen.dart';
import '../features/drive_poster/poster_screens.dart';
import '../services/device_drive_archive.dart';
import '../services/android_device_archive_authorizer.dart';
import '../screens/owned_drive_screen.dart';
import '../screens/owner_cloud_sync_screen.dart';
import '../features/group_drive/group_drive_screen.dart';
import '../features/group_drive/group_drive_service.dart';
import '../features/group_drive/group_gps_source.dart';
import '../screens/account_drive_transfer_screen.dart';

/// Owner navigation shared by the normal application and controlled tests.
/// Unfinished routes remain unregistered instead of using shared personal data.
class OwnerPersonalNavigator extends StatelessWidget {
  const OwnerPersonalNavigator({
    super.key,
    required this.runtime,
    required this.legacyChild,
    this.deviceArchive,
    this.deviceArchiveSnapshot,
    this.deviceArchiveLoader,
    this.initialRoute = '/',
    this.navigatorKey,
    this.groupDriveServiceForTesting,
    this.groupDriveService,
    this.groupGpsSourceFactory,
  }) : assert(deviceArchive == null || deviceArchiveSnapshot == null);
  final LocalOwnerLifecycle runtime;
  final String initialRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget legacyChild;

  /// Explicit simulator injection only; production does not construct it.
  final FakeGroupDriveService? groupDriveServiceForTesting;
  final GroupDriveService? groupDriveService;
  GroupDriveService? get _groupDriveService =>
      groupDriveService ?? groupDriveServiceForTesting;
  final GroupGpsSource Function()? groupGpsSourceFactory;
  final DeviceDriveArchiveAccess? deviceArchive;

  /// Verified device snapshot only; no account/global-store fallback discovery.
  final DeviceDriveArchiveSnapshot? deviceArchiveSnapshot;
  final Future<DeviceDriveArchiveAccess> Function(LocalOwnerLease)?
  deviceArchiveLoader;
  @override
  Widget build(BuildContext context) => LocalOwnerNavigator(
    runtime: runtime,
    initialRoute: initialRoute,
    navigatorKey: navigatorKey,
    legacyChild: legacyChild,
    routes: {
      '/': (_, lease, _) => GuestTransferPrompt(
        lease: lease,
        child: HomeScreen(
          ownerLease: lease,
          groupDriveAvailable: _groupDriveService != null,
        ),
      ),
      if (_groupDriveService != null)
        '/group': (_, lease, _) => GroupDriveScreen(
          lease: lease,
          service: _groupDriveService!,
          gpsSource: groupGpsSourceFactory?.call(),
        ),
      '/history': (_, lease, _) => HistoryScreen(
        ownerLease: lease,
        deviceArchiveLoader: deviceArchiveLoader,
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
      '/profile': (_, lease, _) => ProfileSettingsScreen(
        ownerLease: lease,
        deviceArchiveLoader: deviceArchiveLoader,
      ),
      '/cloud-sync': (_, lease, _) => OwnerCloudSyncScreen(lease: lease),
      '/account-transfer': (_, lease, _) =>
          AccountDriveTransferScreen(lease: lease),
      '/world': (_, lease, _) => WorldModeSelectionScreen(
        loadData: lease.worldMap,
        myWorldBuilder: (_) => MyWorldMapScreen(ownerLease: lease),
      ),
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
