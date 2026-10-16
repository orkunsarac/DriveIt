import 'package:sqflite_common/sqlite_api.dart';
import '../config/local_ownership_gate.dart';
import 'gps_session_ownership.dart';
import 'local_owner_gps_bridge.dart';
import 'local_owner_lifecycle.dart';
import 'owned_foreground_bootstrap.dart';
import 'owner_scoped_local_store.dart';
import 'supabase_account_service.dart';
import 'local_source_writer_fence.dart';
import 'owner_drive_sync_client.dart';
import '../features/my_world/services/road_matching_service.dart';
import '../features/group_drive/group_drive_service.dart';
import 'account_drive_transfer.dart';

/// Dependencies must be supplied explicitly by the synthetic harness. There is
/// no release define, shared-box fallback, legacy migration or import here.
class ControlledOwnershipDependencies {
  ControlledOwnershipDependencies({
    required this.restoreAuth,
    required this.descriptor,
    required this.databaseFactory,
    required this.openStore,
    required this.producerRunning,
    required this.attachForeground,
    required this.detachForeground,
    this.writerFence,
    this.worldRoadMatching,
    this.fakeSyncRemote,
    this.groupDriveServiceForTesting,
    this.groupDriveService,
    this.deviceGuestOwner,
    this.accountSyncAdapter,
    this.automaticAccountSync = true,
    this.automaticCloudDeletionRetry = true,
    this.cloudDeletionEnabled = false,
    this.transferSources,
  });
  final Future<LocalOwnerAuth> Function() restoreAuth;
  final OwnedForegroundBootstrap descriptor;
  final DatabaseFactory databaseFactory;
  final Future<OwnerScopedLocalStore> Function(GpsOwner) openStore;
  final Future<bool> Function() producerRunning;
  final Future<void> Function(LocalOwnerGpsBridge, OwnedForegroundBootstrap)
  attachForeground;
  final Future<void> Function(LocalOwnerGpsBridge) detachForeground;
  final LocalSourceWriterFence? writerFence;
  final RoadMatchingService? worldRoadMatching;

  /// Synthetic acceptance only; never configured by production composition.
  final OwnerSyncRemoteAdapter? fakeSyncRemote;

  /// Opt-in test composition only. Android activation is independently
  /// guarded by the isolated package and native manifest in startDriveIt.
  final FakeGroupDriveService? groupDriveServiceForTesting;
  /// Real backend adapter is supplied only by an explicit post-acceptance build.
  final GroupDriveService? groupDriveService;
  final GpsOwner? deviceGuestOwner;
  final OwnerSyncAccountRemoteAdapter Function(LocalOwnerLease)?
  accountSyncAdapter;
  final bool automaticAccountSync;
  final bool automaticCloudDeletionRetry;
  final bool cloudDeletionEnabled;
  final AccountDriveTransferSources? transferSources;
}

class ControlledOwnershipRuntime {
  ControlledOwnershipRuntime(
    this.owner,
    this.gps,
    this.writerFence,
    this.dependencies,
  );
  final LocalOwnerLifecycle owner;
  final LocalOwnerGpsBridge gps;
  final LocalSourceWriterFence? writerFence;
  final ControlledOwnershipDependencies dependencies;

  /// Explicit background entry point; the current lease pins the owner until
  /// the worker finishes. Missing matching dependency fails closed.
  Future<void> processWorldJobs() => owner.lease.drainWorldJobs();
  // Native producer must be detached/confirmed absent before closing handles.
  Future<void> closeAfterProducerDetached() async {
    if (await dependencies.producerRunning()) {
      throw StateError('Foreground producer still running');
    }
    await dependencies.detachForeground(gps);
    await owner.close();
    if (LocalOwnershipGate.localProductionActivation &&
        !LocalOwnershipGate.syntheticRuntimeAvailable) {
      SupabaseAccountService.instance.detachOwnerForProduction(owner);
    } else {
      SupabaseAccountService.instance.detachOwnerForTesting(owner);
    }
    await gps.ownership.close();
    await gps.journal.close();
    if (writerFence != null) {
      await SourceWriterBoundary.detachForTesting(writerFence!);
    }
  }
}

