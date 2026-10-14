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
/// a fake group service, or an automatic cloud-sync worker.
abstract final class ProductionOwnerRuntimeFactory {
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
