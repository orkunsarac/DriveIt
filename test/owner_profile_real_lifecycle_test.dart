import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/local_owner_gps_bridge.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const url = 'https://arwnbogcswisfesayosy.supabase.co';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late SupabaseClient sdk;
  late LocalOwnerLifecycle owner;
  late GpsSessionStore journal;
  late GpsOwnershipStore sidecar;
  late LocalOwnerGpsBridge gps;
  late SupabaseAccountService account;
  var nextUser = a;
  var token = 'synthetic-a';
  var blockB = false;
  var failB = false;
  var blockProfile = false;
  late Completer<void> openEntered;
  late Completer<void> openRelease;
  late Completer<void> profileEntered;
  late Completer<void> profileRelease;
  late List<({String? auth, String path, String method})> requests;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_real_owner_sdk_');
    nextUser = a;
    failB = false;
    token = 'synthetic-a';
    blockB = false;
    blockProfile = false;
    openEntered = Completer<void>();
    openRelease = Completer<void>();
    profileEntered = Completer<void>();
    profileRelease = Completer<void>();
    requests = [];
    sdk = SupabaseClient(
      url,
      'sb_publishable_synthetic',
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/logout')) return http.Response('{}', 200);
        return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'synthetic-refresh',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': nextUser,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    journal = await GpsSessionStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/gps.db',
    );
    sidecar = await GpsOwnershipStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${root.path}/ownership.db',
    );
    owner = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (identity) async {
        if (failB && identity.userId == b) {
          throw StateError('synthetic open failure');
        }
        if (blockB && identity.userId == b) {
          if (!openEntered.isCompleted) openEntered.complete();
          await openRelease.future;
        }
        return OwnerScopedLocalStore.open(root: root.path, owner: identity);
      },
      driveInProgress: () async =>
          (await journal.recoverableSessions()).isNotEmpty,
      activeSessionOwner: () => gps.activeOwner(),
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    gps = LocalOwnerGpsBridge(
      runtime: owner,
      journal: journal,
      ownership: sidecar,
      journalId: 'synthetic-journal',
    );
    final transport = MockClient((r) async {
      requests.add((
        auth: r.headers['authorization'],
        path: r.url.toString(),
        method: r.method,
      ));
      if (blockProfile) {
        if (!profileEntered.isCompleted) profileEntered.complete();
        await profileRelease.future;
      }
      final id = r.headers['authorization'] == 'Bearer synthetic-a' ? a : b;
      return http.Response(
        jsonEncode({
          'id': id,
          'username': id == a ? 'alpha' : 'bravo',
          'display_name': id == a ? 'Alpha' : 'Bravo',
        }),
        200,
        request: r,
        headers: {'content-type': 'application/json'},
      );
    });
    final gateway = OwnerProfileGateway(
      authClient: sdk,
      url: url,
      publicKey: 'sb_publishable_synthetic',
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => owner.lease.owner.userId,
      approvedEpoch: () => owner.epoch,
      isLeaseCurrent: (epoch) {
        try {
          return owner.lease.epoch == epoch && owner.lease.isCurrent;
        } catch (_) {
          return false;
        }
      },
      transport: transport,
    );
    account = SupabaseAccountService.forTesting(sdk, gateway);
  });
  tearDown(() async {
    if (!openRelease.isCompleted) openRelease.complete();
    if (!profileRelease.isCompleted) profileRelease.complete();
    await owner.close();
    owner.dispose();
    await journal.close();
    await sidecar.close();
    await sdk.dispose();
    await root.delete(recursive: true);
  });
  Future<void> signIn() => sdk.auth.signInWithPassword(
    email: 'synthetic@example.invalid',
    password: 'synthetic',
  );
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await owner.settled;
  }

  test(
    'coordinated SDK account switch revokes old lease before session changes',
    () async {
      await signIn();
      await owner.start();
      account.attachOwnerForTesting(owner);
      final oldLease = owner.lease;
      var observed = false;
      // ignore: invalid_use_of_internal_member
      final sub = sdk.auth.onAuthStateChangeSync.listen((event) {
        if (event.event == AuthChangeEvent.signedIn &&
            event.session?.user.id == b) {
          observed = true;
          expect(oldLease.isCurrent, isFalse);
          expect(() => owner.lease, throwsStateError);
        }
      });
      nextUser = b;
      token = 'synthetic-b';
      await account.signIn(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      expect(observed, isTrue);
      expect(owner.lease.owner.userId, b);
      await sub.cancel();
      account.detachOwnerForTesting(owner);
    },
  );

  test(
    'real lease fences SDK A to B, delayed profile, updates, logout and restore',
    () async {
      await signIn();
      await owner.start();
      account.attachOwnerForTesting(owner);
      expect(owner.lease.owner.userId, a);
      expect((await account.fetchCurrentProfile())?.id, a);
      final oldLease = owner.lease;
      final oldEpoch = owner.epoch;
      blockProfile = true;
      final late = account.fetchCurrentProfile();
      await profileEntered.future;
      blockB = true;
      nextUser = b;
      token = 'synthetic-b';
      var observedGap = false;
      // ignore: invalid_use_of_internal_member
      final syncEvents = sdk.auth.onAuthStateChangeSync.listen((event) {
        if (event.event != AuthChangeEvent.signedIn ||
            event.session?.user.id != b) {
          return;
        }
        observedGap =
            sdk.auth.currentUser?.id == b &&
            oldLease.isCurrent &&
            oldLease.owner.userId == a;
        expect(account.profile, isNull);
        expect(() => account.fetchCurrentProfile(), throwsA(isA<StateError>()));
      });
      await signIn();
      await syncEvents.cancel();
      expect(observedGap, isTrue);
      expect(sdk.auth.currentUser?.id, b);
      expect(account.profile, isNull);
      await expectLater(
        account.updateDisplayName('Other name'),
        throwsA(isA<StateError>()),
      );
      await openEntered.future;
      expect(oldLease.isCurrent, isFalse);
      expect(owner.epoch, greaterThan(oldEpoch));
      await expectLater(
        account.updateUsername('bravo2'),
        throwsA(isA<StateError>()),
      );
      expect(requests.every((r) => r.auth == 'Bearer synthetic-a'), isTrue);
      profileRelease.complete();
      await expectLater(late, throwsA(isA<StateError>()));
      blockProfile = false;
      openRelease.complete();
      await settle();
      expect(owner.lease.owner.userId, b);
      expect((await account.fetchCurrentProfile())?.id, b);
      expect((await account.updateDisplayName('Another name')).id, b);
      expect((await account.updateUsername('bravo2')).id, b);
      expect(requests.last.auth, 'Bearer synthetic-b');
      final epoch = owner.epoch;
      token = 'synthetic-b-refresh';
      await sdk.auth.refreshSession();
      await settle();
      expect(owner.epoch, epoch);
      final stored = jsonEncode(sdk.auth.currentSession!.toJson());
      await sdk.auth.signOut();
      await settle();
      expect(owner.lease.owner.userId, isNull);
      expect(account.profile, isNull);
      await sdk.auth.recoverSession(stored);
      await settle();
      expect(owner.lease.owner.userId, b);
      expect((await account.fetchCurrentProfile())?.id, b);
      account.detachOwnerForTesting(owner);
    },
  );

  test(
    'active GPS blocks external SDK account change; binding stays A',
    () async {
      await signIn();
      await owner.start();
      account.attachOwnerForTesting(owner);
      final session = await gps.start(startNative: (_, _) async {});
      expect((await gps.requireBinding(session.id)).owner.userId, a);
      nextUser = b;
      token = 'synthetic-b';
      await signIn();
      await settle();
      expect(owner.state, LocalOwnerState.blocked);
      expect((await gps.requireBinding(session.id)).owner.userId, a);
      expect(() => account.fetchCurrentProfile(), throwsA(isA<StateError>()));
      expect(requests, isEmpty);
      account.detachOwnerForTesting(owner);
    },
  );

  test('recoverable stopped GPS blocks a different SDK account', () async {
    await signIn();
    await owner.start();
    account.attachOwnerForTesting(owner);
    final session = await gps.start(startNative: (_, _) async {});
    await journal.stop(session.id);
    expect((await journal.recoverableSessions()).single.id, session.id);
    nextUser = b;
    token = 'synthetic-b';
    await signIn();
    await settle();
    expect(owner.state, LocalOwnerState.blocked);
    expect((await gps.requireBinding(session.id)).owner.userId, a);
    expect(() => account.fetchCurrentProfile(), throwsA(isA<StateError>()));
    expect(requests, isEmpty);
    account.detachOwnerForTesting(owner);
  });

  test(
    'invalid and repeated SDK callbacks do not change session or lease',
    () async {
      await signIn();
      await owner.start();
      account.attachOwnerForTesting(owner);
      expect((await account.fetchCurrentProfile())?.id, a);
      final lease = owner.lease;
      final bad = Uri.parse(
        'com.osaracx.driveit://auth/callback?error=access_denied',
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          sdk.auth.getSessionFromUrl(bad),
          throwsA(isA<AuthException>()),
        );
        await settle();
        expect(sdk.auth.currentUser?.id, a);
        expect(lease.isCurrent, isTrue);
        expect(account.profile?.id, a);
      }
      account.detachOwnerForTesting(owner);
    },
  );

  test(
    'identity notifications hide A and load B after the real lease is ready',
    () async {
      await signIn();
      await owner.start();
      account.attachOwnerForTesting(owner);
      account.startIdentitySync();
      await account.fetchCurrentProfile();
      final visible = <String?>[];
      account.addListener(() => visible.add(account.profile?.id));
      blockB = true;
      nextUser = b;
      token = 'synthetic-b';
      await signIn();
      await openEntered.future;
      expect(account.profile, isNull);
      expect(visible, isNot(contains(b)));
      openRelease.complete();
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(account.profile?.id, b);
      account.detachOwnerForTesting(owner);
    },
  );

  test('restart restores SDK session into a fresh real owner lease', () async {
    await signIn();
    await owner.start();
    account.attachOwnerForTesting(owner);
    expect((await account.fetchCurrentProfile())?.id, a);
    final oldLease = owner.lease;
    final stored = jsonEncode(sdk.auth.currentSession!.toJson());
    account.detachOwnerForTesting(owner);
    await owner.close();
    owner.dispose();
    expect(oldLease.isCurrent, isFalse);
    await sdk.dispose();
    sdk = SupabaseClient(
      url,
      'sb_publishable_synthetic',
      httpClient: MockClient((r) async {
        throw StateError('Unexpected Auth network request during restore');
      }),
    );
    await sdk.auth.recoverSession(stored);
    owner = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (identity) =>
          OwnerScopedLocalStore.open(root: root.path, owner: identity),
      driveInProgress: () async =>
          (await journal.recoverableSessions()).isNotEmpty,
      activeSessionOwner: () => gps.activeOwner(),
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    gps = LocalOwnerGpsBridge(
      runtime: owner,
      journal: journal,
      ownership: sidecar,
      journalId: 'synthetic-journal',
    );
    final gateway = OwnerProfileGateway(
      authClient: sdk,
      url: url,
      publicKey: 'sb_publishable_synthetic',
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => owner.lease.owner.userId,
      approvedEpoch: () => owner.epoch,
      isLeaseCurrent: (epoch) {
        try {
          return owner.lease.epoch == epoch && owner.lease.isCurrent;
        } catch (_) {
          return false;
        }
      },
      transport: MockClient(
        (r) async => http.Response(
          jsonEncode({'id': a, 'username': 'alpha', 'display_name': 'Alpha'}),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    account = SupabaseAccountService.forTesting(sdk, gateway);
    await owner.start();
    account.attachOwnerForTesting(owner);
    expect(owner.lease.owner.userId, a);
    expect((await account.fetchCurrentProfile())?.id, a);
    account.detachOwnerForTesting(owner);
  });

  test(
    'failed owner transition rejects profiles until a successful retry',
    () async {
      await signIn();
      await owner.start();
      account.attachOwnerForTesting(owner);
      expect((await account.fetchCurrentProfile())?.id, a);
      final old = owner.lease;
      failB = true;
      nextUser = b;
      token = 'synthetic-b';
      await signIn();
      await settle();
      expect(owner.state, LocalOwnerState.failed);
      expect(old.isCurrent, isFalse);
      expect(account.profile, isNull);
      expect(() => account.fetchCurrentProfile(), throwsA(isA<StateError>()));
      expect(requests.every((r) => r.auth == 'Bearer synthetic-a'), isTrue);
      failB = false;
      await owner.retry();
      expect(owner.lease.owner.userId, b);
      expect((await account.fetchCurrentProfile())?.id, b);
      account.detachOwnerForTesting(owner);
    },
  );
}
