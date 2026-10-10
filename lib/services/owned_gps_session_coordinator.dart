import 'gps_session_ownership.dart';
import 'gps_session_store.dart';
import 'gps_session_transfer.dart';

/// A future scoped repository must provide a sink whose identity cannot change
/// after construction. The existing shared GpsHiveTransferSink is NOT eligible.
abstract interface class OwnedGpsTransferSink implements GpsTransferSink {
  String get targetStore;
}

/// Explicit opt-in only. No production caller or implicit auth subscription.
/// Capture auth once in start; transfer never reads current auth.
class OwnedGpsSessionCoordinator {
  OwnedGpsSessionCoordinator({
    required this.journal,
    required this.ownership,
    required this.journalId,
    required this.ownerAtStart,
  });
  final GpsSessionStore journal;
  final GpsOwnershipStore ownership;

  /// Stable local journal identity; must not change when accounts change.
  final String journalId;
  final GpsOwner Function() ownerAtStart;

  Future<GpsSession> start() async {
    final owner = ownerAtStart();
    final manifest = await ownership.prepare(journalId, owner);
    final session = await journal.create();
    // If this fails, retain journal and prepared reservation. Never guess a
    // binding on reboot. No native producer is started by this coordinator.
    await ownership.bind(manifest.reservationId, session.id);
    return session;
  }

  Future<Map<String, dynamic>> save(
    String sessionId,
    Map<String, dynamic> proposed,
    OwnedGpsTransferSink sink,
  ) async {
    final manifest = await ownership.get(journalId, sessionId);
    if (manifest == null) {
      throw StateError('Legacy ownership requires explicit future migration');
    }
    final op = await ownership.beginTransfer(manifest, sink.targetStore);
    final transfer = GpsSessionTransfer(journal, sink);
    final result = await transfer.save(sessionId, proposed);
    if (!await transfer.verify(sessionId)) {
      throw StateError('Transfer evidence not verified');
    }
    await ownership.verifyTransfer(op);
    return result;
  }
}
