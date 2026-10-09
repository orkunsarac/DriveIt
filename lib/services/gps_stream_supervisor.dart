import 'dart:async';

enum GpsFlowState { recording, waiting, permissionBlocked, stopping }

/// Owns exactly one subscription. Does not start/restart an Android service.
/// All transitions are serialized; late callbacks from cancelled streams die.
class GpsStreamSupervisor<T> {
  GpsStreamSupervisor({
    required this.open,
    required this.available,
    required this.onSample,
    required this.onState,
    this.isFresh,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final Stream<T> Function() open;
  final Future<bool> Function() available;
  final void Function(T) onSample;
  final void Function(GpsFlowState) onState;
  final bool Function(T)? isFresh;
  final DateTime Function() now;
  StreamSubscription<T>? _subscription;
  Future<void> _tail = Future.value();
  DateTime? lastReceivedAt;
  DateTime? _openedAt;
  DateTime? _retryAt;
  int _attempts = 0, _epoch = 0;
  bool _closed = false, _broken = false;
  bool _polling = false;
  GpsFlowState state = GpsFlowState.waiting;
  static const staleAfter = Duration(seconds: 15);
  static const resubscribeAfter = Duration(seconds: 30);
  Duration get age => now().difference(lastReceivedAt ?? _openedAt ?? now());
  void _state(GpsFlowState value) {
    if (state != value) {
      state = value;
      onState(value);
    }
  }

  Future<void> poll() {
    if (_polling || _closed) return _tail;
    _polling = true;
    _tail = _tail
        .then((_) async {
          if (_closed) return;
          bool usable;
          try {
            usable = await available().timeout(const Duration(seconds: 5));
          } catch (_) {
            usable = false;
          }
          if (_closed) return;
          if (!usable) {
            await _cancel();
            _retryAt = null;
            _state(GpsFlowState.permissionBlocked);
            return;
          }
          if (_subscription != null && age > staleAfter) {
            _state(GpsFlowState.waiting);
          }
          if (_subscription != null && !_broken && age <= resubscribeAfter) {
            return;
          }
          if (_retryAt != null && now().isBefore(_retryAt!)) return;
          await _cancel();
          if (_closed) return;
          _broken = false;
          final epoch = ++_epoch;
          _openedAt = now();
          _scheduleRetry();
          try {
            _subscription = open().listen(
              (sample) {
                if (_closed ||
                    epoch != _epoch ||
                    isFresh?.call(sample) == false) {
                  return;
                }
                _broken = false;
                lastReceivedAt = now();
                _attempts = 0;
                _retryAt = null;
                _state(GpsFlowState.recording);
                onSample(sample);
              },
              onError: (Object _) => _ended(epoch),
              onDone: () => _ended(epoch),
            );
          } catch (_) {
            _ended(epoch);
          }
        })
        .catchError((Object _) {
          if (!_closed) {
            _broken = true;
            _state(GpsFlowState.waiting);
            _scheduleRetry();
          }
        })
        .whenComplete(() => _polling = false);
    return _tail;
  }

  void _ended(int epoch) {
    if (_closed || epoch != _epoch) return;
    _broken = true;
    _state(GpsFlowState.waiting);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    // Six rapid attempts, then at most once/minute until conditions recover.
    const seconds = [1, 2, 4, 8, 16, 30, 60];
    _retryAt = now().add(Duration(seconds: seconds[_attempts.clamp(0, 6)]));
    _attempts++;
  }

  Future<void> _cancel() async {
    ++_epoch;
    final old = _subscription;
    await old?.cancel();
    _subscription = null;
  }

  Future<void> close() async {
    _closed = true; // Synchronous producer barrier before any await.
    _state(GpsFlowState.stopping);
    await _tail;
    await _cancel();
  }
}
