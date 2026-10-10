/// Pure contract: storage/crash probes must not depend on Android/UI importers.
abstract interface class LegacySourceWriterFence {
  Future<void> pauseAndDrain();
  Future<void> resume();
}

abstract interface class RegisteredSourceWriterFence
    implements LegacySourceWriterFence {
  void requireRegistered();
}