abstract final class LocalOwnershipBootstrap {
  static Future<ControlledOwnershipRuntime?> run({
    required LocalOwnershipGate gate,
    required Future<void> Function() legacyBootstrap,
    ControlledOwnershipDependencies? controlled,
  }) async {
    if (!gate.enabled) {
      await legacyBootstrap();
      return null;
    }
    if (controlled == null) {
      throw StateError('Controlled owner dependencies missing');
    }
    // Restore identity BEFORE personal stores or native producers are opened.
    final auth = await controlled.restoreAuth();
    LocalOwnerLifecycle.ownerFor(auth.userId); // UUID validation, fail closed.
    final journal = await controlled.descriptor.openJournal(
      controlled.databaseFactory,
    );
    GpsOwnershipStore? sidecar;
    LocalOwnerLifecycle? runtime;
    var authAttached = false;
    var writersAttached = false;
    try {
      if (controlled.writerFence != null) {
        SourceWriterBoundary.installForTesting(controlled.writerFence!);
        writersAttached = true;
      }
      sidecar = await controlled.descriptor.openOwnership(
        controlled.databaseFactory,
      );
      final ownership = sidecar;
      Future<bool> busy() async =>
          await controlled.producerRunning() ||
          await journal.active() != null ||
          (await journal.recoverableSessions()).isNotEmpty;
      runtime = LocalOwnerLifecycle(
        gate: gate,
        auth: auth,
        deviceGuestOwner: controlled.deviceGuestOwner,
        accountSyncAdapter: controlled.accountSyncAdapter,
        automaticAccountSync: controlled.automaticAccountSync,
        automaticCloudDeletionRetry: controlled.automaticCloudDeletionRetry,
        cloudDeletionEnabled: controlled.cloudDeletionEnabled,
        transferSources: controlled.transferSources,
        openStore: controlled.openStore,
        driveInProgress: busy,
        worldRoadMatching: controlled.worldRoadMatching,
        syncRemoteForTesting: controlled.fakeSyncRemote,
        activeSessionOwner: () async {
          final session = await journal.active();
          if (session == null) return null;
          final binding = await ownership.get(
            controlled.descriptor.journalId,
            session.id,
          );
          return binding?.state == 'ready' ? binding!.owner : null;
        },
      );
      await runtime.start();
      if (runtime.state != LocalOwnerState.ready) {
        throw StateError('Owner recovery not ready');
      }
      final bridge = LocalOwnerGpsBridge(
        runtime: runtime,
        journal: journal,
        ownership: ownership,
        journalId: controlled.descriptor.journalId,
      );
      if (LocalOwnershipGate.localProductionActivation &&
          !LocalOwnershipGate.syntheticRuntimeAvailable) {
        SupabaseAccountService.instance.attachOwnerForProduction(runtime);
      } else {
        SupabaseAccountService.instance.attachOwnerForTesting(runtime);
      }
      authAttached = true;
      await controlled.attachForeground(bridge, controlled.descriptor);
      return ControlledOwnershipRuntime(
        runtime,
        bridge,
        controlled.writerFence,
        controlled,
      );
    } catch (_) {
      if (authAttached) {
        if (LocalOwnershipGate.localProductionActivation &&
            !LocalOwnershipGate.syntheticRuntimeAvailable) {
          SupabaseAccountService.instance.detachOwnerForProduction(runtime!);
        } else {
          SupabaseAccountService.instance.detachOwnerForTesting(runtime!);
        }
      }
      await runtime?.close();
      await sidecar?.close();
      await journal.close();
      if (writersAttached) {
        await SourceWriterBoundary.detachForTesting(controlled.writerFence!);
      }
      rethrow; // Durable journals/manifests are never removed on failure.
    }
  }
}
