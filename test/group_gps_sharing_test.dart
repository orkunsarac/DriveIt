import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'package:driveit_project/features/group_drive/group_gps_source.dart';
import 'package:driveit_project/features/group_drive/group_gps_sharing.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'owned_drive_delivery_test.dart' show DeliveryFixture;

class FakeGroupGps implements GroupGpsSource {
  FakeGroupGps() {
    stream = StreamController<Position>.broadcast(
      sync: true,
      onListen: () {
        opens++;
      },
      onCancel: () {
        cancels++;
      },
    );
  }
  late final StreamController<Position> stream;
  bool allowed = true;
  int opens = 0, cancels = 0, requests = 0;
  Completer<bool>? accessHold;
  @override
  Future<void> requestAccess() async {
    requests++;
    if (!allowed) throw const GroupGpsException('permission_denied');
  }

  @override
  Future<bool> hasAccess() => accessHold?.future ?? Future.value(allowed);
  @override
  Stream<Position> positions() => stream.stream;
}

Position groupPosition(
  DateTime at, {
  double accuracy = 5,
  double latitude = 10,
  bool mocked = false,
}) => Position(
  latitude: latitude,
  longitude: 20,
  timestamp: at,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 10,
  speedAccuracy: 0,
  isMocked: mocked,
);

class GroupGpsPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requested = LocationPermission.whileInUse;
  bool enabled = true;
  int requests = 0;
  LocationSettings? settings;
  final stream = StreamController<Position>.broadcast(sync: true);
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission = requested;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return stream.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late TestAuth auth;
  late LocalOwnerLifecycle runtime;
  late FakeGroupDriveService service;
  late FakeGroupGps source;
  late GroupDriveClient client;
  late GroupDriveSnapshot group;
  late GroupGpsSharing gps;
  late DateTime now;
  StreamSubscription<GroupDriveSnapshot?>? groupWatch;
  setUp(() async {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    root = await Directory.systemTemp.createTemp('driveit_group_gps_');
    auth = TestAuth();
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
    );
    await runtime.start();
    now = DateTime.utc(2026, 10, 12);
    service = FakeGroupDriveService(clock: () => now);
    client = service.forOwner(runtime.lease);
    group = await client.create();
    source = FakeGroupGps();
    gps = GroupGpsSharing(
      lease: runtime.lease,
      client: client,
      source: source,
      clock: () => now,
    );
    groupWatch = client.changes.listen(gps.updateGroup);
  });
  tearDown(() async {
    await groupWatch?.cancel();
    await gps.close();
    gps.dispose();
    await source.stream.close();
    await service.close();
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await root.delete(recursive: true);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  Future<void> emit(Position position) async {
    source.stream.add(position);
    await gps.settled;
  }

  GroupDriveMember mine(GroupDriveSnapshot snapshot) =>
      snapshot.members.singleWhere((m) => m.accountId == a);

  test(
    'no consent or permission -> no source subscription; approved GPS reaches group',
    () async {
      await expectLater(
        gps.start(group.id, consent: false),
        throwsA(isA<GroupGpsException>()),
      );
      expect(source.requests, 0);
      expect(source.opens, 0);
      source.allowed = false;
      await expectLater(
        gps.start(group.id, consent: true),
        throwsA(isA<GroupGpsException>()),
      );
      expect(source.opens, 0);
      expect(
        mine((await client.current())!).sharingStatus,
        GroupSharingStatus.off,
      );
      source.allowed = true;
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      expect(
        mine((await client.current())!).location!.origin,
        GroupLocationOrigin.deviceGps,
      );
      expect(mine((await client.current())!).location!.accuracyMeters, 5);
      expect(runtime.lease.drives(), isEmpty); // Group points are not History.
    },
  );
  test(
    'pause cancels only owned listener; resume and restart require new consent',
    () async {
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      await gps.pause(group.id);
      now = now.add(const Duration(seconds: 1));
      await emit(groupPosition(now));
      expect(mine((await client.current())!).location, null);
      expect(source.cancels, 1);
      await expectLater(
        gps.start(group.id, consent: false),
        throwsA(isA<GroupGpsException>()),
      );
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      expect(mine((await client.current())!).location, isNotNull);
      await gps.close();
      gps.dispose();
      gps = GroupGpsSharing(
        lease: runtime.lease,
        client: client,
        source: source,
        clock: () => now,
      );
      groupWatch?.cancel();
      groupWatch = client.changes.listen(gps.updateGroup);
      expect(gps.active, false);
      expect(source.opens, 2);
      expect(mine((await client.current())!).location, null);
    },
  );
  test(
    'old poor accuracy mock future cached and duplicate points never publish',
    () async {
      await gps.start(group.id, consent: true);
      for (final p in [
        groupPosition(now.subtract(const Duration(seconds: 20))),
        groupPosition(now, accuracy: 80),
        groupPosition(now, mocked: true),
        groupPosition(now.add(const Duration(seconds: 1))),
        groupPosition(now, latitude: 100),
      ]) {
        await emit(p);
      }
      expect(mine((await client.current())!).location, null);
      await emit(groupPosition(now));
      await emit(groupPosition(now));
      expect(mine((await client.current())!).location!.sequence, 1);
    },
  );
  test(
    'permission revoke and group end cancel source and clear coordinate',
    () async {
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      source.allowed = false;
      await emit(groupPosition(now.add(const Duration(seconds: 1))));
      expect(gps.active, false);
      expect(gps.errorCode, 'permission_revoked');
      expect(mine((await client.current())!).location, null);
      source.allowed = true;
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      await client.end(group.id);
      expect(gps.active, false);
      expect(source.cancels, 2);
      expect(mine((await client.current())!).location, null);
    },
  );
  test(
    'leaving and expiry revoke the GPS source and clear its point',
    () async {
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      await client.leave(group.id);
      expect(gps.active, false);
      expect(source.cancels, 1);
      group = await client.create();
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      now = group.expiresAt;
      gps.updateGroup(await client.current());
      expect(gps.active, false);
      expect(source.cancels, 2);
      expect(mine((await client.current())!).location, null);
    },
  );
  test(
    'stream failure clears publication without automatic reconnect',
    () async {
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      source.stream.addError(StateError('synthetic stream failure'));
      await Future<void>.value();
      expect(gps.active, false);
      expect(gps.errorCode, 'gps_stream_error');
      expect(mine((await client.current())!).location, null);
      expect(source.opens, 1);
      expect(source.cancels, 1);
    },
  );
  test(
    'late permission callback after owner switch cannot publish A point',
    () async {
      await gps.start(group.id, consent: true);
      source.accessHold = Completer<bool>();
      source.stream.add(groupPosition(now));
      final pending = gps.settled;
      auth.emit(b);
      await runtime.settled;
      source.accessHold!.complete(true);
      await pending;
      expect(gps.active, false);
      expect(source.cancels, 1);
      expect(await service.forOwner(runtime.lease).current(), null);
      auth.emit(a);
      await runtime.settled;
      expect(
        (await service.forOwner(runtime.lease).current())!
            .members
            .single
            .location,
        null,
      );
    },
  );
  test(
    'app background withdraws; foreground return does not automatically resume',
    () async {
      await gps.start(group.id, consent: true);
      await emit(groupPosition(now));
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      expect(gps.active, false);
      expect(mine((await client.current())!).location, null);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      expect(gps.active, false);
      expect(source.opens, 1);
      await gps.start(group.id, consent: true);
      expect(source.opens, 2);
    },
  );
  test(
    'Android adapter requests foreground permission and has no FGS notification config',
    () async {
      final platform = GroupGpsPlatform();
      final adapter = AndroidGroupGpsSource(platform: platform);
      await adapter.requestAccess();
      expect(platform.requests, 1);
      expect(await adapter.hasAccess(), true);
      final driveListener = adapter.positions().listen((_) {});
      final groupListener = adapter.positions().listen((_) {});
      expect(
        (platform.settings! as AndroidSettings).foregroundNotificationConfig,
        null,
      );
      await groupListener.cancel();
      expect(platform.stream.hasListener, true);
      await driveListener.cancel();
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        adapter.requestAccess(),
        throwsA(isA<GroupGpsException>()),
      );
      expect(platform.requests, 1);
      platform.enabled = false;
      expect(await adapter.hasAccess(), false);
      await platform.stream.close();
    },
  );
  test(
    'normal recording journal survives group GPS pause; drive stop does not stop group',
    () async {
      final f = DeliveryFixture();
      await f.open();
      final fClient = service.forOwner(f.runtime.owner.lease);
      final fg = await fClient.create();
      final fSource = FakeGroupGps();
      final fGps = GroupGpsSharing(
        lease: f.runtime.owner.lease,
        client: fClient,
        source: fSource,
        clock: () => now,
      );
      try {
        final recording = await ForegroundService.start();
        await fGps.start(fg.id, consent: true);
        fSource.stream.add(groupPosition(now));
        await fGps.settled;
        await fGps.pause(fg.id);
        expect((await f.runtime.gps.journal.active())!.id, recording.id);
        expect((await f.runtime.gps.journal.read(recording.id)), isEmpty);
        await fGps.start(fg.id, consent: true);
        final drive = await f.populate(recording.id, recording.startedAt);
        expect(
          fGps.active,
          true,
        ); // Normal stop has no group source side effect.
        await f.save(drive);
        expect(f.runtime.owner.lease.pendingSyncKeys(), hasLength(1));
        expect(
          f.runtime.owner.lease.requireDrive(drive.id).route,
          hasLength(301),
        );
      } finally {
        await fGps.close();
        fGps.dispose();
        await fSource.stream.close();
        await f.close();
      }
    },
  );
}
