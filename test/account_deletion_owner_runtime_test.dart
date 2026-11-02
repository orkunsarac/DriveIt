import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/account_deletion_controller.dart';
import 'package:driveit_project/services/account_deletion_runtime.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uidA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _uidB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _project = 'https://arwnbogcswisfesayosy.supabase.co';
const _key = 'sb_publishable_synthetic';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'request uses the approved owner credential; receipt run has no JWT',
    () async {
      final fixture = await _DeletionFixture.create();
      try {
        fixture.runReplies.addAll([
          (status: 403, body: {'error': 'receipt_unavailable'}),
          (status: 200, body: {'state': 'completed'}),
        ]);
        await fixture.controller.start(
          password: 'synthetic-password',
          confirmed: true,
        );

        expect(fixture.controller.state, AccountDeletionState.completed);
        expect(fixture.receipts.value, isNull);
        expect(fixture.signedOut, [_uidA]);
        expect(fixture.requestBodies.single['expectedOwner'], _uidA);
        expect(fixture.requestBodies.single['password'], 'synthetic-password');
        expect(fixture.requestAuth, ['Bearer token-a']);
        expect(fixture.runAuth, [null, null]);
        expect(
          fixture.runBodies.every(
            (body) => body.keys.toSet().containsAll({
              'action',
              'requestId',
              'receiptToken',
            }),
          ),
          isTrue,
        );
        expect(
          fixture.runBodies.every((body) => !body.containsKey('owner')),
          isTrue,
        );
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'failed password reauthentication retains receipt and does not run worker',
    () async {
      final fixture = await _DeletionFixture.create();
      try {
        fixture.requestStatus = 403;
        fixture.runReplies.add((
          status: 403,
          body: {'error': 'receipt_unavailable'},
        ));
        await fixture.controller.start(password: 'wrong', confirmed: true);
        expect(fixture.controller.state, AccountDeletionState.failed);
        expect(fixture.requestBodies, hasLength(1));
        expect(fixture.runBodies, hasLength(1));
        expect(fixture.receipts.value, isNotNull);
        expect(fixture.signedOut, isEmpty);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'active or recoverable GPS blocks destructive start before receipt/network',
    () async {
      final fixture = await _DeletionFixture.create(gpsBusy: true);
      try {
        await fixture.controller.start(
          password: 'synthetic-password',
          confirmed: true,
        );
        expect(fixture.controller.state, AccountDeletionState.failed);
        expect(fixture.receipts.value, isNull);
        expect(fixture.requestBodies, isEmpty);
        expect(fixture.runBodies, isEmpty);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'A to B during request cannot continue under B or complete A locally',
    () async {
      final fixture = await _DeletionFixture.create();
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.holdRequest = true;
      fixture.requestEntered = entered;
      fixture.releaseRequest = release;
      fixture.runReplies.add((
        status: 403,
        body: {'error': 'receipt_unavailable'},
      ));
      try {
        final pending = fixture.controller.start(
          password: 'synthetic-password',
          confirmed: true,
        );
        await entered.future;
        fixture.authUid = _uidB;
        fixture.authToken = 'token-b';
        await fixture.sdk.auth.signInWithPassword(
          email: 'b@example.invalid',
          password: 'synthetic-password',
        );
        await fixture.runtime.settled;
        expect(fixture.lease.isCurrent, isFalse);
        release.complete();
        await pending;
        expect(fixture.requestAuth, ['Bearer token-a']);
        expect(fixture.controller.state, AccountDeletionState.failed);
        expect(fixture.runBodies, hasLength(1));
        expect(fixture.signedOut, isEmpty);
        expect(fixture.receipts.value?['owner'], _uidA);
      } finally {
        if (!release.isCompleted) release.complete();
        await fixture.close();
      }
    },
  );

  test(
    'receipt resume after logout is unauthenticated and retains server contract',
    () async {
      final fixture = await _DeletionFixture.create();
      try {
        fixture.receipts.value = _receipt(_uidA);
        fixture.authUid = null;
        await fixture.sdk.auth.signOut(scope: SignOutScope.local);
        await fixture.runtime.settled;
        fixture.runReplies.add((status: 200, body: {'state': 'completed'}));

        await fixture.controller.resume();

        expect(fixture.controller.state, AccountDeletionState.completed);
        expect(fixture.runAuth, [null]);
        expect(fixture.requestBodies, isEmpty);
        expect(fixture.receipts.value, isNull);
        expect(fixture.signedOut, isEmpty);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'a recreated controller resumes a pending job from the same owner receipt',
    () async {
      final fixture = await _DeletionFixture.create();
      try {
        fixture.receipts.value = _receipt(_uidA);
        fixture.runReplies.addAll([
          for (var i = 0; i < 4; i++) (status: 202, body: {'state': 'pending'}),
          (status: 200, body: {'state': 'completed'}),
        ]);
        final firstProcessController = fixture.makeController();
        await firstProcessController.resume();
        expect(firstProcessController.state, AccountDeletionState.pending);
        expect(fixture.receipts.value, isNotNull);

        final restartedController = fixture.makeController();
        await restartedController.resume();
        expect(restartedController.state, AccountDeletionState.completed);
        expect(fixture.runAuth, hasLength(5));
        expect(fixture.runAuth, everyElement(isNull));
        expect(fixture.receipts.value, isNull);
        expect(fixture.signedOut, [_uidA]);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'a different signed-in account cannot resume another owners receipt',
    () async {
      final fixture = await _DeletionFixture.create();
      try {
        fixture.receipts.value = _receipt(_uidA);
        fixture.authUid = _uidB;
        fixture.authToken = 'token-b';
        await fixture.sdk.auth.signInWithPassword(
          email: 'b@example.invalid',
          password: 'synthetic-password',
        );
        await fixture.runtime.settled;
        await fixture.controller.resume();
        expect(fixture.controller.state, AccountDeletionState.idle);
        expect(fixture.runBodies, isEmpty);
        expect(fixture.receipts.value?['owner'], _uidA);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'blocked Planet, busy and server failures never report completion or erase receipt',
    () async {
      for (final terminal in ['blocked_planet', 'busy', 'pending']) {
        final fixture = await _DeletionFixture.create();
        try {
          fixture.receipts.value = _receipt(_uidA);
          fixture.runReplies.addAll(
            List<AccountDeletionReply>.filled(terminal == 'pending' ? 4 : 1, (
              status: 202,
              body: {'state': terminal},
            )),
          );
          await fixture.controller.resume();
          expect(fixture.controller.state, switch (terminal) {
            'blocked_planet' => AccountDeletionState.blockedPlanet,
            'busy' => AccountDeletionState.busy,
            _ => AccountDeletionState.pending,
          });
          expect(fixture.receipts.value, isNotNull);
          expect(fixture.signedOut, isEmpty);
        } finally {
          await fixture.close();
        }
      }

      final failed = await _DeletionFixture.create();
      try {
        failed.receipts.value = _receipt(_uidA);
        failed.runReplies.add((
          status: 503,
          body: {'error': 'deletion_not_completed'},
        ));
        await failed.controller.resume();
        expect(failed.controller.state, AccountDeletionState.failed);
        expect(failed.receipts.value, isNotNull);
        expect(failed.signedOut, isEmpty);
      } finally {
        await failed.close();
      }
    },
  );

  test('wrong PROD project and malformed receipt fail closed', () async {
    final fixture = await _DeletionFixture.create();
    try {
      final wrong = OwnerScopedAccountDeletionTransport(
        endpoint: 'https://viqngnjfgknpxtoapzcg.supabase.co',
        publicKey: _key,
        applicationId: 'com.osaracx.driveit',
        gatewayForOwner: (_) => fixture.gateway,
        receiptClient: fixture.receiptClient,
      );
      await expectLater(
        wrong.send({..._receipt(_uidA), 'action': 'run'}),
        throwsStateError,
      );
      await expectLater(
        fixture.transport.send({
          'action': 'run',
          'requestId': 'not-a-request',
          'receiptToken': 'short',
        }),
        throwsStateError,
      );
      await expectLater(
        fixture.transport.send({
          ..._receipt(_uidA),
          'action': 'request',
          'expectedOwner': _uidB,
          'confirm': 'DELETE_MY_ACCOUNT',
          'password': 'synthetic-password',
        }),
        throwsStateError,
      );
      expect(fixture.runBodies, isEmpty);
      expect(fixture.requestBodies, isEmpty);
    } finally {
      await fixture.close();
    }
  });
}

Map<String, dynamic> _receipt(String owner) => {
  'owner': owner,
  'endpoint': _project,
  'requestId': '11111111-1111-4111-8111-111111111111',
  'receiptToken': 'a' * 64,
};

class _ReceiptStore implements AccountDeletionReceiptStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read(String? owner) async =>
      value != null && (owner == null || value!['owner'] == owner)
      ? Map<String, dynamic>.from(value!)
      : null;
  @override
  Future<void> write(Map<String, dynamic> receipt) async =>
      value = Map<String, dynamic>.from(receipt);
  @override
  Future<void> remove(String owner) async {
    if (value?['owner'] == owner) value = null;
  }
}

class _DeletionFixture {
  _DeletionFixture._(
    this.root,
    this.sdk,
    this.runtime,
    this.lease,
    this.mock,
    this._gpsBusy,
  );
  final Directory root;
  final SupabaseClient sdk;
  final LocalOwnerLifecycle runtime;
  final LocalOwnerLease lease;
  final _DeletionHttp mock;
  final _ReceiptStore receipts = _ReceiptStore();
  final _GpsBusy _gpsBusy;
  bool get gpsBusy => _gpsBusy.value;
  set gpsBusy(bool value) => _gpsBusy.value = value;
  bool get holdRequest => mock.holdRequest;
  set holdRequest(bool value) => mock.holdRequest = value;
  Completer<void>? get requestEntered => mock.requestEntered;
  set requestEntered(Completer<void> value) => mock.requestEntered = value;
  Completer<void>? get releaseRequest => mock.releaseRequest;
  set releaseRequest(Completer<void> value) => mock.releaseRequest = value;
  List<AccountDeletionReply> get runReplies => mock.runReplies;
  List<Map<String, dynamic>> get requestBodies => mock.requestBodies;
  List<Map<String, dynamic>> get runBodies => mock.runBodies;
  List<String?> get requestAuth => mock.requestAuth;
  List<String?> get runAuth => mock.runAuth;
  List<String> signedOut = [];
  int get requestStatus => mock.requestStatus;
  set requestStatus(int value) => mock.requestStatus = value;
  String? get authUid => mock.authUid;
  set authUid(String? value) => mock.authUid = value;
  String get authToken => mock.authToken;
  set authToken(String value) => mock.authToken = value;
  http.Client get receiptClient => mock.client;

  OwnerProfileGateway get gateway => OwnerProfileGateway(
    authClient: sdk,
    url: _project,
    publicKey: _key,
    applicationId: 'com.osaracx.driveit',
    approvedOwner: () => lease.owner.userId,
    approvedEpoch: () => lease.epoch,
    isLeaseCurrent: (epoch) => epoch == lease.epoch && lease.isCurrent,
    transport: mock.client,
  );

  OwnerScopedAccountDeletionTransport get transport =>
      OwnerScopedAccountDeletionTransport(
        endpoint: _project,
        publicKey: _key,
        applicationId: 'com.osaracx.driveit',
        gatewayForOwner: (owner) {
          lease.requireCurrent();
          if (lease.owner.userId != owner ||
              sdk.auth.currentUser?.id != owner) {
            throw StateError('owner mismatch');
          }
          return gateway;
        },
        receiptClient: mock.client,
      );

  late final AccountDeletionController controller = makeController();

  AccountDeletionController makeController() => AccountDeletionController(
    endpoint: _project,
    store: receipts,
    currentOwner: () => sdk.auth.currentUser?.id,
    guard: (action) async {
      final captured = runtime.lease;
      captured.requireCurrent();
      if (captured.owner.kind.name != 'account' ||
          sdk.auth.currentUser?.id != captured.owner.userId) {
        throw StateError('owner unavailable');
      }
      await runtime.authorizeIdentityChange(() async {
        captured.requireCurrent();
        if (sdk.auth.currentUser?.id != captured.owner.userId) {
          throw StateError('owner changed');
        }
        await action();
      });
    },
    resumeGuard: (action) => action(),
    send: transport.send,
    signOutLocal: (owner) async {
      if (sdk.auth.currentUser?.id == owner) {
        signedOut.add(owner);
        await sdk.auth.signOut(scope: SignOutScope.local);
      }
    },
  );

  static Future<_DeletionFixture> create({bool gpsBusy = false}) async {
    final root = await Directory.systemTemp.createTemp(
      'driveit_deletion_owner_',
    );
    final mock = _DeletionHttp();
    final busy = _GpsBusy();
    final sdk = SupabaseClient(_project, _key, httpClient: mock.client);
    await sdk.auth.signInWithPassword(
      email: 'a@example.invalid',
      password: 'synthetic-password',
    );
    final runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => busy.value,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    await runtime.start();
    final fixture = _DeletionFixture._(
      root,
      sdk,
      runtime,
      runtime.lease,
      mock,
      busy,
    );
    fixture.gpsBusy = gpsBusy;
    return fixture;
  }

  Future<void> close() async {
    await runtime.close();
    await sdk.dispose();
    mock.client.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

class _GpsBusy {
  bool value = false;
}

class _DeletionHttp {
  String? authUid = _uidA;
  String authToken = 'token-a';
  bool holdRequest = false;
  Completer<void>? requestEntered;
  Completer<void>? releaseRequest;
  int requestStatus = 202;
  final runReplies = <AccountDeletionReply>[];
  final requestBodies = <Map<String, dynamic>>[];
  final runBodies = <Map<String, dynamic>>[];
  final requestAuth = <String?>[];
  final runAuth = <String?>[];

  late final http.Client client = MockClient((request) async {
    if (request.url.path == '/auth/v1/token') {
      return http.Response(
        jsonEncode({
          'access_token': authToken,
          'refresh_token': 'synthetic-refresh',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': {
            'id': authUid,
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/functions/v1/delete-account') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['action'] == 'request') {
        requestBodies.add(body);
        requestAuth.add(request.headers['authorization']);
        if (holdRequest) {
          requestEntered?.complete();
          await releaseRequest?.future;
        }
        return http.Response(
          jsonEncode(
            requestStatus == 202
                ? {'state': 'pending'}
                : {'error': 'reauthentication_failed'},
          ),
          requestStatus,
          headers: {'content-type': 'application/json'},
        );
      }
      if (body['action'] == 'run') {
        runBodies.add(body);
        runAuth.add(request.headers['authorization']);
        if (runReplies.isEmpty) {
          return http.Response(
            jsonEncode({'error': 'receipt_unavailable'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        final reply = runReplies.removeAt(0);
        return http.Response(
          jsonEncode(reply.body),
          reply.status,
          headers: {'content-type': 'application/json'},
        );
      }
    }
    return http.Response(
      '{}',
      404,
      headers: {'content-type': 'application/json'},
    );
  });
}
