import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:driveit_project/widgets/owner_personal_navigator.dart';
import 'package:driveit_project/screens/map_screen.dart';
import 'package:driveit_project/screens/history_screen.dart';
import 'package:driveit_project/screens/drive_detail_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/drive_route_projection.dart';
import 'package:driveit_project/services/owned_drive_finalization.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;

/// No main(), global Hive, real GPS or network. Real public foreground/save
/// entry points compose the same durable owner pipeline used by /drive.
class DeliveryFixture {
  late Directory root;
  late TestAuth auth;
  late ControlledOwnershipRuntime runtime;
  final matcher = DeliveryMatcher();
  String? failGroup;
  bool failCompletion = false;
  static const channel = MethodChannel('flutter_foreground_task/methods');
  bool previousSkip = false;

  Future<void> open() async {
    root = await Directory.systemTemp.createTemp('driveit_owner_test_');
    auth = TestAuth();
    SharedPreferences.setMockInitialValues({});
    previousSkip = FlutterForegroundTask.skipServiceResponseCheck;
    FlutterForegroundTask.skipServiceResponseCheck = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'isRunningService' ? false : null,
        );
    await boot();
  }

  Future<void> boot() async {
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    runtime = (await LocalOwnershipBootstrap.run(
      gate: LocalOwnershipGate.synthetic(),
      legacyBootstrap: () async => fail('Shared storage fallback'),
      controlled: ControlledOwnershipDependencies(
        descriptor: descriptor,
        databaseFactory: databaseFactoryFfiNoIsolate,
        restoreAuth: () async => auth,
        producerRunning: () async => false,
        worldRoadMatching: RoadMatchingService(provider: matcher),
        openStore: (owner) => OwnerScopedLocalStore.open(
          root: root.path,
          owner: owner,
          beforeFlush: (group) async {
            if (group == failGroup &&
                (group == 'drive_scores' ||
                    runtime.owner.lease.keys(group).isNotEmpty)) {
              throw StateError('Synthetic flush failure');
            }
            if (failCompletion &&
                group == OwnedDriveFinalization.group &&
                runtime.owner.lease
                    .keys(group)
                    .any(
                      (id) =>
                          runtime.owner.lease.read<Map>(group, id)?['state'] ==
                          'completed',
                    )) {
              throw StateError('Synthetic completion flush failure');
            }
          },
        ),
        attachForeground: (gps, descriptor) async =>
            ForegroundService.attachForTesting(gps, descriptor),
        detachForeground: ForegroundService.detachForTesting,
      ),
    ))!;
    await ForegroundService.init();
  }

  Future<DriveSession> record({int intervals = 300}) async {
    final session = await ForegroundService.start();
    return populate(session.id, session.startedAt, intervals: intervals);
  }

  Future<DriveSession> populate(
    String id,
    DateTime start, {
    int intervals = 300,
  }) async {
    final points = <CanonicalTelemetryPoint>[];
    for (var i = 0; i <= intervals; i++) {
      final point = CanonicalTelemetryPoint(
        latitude: 40 + i * .00018,
        longitude: 30,
        timestamp: start.add(Duration(seconds: i)),
        speedMps: 20,
        headingDegrees: 0,
        altitudeMeters: 10,
        accuracyMeters: 5,
        distanceFromPreviousMeters: i == 0 ? 0 : 20,
        accelerationMps2: 0,
        speedSource: 'native',
      );
      points.add(point);
      await runtime.gps.journal.append(id, i + 1, point);
    }
    await runtime.gps.journal.requestStop(id, at: points.last.timestamp);
    await ForegroundService.stop();
    final projection = DriveRouteProjection(points);
    return DriveSession(
      id: id,
      date: DateTime.utc(2026, 10, 11),
      distance: projection.distanceMeters,
      durationSeconds: intervals,
      averageSpeed: 72,
      maxSpeed: 72,
      mapImagePath: '',
      route: projection.route,
    );
  }

  Future<void> save(DriveSession drive) => DriveStorageService.saveDrive(
    drive,
    acquisitionMetadata: {'sessionId': drive.id},
  );

  Future<void> close() async {
    failGroup = null;
    failCompletion = false;
    await runtime.closeAfterProducerDetached();
    await auth.events.close();
    FlutterForegroundTask.skipServiceResponseCheck = previousSkip;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  }
}

