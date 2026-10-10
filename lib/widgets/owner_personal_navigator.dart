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

/// Controlled harness only. Unfinished routes deliberately remain unregistered
/// rather than falling back to a global personal data consumer.
class OwnerPersonalNavigator extends StatelessWidget {
  const OwnerPersonalNavigator({
    super.key,
    required this.runtime,
    required this.legacyChild,
  });
  final LocalOwnerLifecycle runtime;
  final Widget legacyChild;
  @override
  Widget build(BuildContext context) => LocalOwnerNavigator(
    runtime: runtime,
    legacyChild: legacyChild,
    routes: {
      '/': (_, lease, _) => HomeScreen(ownerLease: lease),
      '/history': (_, lease, _) => HistoryScreen(
        ownerLease: lease,
        ownedDetailBuilder: (lease, id) =>
            OwnedDriveDetailScreen(lease: lease, driveId: id),
      ),
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
    },
  );
}
