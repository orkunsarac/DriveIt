import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'package:driveit_project/features/group_drive/group_drive_visuals.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';

import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'owned_drive_delivery_test.dart' show DeliveryFixture;

Matcher errorCode(String code) =>
    isA<GroupDriveException>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late FakeGroupDriveService service;
  late DateTime now;
  final runtimes = <LocalOwnerLifecycle>[];
  final auths = <TestAuth>[];
  Future<LocalOwnerLifecycle> runtime(String? id) async {
    final auth = TestAuth()..userId = id;
    final result = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
    );
    runtimes.add(result);
    auths.add(auth);
    await result.start();
    return result;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_group_test_');
    now = DateTime.utc(2026, 10, 12);
    service = FakeGroupDriveService(
      clock: () => now,
      displayNames: {a: 'Hesap A', b: 'Hesap B'},
    );
  });
  tearDown(() async {
    await service.close();
    for (final r in runtimes) {
      await r.close();
      r.dispose();
    }
    for (final auth in auths) {
      await auth.events.close();
    }
    runtimes.clear();
    auths.clear();
    await root.delete(recursive: true);
  });

  test(
    'A creates, B joins by link; immutable snapshots and duplicate taps',
    () async {
      final ca = service.forOwner((await runtime(a)).lease);
      final cb = service.forOwner((await runtime(b)).lease);
      final first = await ca.create();
      expect(first.members.single.role, GroupDriveRole.administrator);
      expect(
        first.expiresAt.difference(first.createdAt),
        const Duration(hours: 12),
      );
      expect((await ca.create()).id, first.id);
      final joined = await cb.join(
        GroupDriveInvite.parse(first.invite.link.toString()),
      );
      expect(joined.members, hasLength(2));
      expect(first.members, hasLength(1)); // Previous snapshot stays immutable.
      expect((await ca.current())!.members, hasLength(2));
      expect((await cb.join(first.invite)).members, hasLength(2));
      expect(() => joined.members.clear(), throwsUnsupportedError);
    },
  );

  test(
    'LEFT rejoin uses a new grant identity; banned membership stays denied',
    () async {
      final ca = service.forOwner((await runtime(a)).lease);
      final cb = service.forOwner((await runtime(b)).lease);
      final group = await ca.create();
      await ca.startRide(group.id);
      final joined = await cb.join(group.invite);
      final oldMember = joined.members.last.membershipId;
      final oldGrant = await cb.startSharing(group.id, consent: true);
      await cb.leave(group.id);
      final again = await cb.join(group.invite);
      expect(again.members, hasLength(2));
      expect(again.members.last.membershipId, isNot(oldMember));
      expect(again.members.last.sharingStatus, GroupSharingStatus.off);
      await expectLater(
        cb.publishGps(
          oldGrant,
          GroupGpsLocation(
            latitude: 10,
            longitude: 20,
            recordedAt: now,
            accuracyMeters: 5,
            sequence: 1,
          ),
        ),
        throwsA(errorCode('publication_revoked')),
      );
      await ca.ban(group.id, b);
      await expectLater(
        cb.join(group.invite),
        throwsA(errorCode('membership_banned')),
      );
    },
  );

  test('custom navigation and stationary icons are decodable PNGs', () async {
    for (final moving in [false, true]) {
      final icon =
          GroupMarkerIcons.icon(Colors.blue, moving: moving) as BytesMapBitmap;
      final codec = await ui.instantiateImageCodec(icon.byteData);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 64);
      expect(frame.image.height, 64);
      expect(icon.width, 36);
      expect(icon.height, 36);
      final rgba = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final opaqueX = <int>[], opaqueY = <int>[];
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          if (rgba.getUint8((y * 64 + x) * 4 + 3) > 0) {
            opaqueX.add(x);
            opaqueY.add(y);
          }
        }
      }
      opaqueX.sort();
      opaqueY.sort();
      expect(opaqueX.last - opaqueX.first + 1, inInclusiveRange(24, 32));
      expect(opaqueY.last - opaqueY.first + 1, inInclusiveRange(24, 32));
      expect(
        identical(icon, GroupMarkerIcons.icon(Colors.blue, moving: moving)),
        isTrue,
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  test(
    'V2 lobby, admin idempotent start, late join, stable reusable colours and own blue',
    () async {
      final ca = service.forOwner((await runtime(a)).lease);
      final cb = service.forOwner((await runtime(b)).lease);
      final group = await ca.create();
      expect(group.phase, GroupRidePhase.lobby);
      await cb.join(group.invite);
      await expectLater(
        cb.startRide(group.id),
        throwsA(errorCode('admin_required')),
      );
      await expectLater(
        ca.startSharing(group.id, consent: true),
        throwsA(errorCode('ride_not_started')),
      );
      final started = await ca.startRide(group.id);
      expect(started.phase, GroupRidePhase.running);
      expect((await ca.startRide(group.id)).revision, started.revision);
      expect((await cb.current())!.isRunning, true);
      expect(
        started.members.every((m) => m.sharingStatus == GroupSharingStatus.off),
        true,
      );
      final colours = {
        for (final m in started.members) m.membershipId: m.colorIndex,
      };
      final self = started.members.first;
      expect(groupMemberColor(self, a), const Color(0xff2997ff));
      expect(
        groupMemberColor(started.members.last, b),
        const Color(0xff2997ff),
      );
      expect(groupMemberColor(self, b), groupMemberPalette[self.colorIndex]);
      await cb.leave(group.id);
      final cc = service.forOwner(
        (await runtime('cccccccc-cccc-4ccc-8ccc-cccccccccccc')).lease,
      );
      final joined = await cc.join(group.invite);
      expect(joined.isRunning, true);
      expect(joined.members.map((m) => m.colorIndex).toSet(), hasLength(2));
      expect(joined.members.first.colorIndex, colours[self.membershipId]);
      expect(joined.members.last.colorIndex, started.members.last.colorIndex);
    },
  );

  test(
    'real fixes determine movement beyond accuracy; icons cached and initials owner-specific',
    () {
      GroupGpsLocation fix(double lat, int seconds, {double accuracy = 5}) =>
          GroupGpsLocation(
            latitude: lat,
            longitude: 20,
            recordedAt: now.add(Duration(seconds: seconds)),
            sequence: seconds + 1,
            accuracyMeters: accuracy,
          );
      expect(GroupMotion.between(fix(10, 0), fix(10.00001, 2)).moving, false);
      final motion = GroupMotion.between(fix(10, 0), fix(10.001, 2));
      expect(motion.moving, true);
      expect(motion.heading, closeTo(0, .01));
      expect(GroupMotion.between(fix(10, 0), fix(10.001, 16)).moving, false);
      expect(
        identical(
          GroupMarkerIcons.icon(Colors.blue, moving: true),
          GroupMarkerIcons.icon(Colors.blue, moving: true),
        ),
        true,
      );
      expect(groupMemberInitials('  Orkun  Şahin '), 'OŞ');
      expect(groupMemberInitials('ACESA'), 'AC');
      expect(groupMemberInitials(''), '?');
    },
  );

  test(
    'invite parser rejects wrong schemes and ambiguous code/version',
    () async {
      final group = await service.forOwner((await runtime(a)).lease).create();
      expect(
        GroupDriveInvite.parse(group.invite.code).link.toString(),
        group.invite.link.toString(),
      );
      for (final input in [
        'https://group/join?v=1&code=${group.invite.code}',
        '${group.invite.link}&code=${group.invite.code}',
        '${group.invite.link}&v=2',
        'driveit://actor@group/join?v=1&code=${group.invite.code}',
        '${group.invite.link}#fragment',
      ]) {
        expect(
          () => GroupDriveInvite.parse(input),
          throwsA(errorCode('invalid_invite')),
        );
      }
    },
  );

  test('concurrent requests enforce ten including administrator', () async {
    final admin = service.forOwner((await runtime(a)).lease);
    final group = await admin.create();
    await admin.startRide(group.id);
    final clients = <GroupDriveClient>[];
    for (var i = 1; i <= 10; i++) {
      clients.add(
        service.forOwner(
          (await runtime(
            '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          )).lease,
        ),
      );
    }
    final outcomes = await Future.wait(
      clients.map((client) async {
        try {
          await client.join(group.invite);
          return 'joined';
        } on GroupDriveException catch (error) {
          return error.code;
        }
      }),
    );
    expect(outcomes.where((value) => value == 'joined'), hasLength(9));
    expect(outcomes.where((value) => value == 'group_full'), hasLength(1));
    final members = (await admin.current())!.members;
    expect(members, hasLength(10));
    expect(members.map((member) => member.colorIndex).toSet(), hasLength(10));
  });

  test(
    'only admin extends twice; expiry is absolute and joins then fail',
    () async {
      final ca = service.forOwner((await runtime(a)).lease);
      final cb = service.forOwner((await runtime(b)).lease);
      final group = await ca.create();
      await cb.join(group.invite);
      await expectLater(
        cb.extend(group.id),
        throwsA(errorCode('admin_required')),
      );
      await expectLater(cb.end(group.id), throwsA(errorCode('admin_required')));
      final once = await ca.extend(group.id);
      expect(
        once.expiresAt.difference(group.createdAt),
        const Duration(hours: 18),
      );
      final twice = await ca.extend(group.id);
      expect(
        twice.expiresAt.difference(group.createdAt),
        const Duration(hours: 24),
      );
      await expectLater(
        ca.extend(group.id),
        throwsA(errorCode('extension_limit')),
      );
      now = twice.expiresAt;
      expect((await cb.current())!.status, GroupDriveStatus.expired);
      await expectLater(
        cb.join(group.invite),
        throwsA(errorCode('group_inactive')),
      );
      await expectLater(
        ca.extend(group.id),
        throwsA(errorCode('group_inactive')),
      );
    },
  );

  test(
    'admin leave transfers to earliest member; last departure closes group',
    () async {
      final ca = service.forOwner((await runtime(a)).lease);
      final cb = service.forOwner((await runtime(b)).lease);
      final cc = service.forOwner(
        (await runtime('cccccccc-cccc-4ccc-8ccc-cccccccccccc')).lease,
      );
      final group = await ca.create();
      await cb.join(group.invite);
      await cc.join(
        group.invite,
      ); // Same timestamp; stable joinOrder resolves tie.
      await ca.leave(group.id);
      expect(await ca.current(), null);
      expect(
        (await cb.current())!.members.first.role,
        GroupDriveRole.administrator,
      );
      await cb.leave(group.id);
      expect(
        (await cc.current())!.members.single.role,
        GroupDriveRole.administrator,
      );
      await cc.leave(group.id);
      await expectLater(
        ca.join(group.invite),
        throwsA(errorCode('group_inactive')),
      );
    },
  );

  test(
    'different groups isolated, no ID bypass, one active group per account',
    () async {
      final ca = service.forOwner((await runtime(a)).lease);
      final cb = service.forOwner((await runtime(b)).lease);
      final ga = await ca.create();
      final gb = await cb.create();
      expect(ga.id, isNot(gb.id));
      expect(ga.invite.code, isNot(gb.invite.code));
      await expectLater(
        cb.end(ga.id),
        throwsA(errorCode('membership_required')),
      );
      await expectLater(
        cb.join(ga.invite),
        throwsA(errorCode('already_in_group')),
      );
      expect((await ca.current())!.members, hasLength(1));
      await ca.end(ga.id);
      expect((await ca.current())!.status, GroupDriveStatus.ended);
      expect((await cb.current())!.status, GroupDriveStatus.active);
    },
  );

  test('guest, unresolved and revoked owner never access group data', () async {
    final guest = await runtime(null);
    expect(
      () => service.forOwner(guest.lease),
      throwsA(errorCode('account_required')),
    );
    final ra = await runtime(a);
    final oldClient = service.forOwner(ra.lease);
    await oldClient.create();
    auths.last.emit(b);
    await ra.settled;
    await expectLater(oldClient.current(), throwsStateError);
    expect(await service.forOwner(ra.lease).current(), null);
    final pending = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: TestAuth(),
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
    );
    expect(() => pending.lease, throwsStateError);
    await pending.close();
    pending.dispose();
  });

  test(
    'delayed request after owner change is rejected before mutation',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      await service.close();
      service = FakeGroupDriveService(
        beforeRequest: (_) async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        },
      );
      final ra = await runtime(a);
      final ca = service.forOwner(ra.lease);
      final creation = ca.create();
      final failure = expectLater(creation, throwsStateError);
      await entered.future;
      auths.last.emit(b);
      await ra.settled;
      release.complete();
      await failure;
      expect(await service.forOwner(ra.lease).current(), null);
      auths.last.emit(a);
      await ra.settled;
      expect(await service.forOwner(ra.lease).current(), null);
    },
  );

  test(
    'group location grants fence stale, paused, left and banned publishers',
    () async {
      final ra = await runtime(a);
      final rb = await runtime(b);
      final admin = service.forOwner(ra.lease);
      final member = service.forOwner(rb.lease);
      final group = await admin.create();
      await admin.startRide(group.id);
      await member.join(group.invite);

      final firstGrant = await member.startSharing(group.id, consent: true);
      await expectLater(
        member.publishGps(
          firstGrant,
          GroupGpsLocation(
            latitude: 41,
            longitude: 29,
            recordedAt: now.subtract(const Duration(seconds: 16)),
            sequence: 1,
            accuracyMeters: 5,
          ),
        ),
        throwsA(errorCode('stale_location')),
      );
      await member.publishGps(
        firstGrant,
        GroupGpsLocation(
          latitude: 41,
          longitude: 29,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      expect((await admin.current())!.members.last.location, isNotNull);

      final paused = await member.pauseSharing(group.id);
      expect(paused.members.last.location, isNull);
      await expectLater(
        member.publishGps(
          firstGrant,
          GroupGpsLocation(
            latitude: 41,
            longitude: 29,
            recordedAt: now,
            sequence: 2,
            accuracyMeters: 5,
          ),
        ),
        throwsA(errorCode('publication_revoked')),
      );
      final resumedGrant = await member.startSharing(group.id, consent: true);
      expect(resumedGrant.publicationId, isNot(firstGrant.publicationId));
      await member.publishGps(
        resumedGrant,
        GroupGpsLocation(
          latitude: 41,
          longitude: 29,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );

      await admin.ban(group.id, b);
      expect(await member.current(), isNull);
      expect((await admin.current())!.members, hasLength(1));
      await expectLater(
        member.publishGps(
          resumedGrant,
          GroupGpsLocation(
            latitude: 41,
            longitude: 29,
            recordedAt: now,
            sequence: 2,
            accuracyMeters: 5,
          ),
        ),
        throwsA(errorCode('membership_required')),
      );
    },
  );

  test(
    'owner epoch revokes old publication and clears coordinates for peers',
    () async {
      final ra = await runtime(a);
      final rb = await runtime(b);
      final ownerClient = service.forOwner(ra.lease);
      final peerClient = service.forOwner(rb.lease);
      final group = await ownerClient.create();
      await ownerClient.startRide(group.id);
      await peerClient.join(group.invite);
      final grant = await ownerClient.startSharing(group.id, consent: true);
      await ownerClient.publishGps(
        grant,
        GroupGpsLocation(
          latitude: 41,
          longitude: 29,
          recordedAt: now,
          sequence: 1,
          accuracyMeters: 5,
        ),
      );
      expect((await peerClient.current())!.members.first.location, isNotNull);

      auths[auths.length - 2].emit('dddddddd-dddd-4ddd-8ddd-dddddddddddd');
      await ra.settled;
      final peerSnapshot = (await peerClient.current())!;
      final oldOwner = peerSnapshot.members.firstWhere(
        (member) => member.accountId == a,
      );
      expect(oldOwner.sharingStatus, GroupSharingStatus.paused);
      expect(oldOwner.location, isNull);
      await expectLater(
        ownerClient.publishGps(
          grant,
          GroupGpsLocation(
            latitude: 41,
            longitude: 29,
            recordedAt: now,
            sequence: 2,
            accuracyMeters: 5,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'offline group service leaves actual normal drive save and sync intact',
    () async {
      final f = DeliveryFixture();
      await f.open();
      try {
        final client = service.forOwner(f.runtime.owner.lease);
        final group = await client.create();
        await client.startRide(group.id);
        final grant = await client.startSharing(group.id, consent: true);
        await client.publishSynthetic(
          grant,
          GroupSyntheticLocation(
            latitude: 10,
            longitude: 20,
            recordedAt: service.simulationTime,
            sequence: 1,
          ),
        );
        service.available = false;
        await expectLater(client.current(), throwsA(errorCode('offline')));
        final drive = await f.record();
        await f.save(drive);
        expect(
          f.runtime.owner.lease.requireDrive(drive.id).route,
          hasLength(301),
        );
        expect(f.runtime.owner.lease.pendingSyncKeys(), hasLength(1));
        service.available = true;
        expect(
          (await client.current())!.members.single.sharingStatus,
          GroupSharingStatus.sharing,
        );
      } finally {
        await f.close();
      }
    },
  );
}
