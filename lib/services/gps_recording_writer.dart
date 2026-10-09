import 'dart:async';
import 'canonical_telemetry_pipeline.dart';
import 'gps_session_store.dart';

/// One serialized producer, owned by the foreground task, not the UI isolate.
/// Retries the exact pending canonical point without re-running the filter.
class GpsRecordingWriter {
  GpsRecordingWriter(
    this.store,
    this.sessionId, {
    required this.onError,
    this.retryDelay = const Duration(seconds: 1),
    this.maximumPendingSamples = 128,
  });
  final GpsSessionStore store;
  final String sessionId;
  final void Function(bool failed) onError;
  final Duration retryDelay;
  final int maximumPendingSamples;
  int pendingSamples = 0;
  int rejectedSamples = 0;
  bool queueOverflowed = false;
  final int _producerEpoch = DateTime.now().microsecondsSinceEpoch;
  bool _lossReported = false;
  final pipeline = CanonicalTelemetryPipeline();
  int sequence = 0;
  DateTime? _committedTimestamp;
  Future<void> _tail = Future.value();
  bool _closing = false;
  bool hasPendingFailure = false;
  Future<void> restore() async {
    final events = await store.events(sessionId);
    queueOverflowed = events.any(
      (e) => (e['kind'] as String).startsWith('queue_overflow:'),
    );
    hasPendingFailure = queueOverflowed;
    final last = await store.last(sessionId);
    if (last != null) {
      sequence = last.sequence;
      _committedTimestamp = last.point.timestamp;
      if (last.checkpoint != null) {
        pipeline.restoreCheckpoint(last.checkpoint!);
      } else {
        final points = await store.read(sessionId);
        pipeline.restoreCommitted(points.map((p) => p.point).toList());
      }
    }
    await store.recordProducerEvent(
      sessionId,
      'producer_started',
      _producerEpoch,
      sequence,
    );
  }

  Future<void> add(RawTelemetryInput raw) {
    if (_closing) return Future.error(StateError('Writer is closing'));
    if (pendingSamples >= maximumPendingSamples) {
      rejectedSamples++;
      queueOverflowed = true;
      hasPendingFailure = true;
      onError(true);
      return Future.error(StateError('GPS pending queue capacity exceeded'));
    }
    pendingSamples++;
    _tail = _tail
        .then((_) async {
          // Restart/re-delivery: ignore timestamps already durably committed.
          if (raw.timestamp != null &&
              _committedTimestamp != null &&
              !raw.timestamp!.isAfter(_committedTimestamp!)) {
            return;
          }
          final point = pipeline.add(raw);
          if (point == null) return;
          final next = sequence + 1;
          while (true) {
            try {
              await store.append(
                sessionId,
                next,
                point,
                checkpoint: pipeline.checkpoint(),
              );
              sequence = next;
              _committedTimestamp = point.timestamp;
              if (queueOverflowed && !_lossReported) {
                await store.recordProducerEvent(
                  sessionId,
                  'queue_overflow',
                  _producerEpoch,
                  sequence,
                );
                _lossReported = true;
              }
              if (hasPendingFailure && !queueOverflowed) {
                hasPendingFailure = false;
                onError(false);
              }
              return;
            } catch (_) {
              hasPendingFailure = true;
              onError(true);
              if (_closing) rethrow;
              await Future<void>.delayed(retryDelay);
            }
          }
        })
        .whenComplete(() => pendingSamples--);
    return _tail;
  }

  Future<void> drain() async {
    await _tail;
    await store.recordProducerEvent(
      sessionId,
      'producer_drained',
      _producerEpoch,
      sequence,
    );
  }

  Future<void> close() async {
    _closing = true;
    await _tail;
    await store.recordProducerEvent(
      sessionId,
      'producer_drained',
      _producerEpoch,
      sequence,
    );
  }
}
