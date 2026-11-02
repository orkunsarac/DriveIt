import 'dart:async';
import '../config/driveit_auth_callback.dart';
import 'local_owner_lifecycle.dart';

/// Receives untrusted Android links only after the owner runtime is attached.
/// Codes are retained only in memory to suppress duplicate delivery.
class OwnerAuthCallbackDelivery {
  OwnerAuthCallbackDelivery({required this.owner, required this.exchange});
  final LocalOwnerLifecycle owner;
  final Future<void> Function(Uri) exchange;
  final Set<String> _seen = {};
  Future<void> _tail = Future.value();
  bool _closed = false;

  Future<void> deliver(Uri uri) {
    if (_closed ||
        !DriveItAuthCallback.accepts(uri) ||
        uri.hasFragment ||
        uri.queryParametersAll['code']?.length != 1) {
      return Future.value();
    }
    final code = uri.queryParameters['code'];
    if (code == null ||
        code.isEmpty ||
        code.length > 2048 ||
        _seen.contains(code) ||
        _seen.length >= 64) {
      return Future.value();
    }
    _seen.add(code);
    final result = _tail.then((_) async {
      if (_closed) return;
      try {
        owner.lease.requireCurrent();
        await exchange(uri);
        owner.lease.requireCurrent();
      } catch (_) {
        // Invalid, expired, replayed and GPS-blocked callbacks fail closed.
        // Do not log the URI, code, SDK error or token.
      }
    });
    _tail = result;
    return result;
  }

  void close() {
    _closed = true;
    _seen.clear();
  }
}
