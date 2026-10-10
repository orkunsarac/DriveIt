import 'legacy_account_import.dart';
import 'legacy_import_inventory.dart';
import 'legacy_owner_consent.dart';
import 'local_owner_lifecycle.dart';
import 'legacy_source_writer_fence.dart';
export 'legacy_source_writer_fence.dart';

class LocalOwnerImportBridge {
  LocalOwnerImportBridge({
    required this.runtime,
    required this.importer,
    required this.writerFence,
  });
  final LocalOwnerLifecycle runtime;
  final LegacyAccountImporter importer;
  final LegacySourceWriterFence writerFence;

  Future<VerifiedLegacyImport> approve({
    required LegacyImportSource source,
    required LegacyOwnerConsent consent,
  }) => runtime.withOwnerOperation((lease) async {
    consent.verify(consent.fingerprint);
    if (!identical(lease, consent.lease) ||
        !importer.gate.enabled ||
        await runtime.driveInProgress()) {
      throw StateError('Legacy import quiescence unavailable');
    }
    // No source read or ledger reservation until the writer acknowledges drain.
    // pauseAndDrain must be transactional itself: failed pause must release it.
    final registered = writerFence;
    if (registered is RegisteredSourceWriterFence) {
      registered.requireRegistered();
    }
    await writerFence.pauseAndDrain();
    try {
      consent.verify(consent.fingerprint);
      return await importer.import(source: source, consent: consent);
    } finally {
      await writerFence.resume();
    }
  });
}