class DeliveryMatcher implements RoadMatchingProvider {
  bool retry = false;
  int calls = 0;
  @override
  String get providerId => 'synthetic-only';
  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    calls++;
    if (retry) {
      return RoadMatchingResult.failure(
        kind: RoadMatchingFailureKind.network,
        message: 'Synthetic retry',
      );
    }
    final geometry = request.rawRoute
        .map(
          (p) => MatchedRoadPoint(latitude: p.latitude, longitude: p.longitude),
        )
        .toList();
    final distance = request.canonicalTelemetry.fold<double>(
      0,
      (sum, p) => sum + p.distanceFromPreviousMeters,
    );
    return RoadMatchingResult(
      sections: [
        MatchedRoadSection(
          id: '${request.driveSessionId}:section',
          geometry: geometry,
          distanceMeters: distance,
          confidence: 1,
          sourceTraceIndex: 0,
          sourceChunkIndex: 0,
        ),
      ],
      geometry: geometry,
      validDistanceMeters: distance,
      status: RoadValidationStatus.validated,
      confidence: 1,
      directionKey: 'forward',
      averageHeadingDegrees: 0,
      errorMessage: null,
    );
  }
}

class DeliveryMaps extends maps.GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) => const SizedBox();
}

class DeliveryLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 40,
    longitude: 30,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 5,
    heading: 0,
    headingAccuracy: 5,
    speed: 0,
    speedAccuracy: 5,
  );
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DeliveryFixture f;
  setUp(() async {
    f = DeliveryFixture();
    await f.open();
  });
  tearDown(() async => f.close());

  test(
    'public start/save: durable A History Score World Career, retry exactly once',
    () async {
      final drive = await f.record();
      final binding = await f.runtime.gps.requireBinding(drive.id);
      await f.save(drive);
      final lease = f.runtime.owner.lease;
      expect(lease.drives().single.route.length, 301);
      expect(lease.telemetry(drive.id)!.points.length, 301);
      expect(lease.requireDrive(drive.id).date, drive.date);
      expect(lease.score(drive.id), isNotNull);
      expect(lease.career().totalDistanceMeters, 6000);
      expect((await lease.worldSnapshot())!.traces, isNotEmpty);
      expect(
        await f.runtime.gps.ownership.verified(
          f.runtime.gps.journalId,
          drive.id,
        ),
        true,
      );
      await f.save(drive);
      expect(lease.drives(), hasLength(1));
      expect(lease.career().totalDistanceMeters, 6000);
      expect(
        lease
            .keys('career_contributions_v1')
            .where((k) => k.toString().startsWith('source:')),
        ['source:${binding.provenance.sourceIdentity}'],
      );
      expect(f.matcher.calls, 1);
      await ForegroundService.acknowledgeSaved(drive.id, drive.id);
    },
  );

  test(
    'A B A and guest: History World Career and posters stay scoped',
    () async {
      final aDrive = await f.record();
      await f.save(aDrive);
      f.auth.emit(b);
      await f.runtime.owner.settled;
      expect(f.runtime.owner.lease.drives(), isEmpty);
      expect(f.runtime.owner.lease.career().totalDistanceMeters, 0);
      expect(
        (await f.runtime.owner.lease.worldSnapshot())?.traces ?? [],
        isEmpty,
      );
      final bDrive = await f.record(intervals: 2);
      await f.save(bDrive);
      expect(f.runtime.owner.lease.drives().single.id, bDrive.id);
      f.auth.emit(a);
      await f.runtime.owner.settled;
      expect(f.runtime.owner.lease.drives().single.id, aDrive.id);
      expect(f.runtime.owner.lease.career().totalDistanceMeters, 6000);
      expect(
        () => f.runtime.owner.lease.requireDrive(bDrive.id),
        throwsStateError,
      );
      f.auth.emit(null);
      await f.runtime.owner.settled;
      final guest = await f.record(intervals: 2);
      await f.save(guest);
      f.auth.emit(a);
      await f.runtime.owner.settled;
      expect(f.runtime.owner.lease.drives().map((d) => d.id), [aDrive.id]);
    },
  );

  for (final group in [
    'drive_scores',
    'career_contributions_v1',
    'my_world_index_metadata',
  ]) {
    test(
      '$group write failure: stopped source retained, hidden partial History, retry',
      () async {
        final drive = await f.record();
        f.failGroup = group;
        await expectLater(f.save(drive), throwsStateError);
        expect((await f.runtime.gps.journal.active())!.id, drive.id);
        expect(f.runtime.owner.lease.drives(), isEmpty);
        expect(
          () => f.runtime.owner.lease.requireDrive(drive.id),
          throwsStateError,
        );
        expect(
          await f.runtime.gps.ownership.verified(
            f.runtime.gps.journalId,
            drive.id,
          ),
          false,
        );
        f.failGroup = null;
        await f.save(drive);
        expect(f.runtime.owner.lease.drives(), hasLength(1));
        expect(f.runtime.owner.lease.career().totalDistanceMeters, 6000);
      },
    );
  }

  test(
    'World retry is not successful save; journal/job retained without double contribution',
    () async {
      final drive = await f.record();
      f.matcher.retry = true;
      await expectLater(f.save(drive), throwsStateError);
      expect((await f.runtime.gps.journal.active())!.id, drive.id);
      expect(f.runtime.owner.lease.drives(), isEmpty);
      f.matcher.retry = false;
      await f.save(drive);
      expect(f.runtime.owner.lease.drives(), hasLength(1));
      expect(
        f.runtime.owner.lease
            .keys('career_contributions_v1')
            .where((k) => k.toString().startsWith('source:')),
        hasLength(1),
      );
    },
  );

  test('external Auth change never reassigns unfinished session', () async {
    final session = await ForegroundService.start();
    final binding = await f.runtime.gps.requireBinding(session.id);
    f.auth.emit(b);
    await f.runtime.owner.settled;
    expect(() => f.runtime.owner.lease, throwsStateError);
    expect(
      (await f.runtime.gps.requireBinding(session.id)).owner.targetStore,
      binding.owner.targetStore,
    );
    f.auth.emit(a);
    await f.runtime.owner.settled;
    await ForegroundService.verifyOwnerSession(
      f.runtime.owner.lease,
      session.id,
    );
    expect(
      (await f.runtime.gps.requireBinding(
        session.id,
      )).provenance.sourceIdentity,
      binding.provenance.sourceIdentity,
    );
  });

  test('empty evidence uses explicit N/A and does not run World', () async {
    final drive = await f.record(intervals: 0);
    await f.save(drive);
    expect(f.runtime.owner.lease.score(drive.id), null);
    expect(f.matcher.calls, 0);
    expect(
      f.runtime.owner.lease.read<Map>(
        OwnedDriveFinalization.group,
        drive.id,
      )!['state'],
      'completed',
    );
  });

  test(
    'completion flush failure after two receipts: hidden and reconciled, no new session',
    () async {
      final drive = await f.record(intervals: 2);
      f.failCompletion = true;
      await expectLater(f.save(drive), throwsStateError);
      expect(await f.runtime.gps.journal.active(), null);
      expect(f.runtime.owner.lease.drives(), isEmpty);
      await expectLater(ForegroundService.start(), throwsStateError);
      f.failCompletion = false;
      await ForegroundService.reconcileOwnerSaves(f.runtime.owner.lease);
      expect(f.runtime.owner.lease.drives().single.id, drive.id);
      expect(f.runtime.owner.lease.career().totalDistanceMeters, 40);
    },
  );

  test(
    'interrupted save reopen preserves source UUID, sequence, exact timestamp and retry',
    () async {
      final drive = await f.record(intervals: 2);
      final original = await f.runtime.gps.requireBinding(drive.id);
      f.failGroup = 'career_contributions_v1';
      await expectLater(f.save(drive), throwsStateError);
      f.failGroup = null;
      await f.runtime.closeAfterProducerDetached();
      await f.boot();
      expect(
        (await f.runtime.gps.requireBinding(
          drive.id,
        )).provenance.sourceIdentity,
        original.provenance.sourceIdentity,
      );
      expect(f.runtime.owner.lease.drives(), isEmpty);
      await f.save(drive);
      final journalPoints = await f.runtime.gps.journal.read(drive.id);
      final hivePoints = f.runtime.owner.lease.telemetry(drive.id)!.points;
      expect(
        hivePoints.map((p) => p.timestamp.microsecondsSinceEpoch),
        journalPoints.map((p) => p.point.timestamp.microsecondsSinceEpoch),
      );
      expect(f.runtime.owner.lease.career().totalDistanceMeters, 40);
    },
  );

  test(
    'headless recreation and stopped service continue keep source UUID',
    () async {
      final session = await ForegroundService.start();
      final original = await f.runtime.gps.requireBinding(session.id);
      final descriptor = await OwnedForegroundBootstrap.prepareForTesting(
        f.root,
      );
      await descriptor
          .forSession(
            session,
            original,
            ownerEpoch: f.runtime.owner.lease.epoch,
          )
          .verifyHandoff(databaseFactoryFfiNoIsolate, session.id);
      await ForegroundService.resumeRecording();
      expect((await ForegroundService.activeSession())!.id, session.id);
      expect(
        (await f.runtime.gps.requireBinding(
          session.id,
        )).provenance.sourceIdentity,
        original.provenance.sourceIdentity,
      );
      final drive = await f.populate(
        session.id,
        session.startedAt,
        intervals: 2,
      );
      await f.save(drive);
      expect(f.runtime.owner.lease.drives().single.id, session.id);
    },
  );

  testWidgets(
    '/drive UI start stop save -> owner History detail and route with Score World Career',
    (tester) async {
      final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
      final oldLocation = GeolocatorPlatform.instance;
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      GeolocatorPlatform.instance = DeliveryLocation();
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            permissions,
            (call) async => call.method == 'requestPermissions'
                ? {for (final id in call.arguments as List) id: 1}
                : 1,
          );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: OwnerPersonalNavigator(
              runtime: f.runtime.owner,
              legacyChild: const Text('legacy'),
            ),
          ),
        );
        await tester.pump();
        tester
            .state<NavigatorState>(find.byType(Navigator).last)
            .pushNamed('/drive');
        await tester.runAsync(() => ForegroundService.inspectRecovery());
        for (
          var i = 0;
          i < 15 && find.byType(MapScreen).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(() => ForegroundService.inspectRecovery());
          await tester.pump();
        }
        expect(find.byType(MapScreen), findsOneWidget);
        await tester.runAsync(() async {
          // Real production countdown is awaited; no test timeout is increased.
          final state = tester.state(find.byType(MapScreen)) as dynamic;
          // Exercise the genuine method bound to the visible start control.
          await state.startDriving();
        });
        await tester.pump();
        await tester.runAsync(() async {
          final active = await ForegroundService.activeSession();
          expect(active, isNotNull);
          await f.populate(active!.id, active.startedAt);
        });
        await tester.runAsync(() async {
          final state = tester.state(find.byType(MapScreen)) as dynamic;
          // Stop is the genuine screen action; don't await the dialog lifetime.
          unawaited(state.stopDriving() as Future<void>);
        });
        for (
          var i = 0;
          i < 30 && find.text('🏁 Sürüş Tamamlandı').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(() => ForegroundService.inspectRecovery());
          await tester.pump();
        }
        expect(find.text('🏁 Sürüş Tamamlandı'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('Sürüşü Kaydet').first);
          final active = await f.runtime.gps.journal.active();
          if (active != null) await f.runtime.gps.requireBinding(active.id);
          await f.runtime.owner.withOwnerOperation((_) async {});
        });
        for (
          var i = 0;
          i < 100 && f.runtime.owner.lease.drives().isEmpty;
          i++
        ) {
          await tester.runAsync(() => ForegroundService.inspectRecovery());
          await tester.pump();
        }
        expect(
          f.runtime.owner.lease.keys('drives'),
          isNotEmpty,
          reason: 'UI save must enter primary owner sink',
        );
        expect(f.runtime.owner.lease.drives(), hasLength(1));
        final drive = f.runtime.owner.lease.drives().single;
        expect(f.runtime.owner.lease.score(drive.id), isNotNull);
        expect(f.runtime.owner.lease.career().totalDistanceMeters, 6000);
        expect(
          await tester.runAsync(() => f.runtime.owner.lease.worldSnapshot()),
          isNotNull,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: HistoryScreen(
              ownerLease: f.runtime.owner.lease,
              ownedDetailBuilder: (lease, id) =>
                  OwnedDriveDetailScreen(lease: lease, driveId: id),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(HistoryScreen), findsOneWidget);
        await tester.pumpWidget(
          MaterialApp(
            home: OwnedDriveDetailScreen(
              lease: f.runtime.owner.lease,
              driveId: drive.id,
            ),
          ),
        );
        await tester.runAsync(() async => await Future<void>.value());
        await tester.pump();
        expect(find.byType(DriveDetailScreen), findsOneWidget);
        expect(
          f.runtime.owner.lease.requireDrive(drive.id).route,
          hasLength(301),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        maps.GoogleMapsFlutterPlatform.instance = oldMaps;
        GeolocatorPlatform.instance = oldLocation;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(permissions, null);
      }
    },
  );
}
