import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/services/account_deletion_controller.dart';
import 'package:driveit_project/features/account/screens/account_deletion_screen.dart';

class Receipts implements AccountDeletionReceiptStore {
  Map<String, dynamic>? value;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read(String? owner) async =>
      value != null && (owner == null || owner == value!['owner'])
      ? Map.of(value!)
      : null;
  @override
  Future<void> write(Map<String, dynamic> r) async {
    if (fail) throw StateError('secure store locked');
    value = Map.of(r);
  }

  @override
  Future<void> remove(String owner) async {
    if (value?['owner'] == owner) value = null;
  }
}

void main() {
  late Receipts store;
  late String? owner;
  late List<Map<String, dynamic>> sent;
  late List<String> signedOut;
  AccountDeletionReply reply(int status, String state) =>
      (status: status, body: {'state': state});
  AccountDeletionController make({
    Future<AccountDeletionReply> Function(Map<String, dynamic>)? send,
    Future<void> Function(Future<void> Function())? guard,
  }) => AccountDeletionController(
    store: store,
    endpoint: 'http://127.0.0.1:1234',
    currentOwner: () => owner,
    signOutLocal: (id) async {
      signedOut.add(id);
    },
    guard: guard ?? (action) => action(),
    send:
        send ??
        (body) async {
          sent.add(Map.of(body));
          if (body['action'] == 'request') return reply(202, 'pending');
          if (store.value?['submitted'] == true) return reply(200, 'completed');
          return (status: 403, body: <String, dynamic>{});
        },
  );
  setUp(() {
    store = Receipts();
    owner = 'owner-a';
    sent = [];
    signedOut = [];
  });
  test(
    'explicit consent required, secure store failure prevents network writes',
    () async {
      final c = make();
      await c.start(password: 'synthetic', confirmed: false);
      expect(sent, isEmpty);
      store.fail = true;
      await c.start(password: 'synthetic', confirmed: true);
      expect(sent, isEmpty);
      expect(c.state, AccountDeletionState.failed);
    },
  );
  test(
    'receipt is durable before request and password is not persisted; only verified completion logs out',
    () async {
      var accepted = false;
      final c = make(
        send: (body) async {
          sent.add(Map.of(body));
          expect(store.value, isNotNull);
          expect(store.value!.containsKey('password'), false);
          if (body['action'] == 'request') {
            accepted = true;
            return reply(202, 'pending');
          }
          return accepted ? reply(200, 'completed') : (status: 403, body: <String, dynamic>{});
        },
      );
      await c.start(password: 'synthetic', confirmed: true);
      expect(c.state, AccountDeletionState.completed);
      expect(signedOut, ['owner-a']);
      expect(store.value, isNull);
      expect(sent.where((x) => x.containsKey('password')).length, 1);
    },
  );
  test(
    'pending passes are bounded; receipt survives for process restart',
    () async {
      final c = make(
        send: (body) async {
          sent.add(Map.of(body));
          return body['action'] == 'request'
              ? reply(202, 'pending')
              : sent.length == 1
              ? (status: 403, body: <String, dynamic>{})
              : reply(202, 'pending');
        },
      );
      await c.start(password: 'synthetic', confirmed: true);
      expect(c.state, AccountDeletionState.pending);
      expect(sent.length, 6);
      expect(store.value, isNotNull);
      expect(signedOut, isEmpty);
      final restarted = make(send: (_) async => reply(200, 'completed'));
      owner = null;
      await restarted.resume();
      expect(restarted.state, AccountDeletionState.completed);
      expect(store.value, isNull);
    },
  );
  test(
    'blocked Planet and network failure never report completion or drop receipt',
    () async {
      final c = make(
        send: (body) async => body['action'] == 'request'
            ? reply(202, 'pending')
            : store.value == null
            ? (status: 403, body: <String, dynamic>{})
            : reply(202, 'blocked_planet'),
      );
      await c.start(password: 'synthetic', confirmed: true);
      expect(c.state, AccountDeletionState.blockedPlanet);
      expect(store.value, isNotNull);
      expect(signedOut, isEmpty);
      final retry = make(send: (_) async => throw StateError('offline'));
      await retry.resume();
      expect(retry.state, AccountDeletionState.failed);
      expect(store.value, isNotNull);
    },
  );
  test(
    'A response after switching to B cannot sign B out or erase A receipt',
    () async {
      final c = make(
        send: (body) async {
          owner = 'owner-b';
          return reply(200, 'completed');
        },
      );
      await c.start(password: 'synthetic', confirmed: true);
      expect(c.state, AccountDeletionState.failed);
      expect(signedOut, isEmpty);
      expect(store.value?['owner'], 'owner-a');
      final b = make(send: (_) async => throw StateError('must not send'));
      await b.resume();
      expect(b.state, AccountDeletionState.idle);
    },
  );
  test('active GPS guard fails before touching receipts or network', () async {
    final c = make(guard: (_) async => throw StateError('active GPS'));
    await c.start(password: 'synthetic', confirmed: true);
    expect(sent, isEmpty);
    expect(store.value, isNull);
  });
  test('single-flight prevents duplicate workers', () async {
    final barrier = Completer<AccountDeletionReply>();
    var calls = 0;
    store.value = {
      'owner': owner,
      'endpoint': 'http://127.0.0.1:1234',
      'requestId': 'synthetic',
      'receiptToken': 'synthetic',
    };
    final c = make(
      send: (_) async {
        calls++;
        return barrier.future;
      },
    );
    final one = c.resume(), two = c.resume();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    barrier.complete(reply(202, 'busy'));
    await Future.wait([one, two]);
    expect(c.state, AccountDeletionState.busy);
  });
  test('receipt from another environment cannot be sent', () async {
    store.value = {
      'owner': owner,
      'endpoint': 'https://wrong.invalid',
      'requestId': 'synthetic',
      'receiptToken': 'synthetic',
    };
    final c = make();
    await c.resume();
    expect(sent, isEmpty);
    expect(c.state, AccountDeletionState.failed);
  });
  testWidgets(
    'destructive button requires consent and pending is not successful deletion',
    (tester) async {
      final c = make();
      await tester.pumpWidget(
        MaterialApp(home: AccountDeletionScreen(controller: c)),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('account_deletion_confirm')),
      );
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('Cihazdaki sürüş kayıtların silinmez'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Hesabın ve silinebilir sunucu verilerin silindi'),
        findsNothing,
      );
    },
  );
}
