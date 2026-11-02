import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum AccountDeletionState {
  idle,
  pending,
  blockedPlanet,
  completed,
  busy,
  failed,
  receiptUnavailable,
}

abstract interface class AccountDeletionReceiptStore {
  Future<Map<String, dynamic>?> read(String? owner);
  Future<void> write(Map<String, dynamic> receipt);
  Future<void> remove(String owner);
}

typedef AccountDeletionReply = ({int status, Map<String, dynamic> body});

/// No History/Hive/GPS deletion dependency. Receipts must be encrypted by the adapter.
class AccountDeletionController extends ChangeNotifier {
  AccountDeletionController({
    required this.store,
    required this.send,
    required this.currentOwner,
    required this.guard,
    this.resumeGuard,
    required this.signOutLocal,
    required this.endpoint,
  });
  final AccountDeletionReceiptStore store;
  final Future<AccountDeletionReply> Function(Map<String, dynamic>) send;
  final String? Function() currentOwner;
  final Future<void> Function(Future<void> Function()) guard;

  /// Receipt-only recovery can outlive the Auth session that created it.
  /// Production Play uses an unauthenticated receipt transport for `run`;
  /// callers must still bind the receipt to its endpoint and owner.
  final Future<void> Function(Future<void> Function())? resumeGuard;
  final Future<void> Function(String owner) signOutLocal;
  final String endpoint;
  AccountDeletionState state = AccountDeletionState.idle;
  Future<void>? _flight;
  bool get busy => _flight != null;
  String? _owner;
  void _set(AccountDeletionState next) {
    state = next;
    notifyListeners();
  }

  void _assertOwner(String owner) {
    if (currentOwner() != null && currentOwner() != owner) {
      throw StateError('Account changed');
    }
  }

  Future<void> start({
    required String password,
    required bool confirmed,
  }) => _single(() async {
    if (!confirmed || password.isEmpty) {
      _set(AccountDeletionState.failed);
      return;
    }
    final owner = currentOwner();
    if (owner == null) {
      _set(AccountDeletionState.failed);
      return;
    }
    var receipt = await store.read(owner);
    if (receipt == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      final token = List.generate(
        32,
        (_) => random.nextInt(256),
      ).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      receipt = {
        'owner': owner,
        'endpoint': endpoint,
        'requestId':
            '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
        'receiptToken': token,
      };
      await store.write(
        receipt,
      ); // Must succeed before any destructive request can be sent.
    }
    _validate(receipt, owner);
    _assertOwner(owner);
    // A previous request may already have committed and revoked Auth. Resume without re-requesting it.
    final previous = await send({...receipt, 'action': 'run'});
    if (previous.status != 403) {
      await _drain(receipt, previous);
      return;
    }
    _assertOwner(owner);
    final requested = await send({
      ...receipt,
      'action': 'request',
      'expectedOwner': owner,
      'confirm': 'DELETE_MY_ACCOUNT',
      'password': password,
    });
    if (requested.status != 202) {
      _set(AccountDeletionState.failed);
      return;
    }
    await _drain(receipt);
  }, actionGuard: guard);
  Future<void> resume() => _single(() async {
    final receipt = await store.read(currentOwner());
    if (receipt == null) {
      _set(AccountDeletionState.idle);
      return;
    }
    final owner = receipt['owner'] as String;
    _validate(receipt, owner);
    _assertOwner(owner);
    await _drain(receipt);
  }, actionGuard: resumeGuard ?? guard);
  void _validate(Map<String, dynamic> r, String owner) {
    if (r['owner'] != owner ||
        r['endpoint'] != endpoint ||
        r['receiptToken'] is! String ||
        r['requestId'] is! String) {
      throw StateError('Receipt mismatch');
    }
    _owner = owner;
  }

  Future<void> _drain(
    Map<String, dynamic> receipt, [
    AccountDeletionReply? initial,
  ]) async {
    for (var page = 0; page < 4; page++) {
      _assertOwner(_owner!);
      final response = page == 0 && initial != null
          ? initial
          : await send({...receipt, 'action': 'run'});
      _assertOwner(_owner!);
      if (response.status == 403) {
        _set(AccountDeletionState.receiptUnavailable);
        return;
      }
      if (response.status != 200 && response.status != 202) {
        _set(AccountDeletionState.failed);
        return;
      }
      switch (response.body['state']) {
        case 'completed':
          await signOutLocal(_owner!);
          await store.remove(_owner!);
          _set(AccountDeletionState.completed);
          return;
        case 'blocked_planet':
          _set(AccountDeletionState.blockedPlanet);
          return;
        case 'busy':
          _set(AccountDeletionState.busy);
          return;
        case 'pending':
        case 'purged':
          _set(AccountDeletionState.pending);
        default:
          _set(AccountDeletionState.failed);
          return;
      }
    }
  }

  Future<void> _single(
    Future<void> Function() action, {
    required Future<void> Function(Future<void> Function()) actionGuard,
  }) {
    if (_flight != null) return _flight!;
    final flight = Future<void>(() async {
      try {
        await actionGuard(action);
      } catch (_) {
        _set(AccountDeletionState.failed);
      }
    });
    _flight = flight;
    notifyListeners();
    return flight.whenComplete(() {
      _flight = null;
      notifyListeners();
    });
  }

  static String receiptKey(String endpoint, String owner) =>
      sha256.convert(utf8.encode('$endpoint|$owner')).toString();
}
