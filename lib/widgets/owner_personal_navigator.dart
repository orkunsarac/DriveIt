import 'dart:async';
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
import '../features/group_drive/group_drive_session.dart';
import '../screens/account_drive_transfer_screen.dart';

/// Owner navigation shared by the normal application and controlled tests.
/// Unfinished routes remain unregistered instead of using shared personal data.
class OwnerPersonalNavigator extends StatefulWidget {
  const OwnerPersonalNavigator({
    super.key,
    required this.runtime,
    required this.legacyChild,
    this.deviceArchive,
    this.deviceArchiveSnapshot,
    this.deviceArchiveLoader,
    this.initialRoute = '/',
    this.installationOnboardingCompleted = false,
    this.navigatorKey,
    this.groupDriveServiceForTesting,
    this.groupDriveService,
    this.groupGpsSourceFactory,
  }) : assert(deviceArchive == null || deviceArchiveSnapshot == null);
  final LocalOwnerLifecycle runtime;
  final String initialRoute;
  final bool installationOnboardingCompleted;
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
  State<OwnerPersonalNavigator> createState() => _OwnerPersonalNavigatorState();
}

class _OwnerPersonalNavigatorState extends State<OwnerPersonalNavigator> {
  GroupDriveSession? _groupSession;
  _DriveGroupOrigin? _activeDrive;
  LocalOwnerLifecycle get runtime => widget.runtime;
  String get initialRoute => widget.initialRoute;
  GlobalKey<NavigatorState>? get navigatorKey => widget.navigatorKey;
  Widget get legacyChild => widget.legacyChild;
  GroupDriveService? get _groupDriveService => widget._groupDriveService;
  GroupGpsSource Function()? get groupGpsSourceFactory =>
      widget.groupGpsSourceFactory;
  DeviceDriveArchiveAccess? get deviceArchive => widget.deviceArchive;
  DeviceDriveArchiveSnapshot? get deviceArchiveSnapshot =>
      widget.deviceArchiveSnapshot;
  Future<DeviceDriveArchiveAccess> Function(LocalOwnerLease)?
  get deviceArchiveLoader => widget.deviceArchiveLoader;

  GroupDriveSession? _sessionFor(LocalOwnerLease lease) {
    if (_groupDriveService == null || lease.owner.userId == null) return null;
    if (!identical(_groupSession?.lease, lease)) {
      final source = groupGpsSourceFactory?.call();
      if (source is! BackgroundGroupGpsSource) return null;
      final previous = _groupSession;
      if (previous != null) unawaited(previous.close());
      _groupSession = GroupDriveSession(
        lease: lease,
        service: _groupDriveService!,
        source: source,
      );
    }
    return _groupSession;
  }

  Widget _groupPage(BuildContext context, LocalOwnerLease lease) {
    final candidate = _activeDrive;
    final origin =
        candidate != null &&
            identical(candidate.lease, lease) &&
            candidate.route.isActive
        ? candidate
        : null;
    final session = _sessionFor(lease);
    void goHome() {
      if (!lease.isCurrent) return;
      final navigator = Navigator.of(context);
      if (origin != null && origin.route.isActive) {
        // Keep the existing recorder below a Home route. Popping to the first
        // route would dispose it and terminate the independent drive consumer.
        navigator.pushNamedAndRemoveUntil(
          '/',
          (route) => identical(route, origin.route),
        );
      } else if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      } else {
        navigator.pushReplacementNamed('/');
      }
    }

    if (session != null) {
      return GroupDriveScreen(
        lease: lease,
        service: _groupDriveService!,
        gpsSource: session.gps.source,
        session: session,
        onReturnToDrive: origin?.returnToDrive,
        onGoToDrive: () {
          if (origin != null && origin.route.isActive) {
            origin.returnToDrive();
          } else {
            Navigator.of(context).pushNamed('/drive');
          }
        },
        onGoHome: goHome,
      );
    }
    return GroupDriveScreen(
      lease: lease,
      service: _groupDriveService!,
      gpsSource: groupGpsSourceFactory?.call(),
      onReturnToDrive: origin?.returnToDrive,
      onGoToDrive: () {
        if (origin != null && origin.route.isActive) {
          origin.returnToDrive();
        } else {
          Navigator.of(context).pushNamed('/drive');
        }
      },
      onGoHome: goHome,
    );
  }

  Widget _drivePage(BuildContext context, LocalOwnerLease lease) {
    final session = _sessionFor(lease);
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    final origin = _DriveGroupOrigin(
      lease: lease,
      route: route,
      navigator: navigator,
    );
    return OwnedDriveScreen(
      lease: lease,
      onRecordingChanged: (active) {
        if (active && lease.isCurrent && route.isActive) {
          _activeDrive = origin;
        } else if (identical(_activeDrive?.route, route)) {
          _activeDrive = null;
        }
      },
      activeGroupAction: session == null
          ? null
          : ListenableBuilder(
              listenable: session,
              builder: (_, _) => !session.hasActiveMembership
                  ? const SizedBox.shrink()
                  : FilledButton.tonalIcon(
                      key: const Key('drive_open_group'),
                      icon: const Icon(Icons.group),
                      label: const Text('Grup Sürüşüne Geç'),
                      onPressed: () {
                        if (!lease.isCurrent ||
                            !route.isCurrent ||
                            !session.hasActiveMembership) {
                          return;
                        }
                        // Push above the existing recorder. Never pop/replace its
                        // route: MapScreen's session, timers and journal stay live.
                        navigator.pushNamed('/group');
                      },
                    ),
            ),
    );
  }

  @override
  void dispose() {
    final session = _groupSession;
    if (session != null) unawaited(session.close());
    super.dispose();
  }

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
          installationOnboardingCompleted:
              widget.installationOnboardingCompleted,
        ),
      ),
      if (_groupDriveService != null)
        '/group': (context, lease, _) => _groupPage(context, lease),
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
      '/drive': (context, lease, _) => _drivePage(context, lease),
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

/// Only a live, owner-bound drive route can be a return target. This handle
/// is in memory and never creates or recovers a recording session.
class _DriveGroupOrigin {
  const _DriveGroupOrigin({
    required this.lease,
    required this.route,
    required this.navigator,
  });
  final LocalOwnerLease lease;
  final Route<void> route;
  final NavigatorState navigator;

  void returnToDrive() {
    if (lease.isCurrent && route.isActive && navigator.mounted) {
      navigator.popUntil((candidate) => identical(candidate, route));
    }
  }
}
