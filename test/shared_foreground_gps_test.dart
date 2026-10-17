import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/task_handler.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'group_gps_sharing_test.dart' show groupPosition;
import 'owned_drive_delivery_test.dart' show DeliveryFixture;

class _TaskPlatform extends GeolocatorPlatform {
  int opens = 0, cancels = 0;
  bool allowed = true;
  late final samples = StreamController<Position>.broadcast(
    sync: true,
    onListen: () => opens++,
    onCancel: () => cancels++,
  );
  @override
  Future<bool> isLocationServiceEnabled() async => allowed;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    expect(
      (locationSettings as AndroidSettings).foregroundNotificationConfig,
      null,
    );
    return samples.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late _TaskPlatform platform;
  late GeolocatorPlatform previous;
  late DriveTaskHandler handler;
  late Directory root;
  final reports = <Map>[];
  final nativeCalls = <String>[];
  void receive(Object value) {
    if (value is Map) reports.add(value);
  }

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));
  Future<void> command(Map<String, Object> value) async {
    handler.onReceiveData(value);
    await handler.settled;
    await tick();
  }

  Future<void> group(String commandName) => command({
    'groupGpsCommand': commandName,
    'groupGpsToken': 'ephemeral-host-only',
  });
  setUp(() async {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('driveit_shared_gps_');
    previous = GeolocatorPlatform.instance;
    platform = _TaskPlatform();
    GeolocatorPlatform.instance = platform;
    reports.clear();
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_foreground_task/methods'),
          (call) async {
            nativeCalls.add(call.method);
            return call.method == 'isRunningService' ? true : null;
          },
        );
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(receive);
    handler = DriveTaskHandler(
      recordingRequested: false,
      openJournal: () => GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/journal.db',
      ),
    );
    await handler.onStart(DateTime.now(), TaskStarter.developer);
  });
  tearDown(() async {
    await handler.onDestroy(DateTime.now(), false);
    await tick();
    FlutterForegroundTask.removeTaskDataCallback(receive);
    await FlutterForegroundTask.streamSubscription?.cancel();
    FlutterForegroundTask.receivePort?.close();
    await platform.samples.close();
    GeolocatorPlatform.instance = previous;
    await root.delete(recursive: true);
  });

  test(
    'group-only uses one physical stream and IPC; no journal or persisted coordinates',
    () async {
      expect(platform.opens, 0);
      expect(await root.list().isEmpty, true);
      await group('attach');
      expect(platform.opens, 1);
      expect(
        reports.any((v) => v['groupGpsAttached'] == 'ephemeral-host-only'),
        true,
      );
      platform.samples.add(groupPosition(DateTime.now()));
      await tick();
      expect(
        reports.where((v) => v.containsKey('groupGpsSample')),
        hasLength(1),
      );
      expect(await root.list().isEmpty, true);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await group('detach');
      expect(platform.cancels, 1);
      expect(reports.last['recording'], false);
      platform.samples.add(groupPosition(DateTime.now()));
      await tick();
      expect(
        reports.where((v) => v.containsKey('groupGpsSample')),
        hasLength(1),
      );
    },
  );

  test(
    'drive attaches to group producer; durable drain leaves group receiving',
    () async {
      await group('attach');
      final journal = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/journal.db',
      );
      final session = await journal.create();
      await command({'attachRecording': true});
      expect(reports.any((v) => v['recordingAttached'] == session.id), true);
      expect(platform.opens, 1);
      platform.samples.add(groupPosition(DateTime.now()));
      await tick();
      await command({'drainSession': session.id});
      expect((await journal.session(session.id))!.state, 'stopped');
      expect(
        (await journal.events(session.id)).where((e) => e['kind'] == 'drained'),
        hasLength(1),
      );
      expect(platform.cancels, 0);
      final before = reports
          .where((v) => v.containsKey('groupGpsSample'))
          .length;
      final count = (await journal.read(session.id)).length;
      platform.samples.add(
        groupPosition(DateTime.now().add(const Duration(seconds: 1))),
      );
      await tick();
      expect(
        reports.where((v) => v.containsKey('groupGpsSample')).length,
        before + 1,
      );
      expect((await journal.read(session.id)).length, count);
      await group('detach');
      expect(platform.cancels, 1);
      await journal.close();
    },
  );

  test(
    'group stop preserves drive-only writer and its physical subscription',
    () async {
      final journal = await GpsSessionStore.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${root.path}/journal.db',
      );
      final session = await journal.create();
      await command({'attachRecording': true});
      await group('attach');
      await group('detach');
      expect(reports.last['recording'], true);
      expect(platform.opens, 1);
      expect(platform.cancels, 0);
      platform.samples.add(groupPosition(DateTime.now()));
      await tick();
      await command({'drainSession': session.id});
      expect(platform.cancels, 1);
      expect((await journal.read(session.id)), isNotEmpty);
      expect(reports.where((v) => v.containsKey('groupGpsSample')), isEmpty);
      await journal.close();
    },
  );

  test(
    'expired ephemeral demand revokes group; fresh engine never restores it',
    () async {
      await group('attach');
      handler.onRepeatEvent(DateTime.now().add(const Duration(seconds: 11)));
      await tick();
      expect(
        reports.any((v) => v['groupGpsError'] == 'ephemeral-host-only'),
        true,
      );
      final before = reports
          .where((v) => v.containsKey('groupGpsSample'))
          .length;
      platform.samples.add(groupPosition(DateTime.now()));
      await tick();
      expect(
        reports.where((v) => v.containsKey('groupGpsSample')).length,
        before,
      );
      await handler.onDestroy(DateTime.now(), false);
      final opens = platform.opens;
      handler = DriveTaskHandler(
        recordingRequested: false,
        openJournal: () async => throw StateError('must not open a journal'),
      );
      await handler.onStart(DateTime.now(), TaskStarter.system);
      handler.onRepeatEvent(DateTime.now());
      await tick();
      expect(platform.opens, opens);
    },
  );

  test(
    'permission loss revokes group source and does not silently reattach',
    () async {
      await group('attach');
      platform.allowed = false;
      handler.onRepeatEvent(DateTime.now());
      await tick();
      expect(
        reports.any((v) => v['groupGpsError'] == 'ephemeral-host-only'),
        true,
      );
      expect(platform.cancels, 1);
      platform.allowed = true;
      handler.onRepeatEvent(DateTime.now());
      await tick();
      expect(platform.opens, 1);
    },
  );

  test(
    'recording bootstrap failure leaves the group consumer receiving live samples',
    () async {
      await handler.onDestroy(DateTime.now(), false);
      handler = DriveTaskHandler(
        recordingRequested: false,
        openJournal: () async =>
            throw StateError('synthetic recording storage failure'),
      );
      await handler.onStart(DateTime.now(), TaskStarter.developer);
      await group('attach');
      await command({'attachRecording': true});
      platform.samples.add(groupPosition(DateTime.now()));
      await tick();
      expect(reports.any((v) => v.containsKey('groupGpsSample')), true);
      expect(reports.any((v) => v.containsKey('groupGpsError')), false);
      expect(platform.cancels, 0);
    },
  );

  test(
    'real static bridge attaches and drains recording without stopping group-only service',
    () async {
      final fixture = DeliveryFixture();
      await fixture.open();
      await handler.onDestroy(DateTime.now(), false);
      handler = DriveTaskHandler(
        recordingRequested: false,
        openJournal: () => GpsSessionStore.open(
          factory: databaseFactoryFfiNoIsolate,
          path: fixture.runtime.gps.journal.db.path,
        ),
        verifySessionOwner: (id) => ForegroundService.verifyOwnerSession(
          fixture.runtime.owner.lease,
          id,
        ),
      );
      var running = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeliveryFixture.channel, (call) async {
            nativeCalls.add(call.method);
            switch (call.method) {
              case 'isRunningService':
                return running;
              case 'startService':
                running = true;
                await handler.onStart(DateTime.now(), TaskStarter.developer);
              case 'sendData':
                handler.onReceiveData(call.arguments as Object);
              case 'stopService':
                running = false;
                await handler.onDestroy(DateTime.now(), false);
            }
            return null;
          });
      final points = <Position>[];
      final errors = <Object>[];
      final subscription = ForegroundService.groupPositions().listen(
        points.add,
        onError: errors.add,
      );
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (!reports.any((m) => m.containsKey('groupGpsAttached')) &&
            errors.isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tick();
        }
        expect(errors, isEmpty);
        expect(running, true);
        expect(reports.any((m) => m.containsKey('groupGpsAttached')), true);
        expect(
          (await ForegroundService.inspectRecovery()).canStartNewDrive,
          true,
        );
        expect(await ForegroundService.activeSession(), null);
        final session = await ForegroundService.start();
        expect(
          (await ForegroundService.inspectRecovery()).producerRunning,
          true,
        );
        expect(platform.opens, 1);
        platform.samples.add(groupPosition(DateTime.now()));
        await tick();
        expect(points, hasLength(1));
        await ForegroundService.stop();
        expect(running, true);
        expect(
          (await fixture.runtime.gps.journal.session(session.id))!.state,
          'stopped',
        );
        platform.samples.add(
          groupPosition(DateTime.now().add(const Duration(seconds: 1))),
        );
        await tick();
        expect(points, hasLength(2));
      } finally {
        await subscription.cancel();
        expect(running, false);
        await fixture.close();
      }
    },
  );
}
