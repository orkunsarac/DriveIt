import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/local_ownership_gate.dart';
import '../config/supabase_bootstrap.dart';
import '../features/my_world/providers/mapbox/mapbox_road_matching_provider.dart';
import '../features/my_world/services/road_matching_service.dart';
import 'device_guest_owner_identity.dart';
import 'foreground_service.dart';
import 'gps_session_ownership.dart';
import 'gps_session_runtime.dart';
import 'local_ownership_bootstrap.dart';
import 'local_owner_lifecycle.dart';
import 'owned_foreground_bootstrap.dart';
import 'owner_scoped_local_store.dart';
import 'supabase_local_owner_auth.dart';
import 'supabase_owner_drive_sync_adapter.dart';
import 'account_drive_transfer.dart';
import 'legacy_drive_transfer_source.dart';
import 'android_device_archive_authorizer.dart';
import '../features/group_drive/supabase_group_drive_service.dart';

/// No Auth UID is fabricated when cloud Auth isn't configured. The caller must
/// obtain the user's explicit Guest choice before mounting the owner runtime.
class UnavailableCloudOwnerAuth implements LocalOwnerAuth {
  const UnavailableCloudOwnerAuth();

  @override
  String? get userId => null;

  @override
  Stream<String?> get changes => const Stream<String?>.empty();
}

class ProductionOwnerRuntimeDependencies {
  ProductionOwnerRuntimeDependencies({
    required this.auth,
    required this.guestOwner,
    required this.controlledBootstrap,
    required this.appSupportDirectory,
    required this.legacyRecoveryRequired,
  });

  final LocalOwnerAuth auth;
  final GpsOwner guestOwner;
  final ControlledOwnershipDependencies controlledBootstrap;
  final Directory appSupportDirectory;
  final bool legacyRecoveryRequired;
}

/// Real application composition. This factory never creates fake Auth/GPS,
/// a fake group service. Cloud sync requires a separate explicit build opt-in
/// and an authenticated backend capability check; normal builds leave it off.
abstract final class ProductionOwnerRuntimeFactory {
  /// Leave false until the matching backend is deployed and accepted.
  static const accountSyncEnabled = bool.fromEnvironment(
    'DRIVEIT_ACCOUNT_SYNC_ENABLED',
  );

  /// Separate rollout opt-in; M1-only builds and Guest never gain cloud delete.
  static const accountDeletionEnabled =
      accountSyncEnabled &&
      bool.fromEnvironment('DRIVEIT_ACCOUNT_DELETE_ENABLED');
  /// Keep disabled until M4 migration/Realtime security is deployed and accepted.
  static const accountGroupDriveEnabled =
      bool.fromEnvironment('DRIVEIT_GROUP_DRIVE_ENABLED');
  static Future<ProductionOwnerRuntimeDependencies> create() async {
    if (!LocalOwnershipGate.production.enabled ||
        !LocalOwnershipGate.localProductionActivation) {
      throw StateError('Local production owner activation is not enabled');
    }

    final support = await getApplicationSupportDirectory();
    final guestOwner = await DeviceGuestOwnerIdentity.loadOrCreate(support);
    final descriptor = await OwnedForegroundBootstrap.prepareForProduction();
    final hasCloudAuth = await SupabaseBootstrap.initializeIfConfigured();
    final auth = hasCloudAuth
        ? SupabaseLocalOwnerAuth(Supabase.instance.client)
        : const UnavailableCloudOwnerAuth();

    final bool legacyRecoveryRequired;
    try {
      final legacyJournal = await openGpsJournal();
      try {
        legacyRecoveryRequired =
            await FlutterForegroundTask.isRunningService ||
            await legacyJournal.active() != null ||
            (await legacyJournal.recoverableSessions()).isNotEmpty ||
            await FlutterForegroundTask.getData(key: 'driveit_is_driving') ==
                true ||
            await FlutterForegroundTask.getData(
                  key: 'driveit_stop_requested',
                ) ==
                true;
      } finally {
        await legacyJournal.close();
      }
    } catch (_) {
      // An unreadable legacy journal is not evidence that it is idle.
      rethrow;
    }

    final dependencies = ControlledOwnershipDependencies(
      restoreAuth: () async => auth,
      descriptor: descriptor,
      databaseFactory: databaseFactory,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: support.path, owner: owner),
      producerRunning: () => FlutterForegroundTask.isRunningService,
      attachForeground: (bridge, value) async =>
          ForegroundService.attachForProduction(bridge, value),
      detachForeground: (bridge) =>
          ForegroundService.detachForProduction(bridge),
      worldRoadMatching: RoadMatchingService(
        provider: MapboxRoadMatchingProvider(),
      ),
      deviceGuestOwner: guestOwner,
      accountSyncAdapter: !accountSyncEnabled
          ? null
          : (lease) {
              // Use the SAME Auth project/client; never forward a Planet JWT
              // to the separate Phase 8 project or fabricate a backend user.
              if (!hasCloudAuth ||
                  SupabaseConfig.url !=
                      'https://viqngnjfgknpxtoapzcg.supabase.co' ||
                  lease.owner.kind != GpsOwnerKind.account) {
                throw StateError('Account sync Auth project not approved');
              }
              return SupabaseOwnerDriveSyncAdapter(
                client: Supabase.instance.client,
                ownerId: lease.owner.userId!,
                requireCurrent: lease.requireCurrent,
                deletionEnabled: accountDeletionEnabled,
              );
            },
      // Upload only new account drives explicitly marked at local finalization.
      // Existing/manual rows, Guest, and legacy archive data are not consent.
      automaticAccountSync: accountSyncEnabled,
      // Opening/resuming the normal app must not retry a real deletion.
      // History exposes the existing consent-preserving manual retry instead.
      automaticCloudDeletionRetry: false,
      cloudDeletionEnabled: accountDeletionEnabled,
      groupDriveService: accountGroupDriveEnabled && hasCloudAuth &&
              SupabaseConfig.url ==
                  'https://viqngnjfgknpxtoapzcg.supabase.co'
          ? SupabaseGroupDriveService(Supabase.instance.client)
          : null,
      transferSources: AccountDriveTransferSources(
        openGuest: () =>
            OwnerScopedLocalStore.open(root: support.path, owner: guestOwner),
        hasLegacy: () => LegacyHiveDriveTransferSource.hasRecords(),
        openLegacy: (context) => LegacyHiveDriveTransferSource.open(
          requireAccess: () {
            if (!context.isCurrent) throw StateError('archive_access_revoked');
          },
        ),
        authorizer: AndroidDeviceArchiveAuthorizer(),
      ),
    );

    return ProductionOwnerRuntimeDependencies(
      auth: auth,
      guestOwner: guestOwner,
      controlledBootstrap: dependencies,
      appSupportDirectory: support,
      legacyRecoveryRequired: legacyRecoveryRequired,
    );
  }
}
