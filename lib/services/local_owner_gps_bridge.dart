import 'gps_session_ownership.dart';
import 'gps_session_store.dart';
import 'local_owner_lifecycle.dart';
import 'owned_gps_session_coordinator.dart';

/// Explicit integration boundary, never a global fallback. The native callback
/// must independently call requireBinding before subscribing to GPS. This class
/// does not enable the existing production foreground callback.
class LocalOwnerGpsBridge {
  LocalOwnerGpsBridge({
    required this.runtime,
    required this.journal,
    required this.ownership,
    required this.journalId,
  });
  final LocalOwnerLifecycle runtime;
  final GpsSessionStore journal;
  final GpsOwnershipStore ownership;
  final String journalId;

  Future<GpsOwnershipManifest> requireBinding(String sessionId) async {
    if (!runtime.gate.enabled) throw StateError('Ownership disabled');
    final binding = await ownership.get(journalId, sessionId);
    if (binding == null ||
        binding.state != 'ready' ||
        binding.owner.kind == GpsOwnerKind.legacyUnassigned) {
      throw StateError('GPS ownership requires explicit recovery');
    }
    return binding;
  }

  Future<GpsOwner?> activeOwner() async {
    final session = await journal.active();
    if (session == null) return null;
    final binding = await ownership.get(journalId, session.id);
    return binding?.state == 'ready' ? binding!.owner : null;
  }

  Future<GpsSession> start({
    required Future<void> Function(GpsSession, GpsOwnershipManifest)
    startNative,
  }) => runtime.withOwnerOperation((lease) async {
    if (await journal.active() != null ||
        (await journal.recoverableSessions()).isNotEmpty) {
      throw StateError('Existing GPS session must be recovered');
    }
    final coordinator = OwnedGpsSessionCoordinator(
      journal: journal,
      ownership: ownership,
      journalId: journalId,
      ownerAtStart: () => lease.owner,
    );
    final session = await coordinator.start();
    // An external Auth event may have revoked the UI during the durable write.
    // Keep the bound journal, but do not start a producer from a revoked view.
    lease.requireCurrent();
    await startNative(session, await requireBinding(session.id));
    return session;
  });

  /// Destination comes from durable evidence. A mismatching context blocks,
  /// never substitutes another account. The source remains recoverable.
  Future<void> transfer(String sessionId, Map<String, dynamic> proposed) async {
    final binding = await requireBinding(sessionId);
    await runtime.lease.transferGps(
      journal: journal,
      ownership: ownership,
      binding: binding,
      proposed: proposed,
    );
    // Cleanup remains separate maintenance with dual receipts + Hive proof.
  }
}
