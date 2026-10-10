import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/legacy_owner_consent.dart';
import 'package:driveit_project/widgets/local_owner_boundary.dart';
import 'package:driveit_project/widgets/legacy_owner_consent_panel.dart';

const accountA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const accountB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class FakeOwnerAuth implements LocalOwnerAuth {
  FakeOwnerAuth([this.userId]);
  @override
  String? userId;
  final controller = StreamController<String?>.broadcast(sync: true);
  @override
  Stream<String?> get changes => controller.stream;
  void change(String? id) {
    userId = id;
    controller.add(id);
  }
}

void main() {
  late Directory root;
  late FakeOwnerAuth auth;
  late LocalOwnerLifecycle runtime;
  var active = false;
  var opens = 0;
  var failOpen = false;
  var failGps = false;
  Future<void> change(String? id) async {
    auth.change(id);
    await runtime.settled;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_owner_lifecycle_');
    auth = FakeOwnerAuth();
    active = false;
    failOpen = false;
    failGps = false;
    opens = 0;
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) async {
        opens++;
        if (failOpen) throw StateError('synthetic open failure');
        return OwnerScopedLocalStore.open(root: root.path, owner: owner);
      },
      driveInProgress: () async {
        if (failGps) throw StateError('synthetic journal read failure');
        return active;
      },
    );
  });
  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.controller.close();
    await root.delete(recursive: true);
  });

  test(
    'production gate OFF does not observe Auth or touch storage/GPS',
    () async {
      final disabled = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.production,
        auth: auth,
        openStore: (_) => throw StateError('must not open'),
        driveInProgress: () => throw StateError('must not read'),
      );
      await disabled.start();
      auth.change(accountA);
      expect(disabled.state, LocalOwnerState.disabled);
      expect(() => disabled.lease, throwsStateError);
      var legacyCalled = false;
      await disabled.authorizeIdentityChange(() async {
        legacyCalled = true;
      });
      expect(legacyCalled, true);
      await disabled.close();
      disabled.dispose();
    },
  );
  test(
    'guest A logout B A retains disks and prevents same-ID collision',
    () async {
      await runtime.start();
      await runtime.lease.put('drive_names', 'same', 'guest');
      await change(accountA);
      expect(runtime.lease.read('drive_names', 'same'), null);
      await runtime.lease.put('drive_names', 'same', 'A');
      await change(null);
      expect(runtime.lease.read('drive_names', 'same'), 'guest');
      await change(accountB);
      await runtime.lease.put('drive_names', 'same', 'B');
      await change(accountA);
      expect(runtime.lease.read('drive_names', 'same'), 'A');
    },
  );
  test(
    'old repository lease revoked synchronously before new store opens',
    () async {
      await runtime.start();
      final old = runtime.lease;
      auth.change(accountA);
      expect(() => old.read('profile', 'display_name'), throwsStateError);
      expect(
        () => old.put('profile', 'display_name', 'wrong'),
        throwsStateError,
      );
      expect(() => runtime.lease, throwsStateError);
      await runtime.settled;
    },
  );
  test('late success from A is discarded under B', () async {
    await runtime.start();
    await change(accountA);
    final result = Completer<String>();
    final pending = runtime.lease.load((_) => result.future);
    await change(accountB);
    result.complete('A private value');
    expect(await pending, null);
  });
  test(
    'late A read error is discarded; current read error propagates',
    () async {
      await runtime.start();
      final result = Completer<String>();
      final pending = runtime.lease.load((_) => result.future);
      await change(accountB);
      result.completeError(StateError('old read'));
      expect(await pending, null);
      await expectLater(
        runtime.lease.load<String>((_) async {
          throw StateError('current read');
        }),
        throwsStateError,
      );
    },
  );
  test(
    'same UUID token refresh does not recreate context or lose map epoch',
    () async {
      auth.userId = accountA;
      await runtime.start();
      final epoch = runtime.epoch;
      final count = opens;
      await change(accountA);
      expect(runtime.epoch, epoch);
      expect(opens, count);
    },
  );
  test('rapid A B A events publish only the final context', () async {
    await runtime.start();
    auth.change(accountA);
    auth.change(accountB);
    auth.change(accountA);
    await runtime.settled;
    expect(runtime.lease.owner.userId, accountA);
    expect(opens, 2); // guest + final A; stale requests never open stores.
  });
  test('open failure hides A and retry opens B without deleting A', () async {
    auth.userId = accountA;
    await runtime.start();
    await runtime.lease.put('profile', 'display_name', 'A');
    failOpen = true;
    await change(accountB);
    expect(runtime.state, LocalOwnerState.failed);
    expect(() => runtime.lease, throwsStateError);
    failOpen = false;
    await runtime.retry();
    expect(runtime.lease.read('profile', 'display_name'), null);
    await change(accountA);
    expect(runtime.lease.read('profile', 'display_name'), 'A');
  });
  test(
    'invalid Auth identity fails closed, never falls back to guest',
    () async {
      await runtime.start();
      await change('not-a-uuid');
      expect(runtime.state, LocalOwnerState.failed);
      expect(runtime.errorCode, 'invalid_owner_identity');
      expect(() => runtime.lease, throwsStateError);
    },
  );
  test('active GPS blocks user logout without calling Auth', () async {
    auth.userId = accountA;
    await runtime.start();
    active = true;
    var called = false;
    await expectLater(
      runtime.authorizeIdentityChange(() async {
        called = true;
      }),
      throwsStateError,
    );
    expect(called, false);
    expect(runtime.lease.owner.userId, accountA);
  });
  test(
    'external Auth change during GPS hides data; recovery waits for completion',
    () async {
      auth.userId = accountA;
      await runtime.start();
      final ownerAtStart = runtime.lease.owner;
      active = true;
      await change(accountB);
      expect(runtime.state, LocalOwnerState.blocked);
      expect(() => runtime.lease, throwsStateError);
      expect(ownerAtStart.userId, accountA);
      active = false;
      await runtime.retry();
      expect(runtime.lease.owner.userId, accountB);
    },
  );
  test(
    'unreadable GPS state blocks user change and context transition',
    () async {
      await runtime.start();
      failGps = true;
      await expectLater(
        runtime.authorizeIdentityChange(() async {}),
        throwsStateError,
      );
      await change(accountA);
      expect(runtime.state, LocalOwnerState.failed);
      expect(() => runtime.lease, throwsStateError);
    },
  );
  for (final group in [
    'career_totals',
    'local_lifecycle_v1',
    'planet_segment_outbox_v1',
    'my_world_settings',
    'derived_cache_v1',
  ]) {
    test('$group remains isolated over owner transitions', () async {
      auth.userId = accountA;
      await runtime.start();
      await runtime.lease.put(group, 'same', {'owner': 'A'});
      await change(accountB);
      expect(runtime.lease.read(group, 'same'), null);
      await change(accountA);
      expect(runtime.lease.read<Map>(group, 'same')!['owner'], 'A');
    });
  }
  test('legacy is not a guest or restored Auth account', () async {
    final legacy = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: const GpsOwner.legacy(),
    );
    await legacy.put(legacy.owner, 'drive_names', 'same', 'legacy');
    await legacy.close();
    await runtime.start();
    expect(runtime.lease.read('drive_names', 'same'), null);
    await change(accountA);
    expect(runtime.lease.read('drive_names', 'same'), null);
  });

  test(
    'started write flushes to A before closing; never redirects to B',
    () async {
      await runtime.close();
      runtime.dispose();
      final entered = Completer<void>();
      final release = Completer<void>();
      var delay = true;
      auth.userId = accountA;
      runtime = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: auth,
        openStore: (owner) => OwnerScopedLocalStore.open(
          root: root.path,
          owner: owner,
          beforeFlush: (group) async {
            if (delay && group == 'drive_names') {
              entered.complete();
              await release.future;
            }
          },
        ),
        driveInProgress: () async => false,
      );
      await runtime.start();
      final write = runtime.lease.put('drive_names', 'same', 'A');
      await entered.future;
      auth.change(accountB);
      expect(() => runtime.lease, throwsStateError);
      delay = false;
      release.complete();
      await write;
      await runtime.settled;
      expect(runtime.lease.read('drive_names', 'same'), null);
      await change(accountA);
      expect(runtime.lease.read('drive_names', 'same'), 'A');
    },
  );

  test(
    'Auth observation failure immediately revokes current repositories',
    () async {
      await runtime.start();
      final old = runtime.lease;
      auth.controller.addError(StateError('synthetic auth stream failure'));
      expect(runtime.state, LocalOwnerState.failed);
      expect(() => old.keys('drives'), throwsStateError);
      expect(runtime.errorCode, 'auth_observation_failed');
      await runtime.retry();
      expect(runtime.state, LocalOwnerState.ready);
    },
  );

  LegacyOwnerPreview preview({bool verified = true}) => LegacyOwnerPreview(
    manifestFingerprint: 'synthetic-fingerprint',
    driveCount: 1,
    worldStatus: 'sentetik doğrulandı',
    careerStatus: 'sentetik doğrulandı',
    copyContractVerified: verified,
  );
  test(
    'preview never approves without explicit action; skip writes nothing',
    () async {
      auth.userId = accountA;
      await runtime.start();
      final consent = LegacyOwnerConsentController(runtime, preview());
      consent.skip();
      expect(() => consent.approve(), throwsStateError);
      expect(runtime.lease.keys('drives'), isEmpty);
    },
  );
  test('explicit consent pins account epoch and cannot be reused', () async {
    auth.userId = accountA;
    await runtime.start();
    final controller = LegacyOwnerConsentController(runtime, preview());
    final consent = controller.approve();
    expect(consent.target.userId, accountA);
    consent.verify('synthetic-fingerprint');
    expect(() => controller.approve(), throwsStateError);
    await change(accountB);
    expect(() => consent.verify('synthetic-fingerprint'), throwsStateError);
  });
  test('A B A invalidates old consent even when UUID returns to A', () async {
    auth.userId = accountA;
    await runtime.start();
    final controller = LegacyOwnerConsentController(runtime, preview());
    await change(accountB);
    await change(accountA);
    expect(() => controller.approve(), throwsStateError);
  });
  test(
    'missing copy/file/claim proof and changed manifest deny consent',
    () async {
      auth.userId = accountA;
      await runtime.start();
      expect(
        () => LegacyOwnerConsentController(
          runtime,
          preview(verified: false),
        ).approve(),
        throwsStateError,
      );
      final consent = LegacyOwnerConsentController(
        runtime,
        preview(),
      ).approve();
      expect(() => consent.verify('changed'), throwsStateError);
    },
  );
  test('guest cannot approve legacy adoption', () async {
    await runtime.start();
    expect(
      () => LegacyOwnerConsentController(runtime, preview()).approve(),
      throwsStateError,
    );
  });

  testWidgets(
    'OFF boundary renders original child without any scoped builder',
    (tester) async {
      final disabled = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.production,
        auth: auth,
        openStore: (_) => throw StateError('unused'),
        driveInProgress: () => throw StateError('unused'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LocalOwnerBoundary(
            runtime: disabled,
            personalBuilder: (_, _) => throw StateError('unused'),
            legacyChild: const Text('original'),
          ),
        ),
      );
      expect(find.text('original'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await disabled.close();
      disabled.dispose();
    },
  );
  testWidgets('epoch replaces personal subtree and drops old map state', (
    tester,
  ) async {
    await tester.runAsync(runtime.start);
    await tester.pumpWidget(
      MaterialApp(
        home: LocalOwnerBoundary(
          runtime: runtime,
          legacyChild: const Text('legacy'),
          personalBuilder: (_, lease) =>
              Text('map:${lease.owner.wireKind}:${lease.owner.userId}'),
        ),
      ),
    );
    final oldKey = tester
        .widget<KeyedSubtree>(find.byType(KeyedSubtree).last)
        .key;
    await tester.runAsync(() => change(accountA));
    await tester.pump();
    expect(find.text('map:guest:null'), findsNothing);
    expect(find.text('map:account:$accountA'), findsOneWidget);
    expect(
      tester.widget<KeyedSubtree>(find.byType(KeyedSubtree).last).key,
      isNot(oldKey),
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'consent panel is unselected and incomplete proof disables copy',
    (tester) async {
      auth.userId = accountA;
      await tester.runAsync(runtime.start);
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegacyOwnerConsentPanel(
              controller: LegacyOwnerConsentController(
                runtime,
                preview(verified: false),
              ),
              onApprove: (_) async {
                called = true;
              },
              onSkip: () {},
            ),
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        null,
      );
      expect(called, false);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('account switch disables an already visible approval panel', (
    tester,
  ) async {
    auth.userId = accountA;
    await tester.runAsync(runtime.start);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegacyOwnerConsentPanel(
            controller: LegacyOwnerConsentController(runtime, preview()),
            onApprove: (_) async {},
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.runAsync(() => change(accountB));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      null,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
