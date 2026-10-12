import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'group_drive_service_test.dart' show errorCode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FakeGroupDriveService service;
  late DateTime now;
  late LocalOwnerLifecycle ra, rb, rc;
  late TestAuth aa, ab, ac;
  const c = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  Future<LocalOwnerLifecycle> open(TestAuth auth, String device) async {
    final r = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) => OwnerScopedLocalStore.open(
        root: '${root.path}/$device',
        owner: owner,
      ),
      driveInProgress: () async => false,
    );
    await r.start();
    return r;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_group_locations_');
    now = DateTime.utc(2026, 10, 12);
    service = FakeGroupDriveService(clock: () => now);
    aa = TestAuth();
    ab = TestAuth()..userId = b;
    ac = TestAuth()..userId = c;
    ra = await open(aa, 'a');
    rb = await open(ab, 'b');
    rc = await open(ac, 'c');
  });
  tearDown(() async {
    await service.close();
    for (final r in [ra, rb, rc]) {
      await r.close();
      r.dispose();
    }
    for (final auth in [aa, ab, ac]) {
      await auth.events.close();
    }
    await root.delete(recursive: true);
  });
  GroupSyntheticLocation point([int sequence = 1]) => GroupSyntheticLocation(
    latitude: 10,
    longitude: 20,
    recordedAt: now,
    sequence: sequence,
  );

  test(
    'A B C default OFF; explicit consent admits only the publisher member',
    () async {
      final ca = service.forOwner(ra.lease),
          cb = service.forOwner(rb.lease),
          cc = service.forOwner(rc.lease);
      final group = await ca.create();
      await cb.join(group.invite);
      await cc.join(group.invite);
      expect(
        (await ca.current())!.members.every(
          (m) =>
              m.sharingStatus == GroupSharingStatus.off && m.location == null,
        ),
        true,
      );
      await expectLater(
        cb.startSharing(group.id, consent: false),
        throwsA(errorCode('consent_required')),
      );
      final ga = await ca.startSharing(group.id, consent: true);
      final gc = await cc.startSharing(group.id, consent: true);
      await ca.publishSynthetic(ga, point());
      await cc.publishSynthetic(gc, point());
      final snapshot = (await ca.current())!;
      expect(snapshot.members.where((m) => m.location != null), hasLength(2));
      expect(
        snapshot.members.singleWhere((m) => m.accountId == b).location,
        null,
      );
      await expectLater(
        cb.publishSynthetic(ga, point()),
        throwsA(errorCode('publication_revoked')),
      );
      final gb = await cb.startSharing(group.id, consent: true);
      await cb.publishSynthetic(gb, point());
      expect(
        (await ca.current())!.members.where((m) => m.location != null),
        hasLength(3),
      );
    },
  );

  test(
    'pause/off erase latest point; resume needs a fresh explicit grant',
    () async {
      final ca = service.forOwner(ra.lease), cb = service.forOwner(rb.lease);
      final group = await ca.create();
      await cb.join(group.invite);
      final ga = await ca.startSharing(group.id, consent: true);
      final gb = await cb.startSharing(group.id, consent: true);
      await ca.publishSynthetic(ga, point());
      await cb.publishSynthetic(gb, point());
      await cb.pauseSharing(group.id);
      expect(
        (await ca.current())!.members
            .singleWhere((m) => m.accountId == b)
            .location,
        null,
      );
      expect(
        (await cb.current())!.members
            .singleWhere((m) => m.accountId == a)
            .location,
        isNotNull,
      );
      await expectLater(
        cb.publishSynthetic(gb, point(2)),
        throwsA(errorCode('publication_revoked')),
      );
      final resumed = await cb.startSharing(group.id, consent: true);
      expect(resumed.publicationId, isNot(gb.publicationId));
      await expectLater(
        cb.publishSynthetic(gb, point(3)),
        throwsA(errorCode('publication_revoked')),
      );
      await cb.publishSynthetic(resumed, point());
      await cb.stopSharing(group.id);
      final member = (await ca.current())!.members.singleWhere(
        (m) => m.accountId == b,
      );
      expect(member.sharingStatus, GroupSharingStatus.off);
      expect(member.location, null);
    },
  );

  test(
    'delayed publication after pause is rejected even when fake transport fails',
    () async {
      await service.close();
      final entered = Completer<void>(), release = Completer<void>();
      service = FakeGroupDriveService(
        clock: () => now,
        beforeRequest: (operation) async {
          if (operation == 'publishSynthetic') {
            entered.complete();
            await release.future;
          }
        },
      );
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      final grant = await client.startSharing(group.id, consent: true);
      final send = client.publishSynthetic(grant, point());
      final rejected = expectLater(
        send,
        throwsA(errorCode('publication_revoked')),
      );
      await entered.future;
      service.available = false;
      final paused = await client.pauseSharing(
        group.id,
      ); // Independent safety control.
      expect(paused.members.single.location, null);
      service.available = true;
      release.complete();
      await rejected;
      expect(
        (await client.current())!.members.single.sharingStatus,
        GroupSharingStatus.paused,
      );
    },
  );

  test('leave/rejoin replaces membership and rejects old grant', () async {
    final ca = service.forOwner(ra.lease), cb = service.forOwner(rb.lease);
    final group = await ca.create();
    await cb.join(group.invite);
    final grant = await cb.startSharing(group.id, consent: true);
    await cb.publishSynthetic(grant, point());
    await cb.leave(group.id);
    expect((await ca.current())!.members, hasLength(1));
    final rejoined = await cb.join(group.invite);
    final member = rejoined.members.singleWhere((m) => m.accountId == b);
    expect(member.membershipId, isNot(grant.membershipId));
    expect(member.sharingStatus, GroupSharingStatus.off);
    await expectLater(
      cb.publishSynthetic(grant, point(2)),
      throwsA(errorCode('publication_revoked')),
    );
  });

  test(
    'end and expiry stop every publication, including retained snapshots',
    () async {
      final ca = service.forOwner(ra.lease), cb = service.forOwner(rb.lease);
      var group = await ca.create();
      await cb.join(group.invite);
      final grant = await cb.startSharing(group.id, consent: true);
      await cb.publishSynthetic(grant, point());
      await ca.end(group.id);
      expect(
        (await cb.current())!.members.every(
          (m) =>
              m.location == null && m.sharingStatus == GroupSharingStatus.off,
        ),
        true,
      );
      await expectLater(
        cb.publishSynthetic(grant, point(2)),
        throwsA(errorCode('group_inactive')),
      );
      group = await ca.create();
      await cb.join(group.invite);
      final newGrant = await cb.startSharing(group.id, consent: true);
      await cb.publishSynthetic(newGrant, point());
      now = group.expiresAt;
      expect(
        (await cb.current())!.members.every(
          (m) =>
              m.location == null && m.sharingStatus == GroupSharingStatus.off,
        ),
        true,
      );
      await expectLater(
        cb.publishSynthetic(newGrant, point(2)),
        throwsA(errorCode('group_inactive')),
      );
    },
  );

  test(
    'owner revocation immediately clears A point; another group has no locations',
    () async {
      final ca = service.forOwner(ra.lease),
          cb = service.forOwner(rb.lease),
          cc = service.forOwner(rc.lease);
      final group = await ca.create();
      await cb.join(group.invite);
      await cc.create();
      final grant = await ca.startSharing(group.id, consent: true);
      await ca.publishSynthetic(grant, point());
      aa.emit(b); // Lease is revoked synchronously, before next store is ready.
      final snapshot = (await cb.current())!;
      expect(
        snapshot.members.singleWhere((m) => m.accountId == a).location,
        null,
      );
      expect(
        snapshot.members.singleWhere((m) => m.accountId == a).sharingStatus,
        GroupSharingStatus.paused,
      );
      await ra.settled;
      await expectLater(ca.publishSynthetic(grant, point(2)), throwsStateError);
      expect(
        (await cc.current())!.members.every((m) => m.location == null),
        true,
      );
    },
  );

  test(
    'stale future duplicate samples fail closed and client recreation never auto resumes',
    () async {
      final client = service.forOwner(ra.lease);
      final group = await client.create();
      final grant = await client.startSharing(group.id, consent: true);
      await client.publishSynthetic(grant, point());
      await expectLater(
        client.publishSynthetic(
          GroupLocationGrant(
            groupId: grant.groupId,
            membershipId: grant.membershipId,
            publicationId: grant.publicationId,
            ownerEpoch: grant.ownerEpoch,
            startedAt: grant.startedAt.subtract(const Duration(seconds: 1)),
          ),
          point(2),
        ),
        throwsA(errorCode('publication_revoked')),
      );
      await expectLater(
        client.publishSynthetic(grant, point()),
        throwsA(errorCode('stale_location')),
      );
      now = now.add(const Duration(seconds: 16));
      await expectLater(
        client.publishSynthetic(
          grant,
          GroupSyntheticLocation(
            latitude: 10,
            longitude: 20,
            recordedAt: now.subtract(const Duration(seconds: 16)),
            sequence: 2,
          ),
        ),
        throwsA(errorCode('stale_location')),
      );
      await expectLater(
        client.publishSynthetic(
          grant,
          GroupSyntheticLocation(
            latitude: 10,
            longitude: 20,
            recordedAt: now.add(const Duration(seconds: 1)),
            sequence: 2,
          ),
        ),
        throwsA(errorCode('stale_location')),
      );
      await client.close();
      final recreated = service.forOwner(ra.lease);
      expect(
        (await recreated.current())!.members.single.sharingStatus,
        GroupSharingStatus.paused,
      );
      expect((await recreated.current())!.members.single.location, null);
      await expectLater(
        recreated.publishSynthetic(grant, point(3)),
        throwsA(errorCode('publication_revoked')),
      );
    },
  );
}
