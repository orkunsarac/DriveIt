import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
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
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/foreground_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/drive_route_projection.dart';
import 'package:driveit_project/services/owned_drive_finalization.dart';
import 'package:driveit_project/services/owner_drive_sync_client.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'package:driveit_project/main.dart' as app;
import 'package:driveit_project/services/device_drive_archive.dart';
import 'package:driveit_project/services/local_source_writer_fence.dart';
import 'package:driveit_project/models/route_point.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/screens/device_drive_archive_screen.dart';
import 'package:driveit_project/widgets/owner_personal_navigator.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'group_gps_sharing_test.dart' show FakeBackgroundGroupGps;

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
  HiveImpl? archiveHive;
  bool runtimeOpen = false;
  int storesOpened = 0;
  OwnerSyncRemoteAdapter? fakeSyncRemote;

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

  Future<void> boot({
    bool application = false,
    Future<LocalOwnerAuth> Function()? restoreAuth,
    Future<bool> Function()? confirmGuest,
    DeviceArchiveAuthorizer? archiveAuthorizer,
    Future<Set<String>> Function()? unfinishedArchiveDrives,
    void Function(Widget)? mountApplication,
    bool omitForeground = false,
  }) async {
    final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
    final gate = LocalOwnershipGate.synthetic();
    final dependencies = ControlledOwnershipDependencies(
      descriptor: descriptor,
      databaseFactory: databaseFactoryFfiNoIsolate,
      restoreAuth: restoreAuth ?? () async => auth,
      producerRunning: () async => false,
      worldRoadMatching: RoadMatchingService(provider: matcher),
      openStore: (owner) {
        storesOpened++;
        return OwnerScopedLocalStore.open(
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
        );
      },
      attachForeground: (gps, descriptor) async {
        if (!omitForeground) {
          ForegroundService.attachForTesting(gps, descriptor);
        }
      },
      detachForeground: (gps) async {
        if (!omitForeground) await ForegroundService.detachForTesting(gps);
      },
      writerFence: application
          ? LocalSourceWriterFence(
              gate: gate,
              gpsBusy: () async => false,
              provenCategories: LocalSourceWriterFence.requiredCategories,
              sourceRoots: [root.path],
            )
          : null,
      fakeSyncRemote: fakeSyncRemote,
    );
    if (application) {
      await archiveHive?.close();
      archiveHive = HiveImpl()
        ..init('${root.path}/legacy')
        ..registerAdapter(DriveSessionAdapter())
        ..registerAdapter(RoutePointAdapter());
      final box = await archiveHive!.openBox<DriveSession>('drives');
      await box.put(
        'old',
        DriveSession(
          id: 'old',
          date: DateTime.utc(2026, 9, 28),
          distance: 1000,
          durationSeconds: 100,
          averageSpeed: 36,
          maxSpeed: 40,
          mapImagePath: '',
          route: [RoutePoint(latitude: 40, longitude: 30)],
        ),
      );
      await box.flush();
      runtime = (await app.startDriveIt(
        gate: gate,
        controlled: dependencies,
        archiveSource: SavedDriveArchiveSource(box),
        unfinishedArchiveDrives: unfinishedArchiveDrives ?? () async => {},
        confirmGuest: confirmGuest ?? () async => true,
        archiveAuthorizer: archiveAuthorizer,
        mountApplication: mountApplication ?? runApp,
      ))!;
    } else {
      runtime = (await LocalOwnershipBootstrap.run(
        gate: gate,
        legacyBootstrap: () async => fail('Shared storage fallback'),
        controlled: dependencies,
      ))!;
    }
    runtimeOpen = true;
    if (!application) await ForegroundService.init();
  }

  Future<void> closeRuntime() async {
    if (!runtimeOpen) return;
    await runtime.closeAfterProducerDetached();
    runtimeOpen = false;
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

  Future<void> save(DriveSession drive) async {
    await DriveStorageService.saveDrive(
      drive,
      acquisitionMetadata: {'sessionId': drive.id},
    );
    await runtime.owner.syncSettled;
    await runtime.owner.worldSettled;
  }

  Future<void> close() async {
    failGroup = null;
    failCompletion = false;
    await closeRuntime();
    await auth.events.close();
    await archiveHive?.close();
    FlutterForegroundTask.skipServiceResponseCheck = previousSkip;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  }
}

class DeliveryMatcher implements RoadMatchingProvider {
  Completer<void>? hold;
  bool fail = false;
  bool retry = false;
  int calls = 0;
  @override
  String get providerId => 'synthetic-only';
  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    calls++;
    await hold?.future;
    if (fail) throw StateError('Synthetic World provider failure');
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

class DeliveryArchiveAuthorizer implements DeviceArchiveAuthorizer {
  @override
  Future<bool> verifyDeviceAccess() async => true;
}

class DeliverySyncRemote
    implements OwnerSyncRemoteAdapter, OwnerSyncDownloadAdapter {
  bool failNext = false;
  Completer<void>? holdNext;
  Completer<void>? enteredNext;
  final Map<String, OwnerSyncMutation> records = {};
  final List<String> calls = [];
  final List<OwnerSyncRemoteChange> _changes = [];
  OwnerSyncMutation? forcedDownloadMutation;

  @override
  Future<OwnerSyncReceipt> apply(OwnerSyncMutation mutation) async {
    calls.add(mutation.idempotencyKey);
    final entered = enteredNext;
    enteredNext = null;
    if (entered != null && !entered.isCompleted) entered.complete();
    final hold = holdNext;
    holdNext = null;
    await hold?.future;
    if (failNext) {
      failNext = false;
      throw const OwnerSyncTransportFailure('offline');
    }
    final previous = records[mutation.idempotencyKey];
    if (previous != null &&
        previous.payloadFingerprint != mutation.payloadFingerprint) {
      throw const OwnerSyncConflict('remote_payload_conflict');
    }
    if (!records.containsKey(mutation.idempotencyKey)) {
      records[mutation.idempotencyKey] = mutation;
      _changes.add(
        OwnerSyncRemoteChange(
          cursor: '${_changes.length + 1}',
          mutation: mutation,
        ),
      );
    }
    return OwnerSyncReceipt(
      ownerScope: mutation.ownerScope,
      idempotencyKey: mutation.idempotencyKey,
      payloadFingerprint: mutation.payloadFingerprint,
      remoteId: 'remote:${mutation.idempotencyKey}',
    );
  }

  @override
  Future<OwnerSyncDownloadPage> download({
    required String ownerId,
    required String afterCursor,
    required int limit,
  }) async {
    final filtered = _changes
        .where(
          (change) =>
              int.parse(change.cursor) >
                  int.parse(afterCursor.isEmpty ? '0' : afterCursor) &&
              change.mutation.ownerId == ownerId,
        )
        .take(limit)
        .toList(growable: false);
    final forced = forcedDownloadMutation;
    if (forced != null) {
      forcedDownloadMutation = null;
      return OwnerSyncDownloadPage(
        ownerId: ownerId,
        fromCursor: afterCursor,
        nextCursor: afterCursor.isEmpty ? '0' : afterCursor,
        changes: [OwnerSyncRemoteChange(cursor: 'forced', mutation: forced)],
      );
    }
    final next = filtered.length == limit
        ? filtered.last.cursor
        : '${_changes.length}';
    return OwnerSyncDownloadPage(
      ownerId: ownerId,
      fromCursor: afterCursor,
      nextCursor: next,
      changes: filtered,
    );
  }
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
    'main entry OFF preserves legacy bootstrap without owner dependencies',
    () async {
      var legacy = 0;
      final result = await app.startDriveIt(
        legacyBootstrap: () async {
          legacy++;
        },
      );
      expect(result, isNull);
      expect(legacy, 1);
      expect(LocalOwnershipGate.production.enabled, false);
    },
  );

  test('main entry ON rejects missing composition', () async {
    await expectLater(
      app.startDriveIt(gate: LocalOwnershipGate.synthetic()),
      throwsStateError,
    );
  });

  test(
    'application refuses an unbound foreground before inspecting shared journal',
    () async {
      await f.closeRuntime();
      await expectLater(
        f.boot(application: true, omitForeground: true),
        throwsStateError,
      );
      expect(ForegroundService.controlledOwnerBridge, null);
    },
  );

  testWidgets(
    'Auth restore precedes store opening; restore failure never becomes guest',
    (tester) async {
      await tester.runAsync(f.closeRuntime);
      final before = f.storesOpened;
      await tester.runAsync(() async {
        final restored = Completer<LocalOwnerAuth>();
        final restoreEntered = Completer<void>();
        final boot = f.boot(
          application: true,
          restoreAuth: () {
            restoreEntered.complete();
            return restored.future;
          },
        );
        await restoreEntered.future;
        expect(f.storesOpened, before);
        restored.complete(f.auth);
        await boot;
      });
      await tester.pump();
      expect(f.storesOpened, before + 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.closeRuntime);
      final count = f.storesOpened;
      await tester.runAsync(() async {
        await expectLater(
          f.boot(
            application: true,
            restoreAuth: () async =>
                throw StateError('Synthetic restore failure'),
          ),
          throwsStateError,
        );
      });
      expect(f.storesOpened, count);
    },
  );

  testWidgets('explicit guest choice and root guest A B A isolation', (
    tester,
  ) async {
    await tester.runAsync(f.closeRuntime);
    f.auth.emit(null);
    final before = f.storesOpened;
    await tester.runAsync(() async {
      await expectLater(
        f.boot(application: true, confirmGuest: () async => false),
        throwsStateError,
      );
    });
    expect(f.storesOpened, before);
    await tester.runAsync(() => f.boot(application: true));
    await tester.pump();
    expect(find.textContaining('Misafir sürüşleri bu cihazda'), findsOneWidget);
    late DriveSession guest;
    await tester.runAsync(() async {
      guest = await f.record(intervals: 2);
      await f.save(guest);
    });
    for (final id in [a, b, a]) {
      await tester.runAsync(() async {
        f.auth.emit(id);
        await f.runtime.owner.settled;
      });
      await tester.pump();
      expect(f.runtime.owner.lease.drives(), isEmpty);
      expect(
        () => f.runtime.owner.lease.requireDrive(guest.id),
        throwsStateError,
      );
    }
    await tester.runAsync(() async {
      f.auth.emit(null);
      await f.runtime.owner.settled;
    });
    await tester.pump();
    expect(f.runtime.owner.lease.drives().single.id, guest.id);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unfinished legacy journal blocks activation before opening owner store',
    (tester) async {
      await tester.runAsync(f.closeRuntime);
      final before = f.storesOpened;
      await tester.runAsync(() async {
        await expectLater(
          f.boot(
            application: true,
            unfinishedArchiveDrives: () async => {'old-unassigned-session'},
          ),
          throwsStateError,
        );
      });
      expect(f.storesOpened, before);
    },
  );

  test(
    'slow World never delays verified History save or source receipt',
    () async {
      final drive = await f.record();
      f.matcher.hold = Completer<void>();
      try {
        await DriveStorageService.saveDrive(
          drive,
          acquisitionMetadata: {'sessionId': drive.id},
        );
        expect(f.runtime.owner.lease.drives().single.id, drive.id);
        expect(await f.runtime.gps.journal.active(), isNull);
        expect(f.runtime.owner.lease.career().totalDistanceMeters, 6000);
      } finally {
        f.matcher.hold!.complete();
      }
      await f.runtime.owner.worldSettled;
      expect(
        (await f.runtime.owner.lease.worldSnapshot())!.traces,
        hasLength(1),
      );
    },
  );

  test(
    'World worker exception preserves completed History and durable retry',
    () async {
      final drive = await f.record();
      f.matcher.fail = true;
      await f.save(drive);
      expect(f.runtime.owner.lease.drives(), hasLength(1));
      expect(await f.runtime.gps.journal.active(), isNull);
      expect(f.runtime.owner.worldErrorCode, 'owner_world_retry_pending');
      f.matcher.fail = false;
      await f.runtime.owner.lease.drainWorldJobs();
      await f.save(drive);
      expect(f.runtime.owner.lease.drives(), hasLength(1));
      expect(f.runtime.owner.lease.career().totalDistanceMeters, 6000);
    },
  );

  test(
    'real finalization queues once; fake worker retries across A B A while World fails',
    () async {
      f.matcher.fail = true;
      final drive = await f.record();
      await f.save(drive);

      final leaseA = f.runtime.owner.lease;
      expect(leaseA.drives().single.id, drive.id);
      expect(f.runtime.owner.worldErrorCode, 'owner_world_retry_pending');
      expect(leaseA.pendingSyncKeys(), hasLength(1));
      final key = leaseA.pendingSyncKeys().single;
      final remote = DeliverySyncRemote()..failNext = true;
      final workerA = leaseA.syncWorker(remote);
      final offline = await workerA.runOnce();
      expect(offline.notAcknowledged, 1);
      expect(leaseA.syncRecord(key)!['state'], 'retryableFailure');

      // Hold the remote response while Auth changes. The old lease must not
      // apply its result to B; the remote idempotency key remains reusable.
      final entered = Completer<void>();
      final release = Completer<void>();
      remote.enteredNext = entered;
      remote.holdNext = release;
      final staleResult = workerA.runOnce();
      await entered.future;
      f.auth.emit(b);
      await f.runtime.owner.settled;
      await f.runtime.owner.syncSettled;
      final leaseB = f.runtime.owner.lease;
      expect(leaseB.drives(), isEmpty);
      expect(leaseB.pendingSyncKeys(), isEmpty);
      release.complete();
      await expectLater(staleResult, throwsStateError);

      f.auth.emit(a);
      await f.runtime.owner.settled;
      await f.runtime.owner.syncSettled;
      final returnedA = f.runtime.owner.lease;
      expect(returnedA.drives().single.id, drive.id);
      expect(returnedA.pendingSyncKeys(), [key]);
      final workerReturnedA = returnedA.syncWorker(remote);
      final retry = await workerReturnedA.runOnce();
      expect(retry.acknowledged, 1);
      expect(remote.records, hasLength(1));
      expect(remote.calls, [key, key, key]);
      expect(returnedA.syncRecord(key)!['state'], 'acknowledged');
      expect(returnedA.pendingSyncKeys(), isEmpty);
      expect((await workerReturnedA.runOnce()).attempted, 0);
      expect(returnedA.career().totalDistanceMeters, 6000);
    },
  );

  test(
    'two synthetic devices auto-retry and pull one proven drive without owner leakage',
    () async {
      await f.closeRuntime();
      final remote = DeliverySyncRemote()..failNext = true;
      f.fakeSyncRemote = remote;
      await f.boot();
      f.matcher.fail = true;

      final drive = await f.record();
      await f.save(drive);
      final sourceIdentity = (await f.runtime.gps.requireBinding(
        drive.id,
      )).provenance.sourceIdentity;
      await f.runtime.owner.syncSettled;
      expect(f.runtime.owner.lease.drives(), hasLength(1));
      expect(f.runtime.owner.worldErrorCode, 'owner_world_retry_pending');
      expect(remote.calls, hasLength(1));
      expect(remote.records, isEmpty);
      expect(f.runtime.owner.syncErrorCode, 'owner_sync_retry_pending');
      final key = f.runtime.owner.lease.pendingSyncKeys().single;
      expect(
        f.runtime.owner.lease.syncRecord(key)!['state'],
        'retryableFailure',
      );

      // A resume is one lifecycle retry; it is not a polling loop.
      f.runtime.owner.onOwnerResumed();
      await f.runtime.owner.syncSettled;
      expect(remote.calls, hasLength(2));
      expect(remote.records, hasLength(1));
      expect(f.runtime.owner.lease.syncRecord(key)!['state'], 'acknowledged');

      final receiverRoot = await Directory.systemTemp.createTemp(
        'driveit_device2_sync_',
      );
      final receiverAuth = TestAuth();
      String? receiverFailGroup;
      final receiver = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: receiverAuth,
        openStore: (owner) => OwnerScopedLocalStore.open(
          root: receiverRoot.path,
          owner: owner,
          beforeFlush: (group) async {
            if (group == receiverFailGroup) {
              throw StateError('Synthetic receiver flush interruption');
            }
          },
        ),
        driveInProgress: () async => false,
      );
      try {
        await receiver.start();
        expect(receiver.state, LocalOwnerState.ready);
        receiverFailGroup = 'drive_telemetry';
        await expectLater(
          receiver.lease.downloadSync(remote),
          throwsStateError,
        );
        expect(receiver.lease.drives(), isEmpty);
        receiverFailGroup = null;
        final first = await receiver.lease.downloadSync(remote);
        expect(first.applied, 1);
        expect(receiver.lease.drives().single.id, drive.id);
        expect(receiver.lease.requireDrive(drive.id).route, hasLength(301));
        expect(receiver.lease.telemetry(drive.id)!.points, hasLength(301));
        expect(receiver.lease.score(drive.id), isNotNull);
        expect(
          receiver.lease.read<Map>(
            'drive_source_provenance_v1',
            drive.id,
          )!['sourceIdentity'],
          sourceIdentity,
        );

        final repeated = await receiver.lease.downloadSync(remote);
        expect(repeated.applied, 0);
        expect(receiver.lease.drives(), hasLength(1));

        final validMutation = remote.records.values.single;
        final incompletePayload = Map<String, dynamic>.from(
          validMutation.payload,
        )..remove('sourceProvenance');
        remote.forcedDownloadMutation = OwnerSyncMutation(
          version: validMutation.version,
          kind: validMutation.kind,
          ownerScope: validMutation.ownerScope,
          ownerId: validMutation.ownerId,
          idempotencyKey: validMutation.idempotencyKey,
          payloadFingerprint: validMutation.payloadFingerprint,
          sourceIdentity: validMutation.sourceIdentity,
          payload: incompletePayload,
        );
        await expectLater(
          receiver.lease.downloadSync(remote),
          throwsA(isA<OwnerSyncConflict>()),
        );
        expect(receiver.lease.drives(), hasLength(1));

        receiverAuth.emit(b);
        await receiver.settled;
        expect(receiver.lease.drives(), isEmpty);
        final wrongOwner = remote.records.values.single;
        remote.forcedDownloadMutation = wrongOwner;
        await expectLater(
          receiver.lease.downloadSync(remote),
          throwsA(isA<OwnerSyncConflict>()),
        );
        expect(receiver.lease.drives(), isEmpty);

        receiverAuth.emit(a);
        await receiver.settled;
        expect(receiver.lease.drives(), hasLength(1));
        final redelivery = await receiver.lease.downloadSync(remote);
        expect(redelivery.applied, 0);
        expect(receiver.lease.drives(), hasLength(1));
      } finally {
        await receiver.close();
        await receiverAuth.events.close();
        await receiverRoot.delete(recursive: true);
      }
    },
  );

  test('startup reconciliation repairs the Hive-to-outbox crash gap', () async {
    await f.closeRuntime();
    f.fakeSyncRemote = DeliverySyncRemote();
    await f.boot();
    f.failGroup = OwnerDriveSyncClient.boxName;
    final drive = await f.record();
    await f.save(drive);
    expect(f.runtime.owner.lease.drives().single.id, drive.id);
    expect(f.runtime.owner.syncErrorCode, 'owner_sync_queue_pending');

    // The synthetic outbox flush failure occurs after completed owner Hive
    // finalization. Reopen, clear only this temporary fixture's nondurable
    // outbox state, and verify startup discovers the missing queue item.
    f.failGroup = null;
    await f.closeRuntime();
    final interruptedStore = await OwnerScopedLocalStore.open(
      root: f.root.path,
      owner: GpsOwner.account(a),
    );
    final possibleRows = interruptedStore.keys(
      GpsOwner.account(a),
      OwnerDriveSyncClient.boxName,
    );
    for (final key in possibleRows) {
      await interruptedStore.remove(
        GpsOwner.account(a),
        OwnerDriveSyncClient.boxName,
        key,
      );
    }
    expect(
      interruptedStore.read<Map>(
        GpsOwner.account(a),
        OwnedDriveFinalization.group,
        drive.id,
      )?['state'],
      'completed',
    );
    await interruptedStore.close();

    await f.boot();
    await f.runtime.owner.syncSettled;
    final lease = f.runtime.owner.lease;
    expect(lease.drives().single.id, drive.id);
    expect(lease.pendingSyncKeys(), isEmpty);
    expect(
      lease.syncRecord(
        lease.keys(OwnerDriveSyncClient.boxName).single.toString(),
      )?['state'],
      'acknowledged',
    );
    expect(f.runtime.owner.syncErrorCode, isNull);
  });

  test(
    'completed History and pending World survive close/reopen and worker retry',
    () async {
      final drive = await f.record();
      f.matcher.retry = true;
      await f.save(drive);
      expect(
        f.runtime.owner.lease.read<Map>(
          OwnedDriveFinalization.group,
          drive.id,
        )?['worldQueued'],
        true,
      );
      await f.closeRuntime();
      f.matcher.retry = false;
      await f.boot();
      expect(f.runtime.owner.lease.drives().single.id, drive.id);
      expect(f.runtime.owner.lease.telemetry(drive.id)!.points, hasLength(301));
      f.runtime.owner.scheduleWorldJobs(f.runtime.owner.lease);
      await f.runtime.owner.worldSettled;
      expect(
        (await f.runtime.owner.lease.worldSnapshot())!.traces,
        hasLength(1),
      );
      expect(f.runtime.owner.lease.career().totalDistanceMeters, 6000);
      expect(f.runtime.owner.worldErrorCode, null);
    },
  );

  testWidgets(
    'application History archive detail map keeps legacy bytes unchanged',
    (tester) async {
      final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      try {
        await tester.runAsync(() async {
          await f.closeRuntime();
          await f.boot(
            application: true,
            archiveAuthorizer: DeliveryArchiveAuthorizer(),
          );
          await f.runtime.owner.worldSettled;
        });
        await tester.pump();
        final source = File(f.archiveHive!.box<DriveSession>('drives').path!);
        final before = await tester.runAsync(source.readAsBytes);
        tester
            .state<NavigatorState>(find.byType(Navigator).last)
            .pushNamed('/history');
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Cihazdaki Eski Sürüşler'));
          await f.runtime.owner.withOwnerOperation((_) async {});
        });
        await tester.pumpAndSettle();
        expect(find.byType(DeviceDriveArchiveScreen), findsOneWidget);
        await tester.tap(find.text('28.09.2026 00:00'));
        await tester.pumpAndSettle();
        expect(find.byType(DeviceDriveArchiveDetailScreen), findsOneWidget);
        await tester.tap(find.text('GPS Rota Haritası'));
        await tester.pumpAndSettle();
        expect(find.byType(DeviceDriveArchiveMapScreen), findsOneWidget);
        expect(await tester.runAsync(source.readAsBytes), before);
        expect(f.runtime.owner.lease.drives(), isEmpty);
        await tester.runAsync(() async {
          f.auth.emit(b);
          await f.runtime.owner.settled;
        });
        // New Home can show its animated first-use tour. Assert epoch removal
        // after the frame, rather than waiting for all user-driven animations.
        await tester.pump();
        expect(find.byType(DeviceDriveArchiveMapScreen), findsNothing);
        expect(f.runtime.owner.lease.drives(), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        maps.GoogleMapsFlutterPlatform.instance = oldMaps;
      }
    },
  );

  test(
    'application entry routes active owner session to recovery without archive capture',
    () async {
      late Widget application;
      final session = await ForegroundService.start();
      final binding = await f.runtime.gps.requireBinding(session.id);
      await f.closeRuntime();
      await f.boot(
        application: true,
        mountApplication: (widget) => application = widget,
      );
      // Capture only the rendering side effect; the shared entry performs the
      // real Auth/store/foreground/recovery composition before producing this app.
      expect((application as app.DriveItApp).ownerInitialRoute, '/drive');
      final recovered = await f.runtime.gps.requireBinding(session.id);
      expect(
        recovered.provenance.sourceIdentity,
        binding.provenance.sourceIdentity,
      );
    },
  );

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

  for (final group in ['drive_scores', 'career_contributions_v1']) {
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
    'World retry does not block save; durable job and exactly-once contribution',
    () async {
      final drive = await f.record();
      f.matcher.retry = true;
      await f.save(drive);
      expect(await f.runtime.gps.journal.active(), isNull);
      expect(f.runtime.owner.lease.drives(), hasLength(1));
      expect(f.runtime.owner.worldErrorCode, 'owner_world_retry_pending');
      expect(f.runtime.owner.lease.keys('my_world_pending_jobs'), hasLength(1));
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
    'active drive switches to group and returns to the same recorder; pause and stop are independent',
    (tester) async {
      final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
      final oldLocation = GeolocatorPlatform.instance;
      maps.GoogleMapsFlutterPlatform.instance = DeliveryMaps();
      GeolocatorPlatform.instance = DeliveryLocation();
      final source = FakeBackgroundGroupGps();
      final service = FakeGroupDriveService();
      final navigation = GlobalKey<NavigatorState>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        (call) async => call.method == 'requestPermissions'
            ? {for (final id in call.arguments as List) id: 1}
            : 1,
      );
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> frames() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
      }

      Future<void> click(Key key) async {
        final target = find.byKey(key);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await frames();
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: OwnerPersonalNavigator(
              runtime: f.runtime.owner,
              legacyChild: const SizedBox(),
              initialRoute: '/drive',
              navigatorKey: navigation,
              groupDriveService: service,
              groupGpsSourceFactory: () => source,
            ),
          ),
        );
        for (
          var i = 0;
          i < 20 && find.byType(MapScreen).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(() => ForegroundService.inspectRecovery());
          await frames();
        }
        expect(find.byType(MapScreen), findsOneWidget);
        final state = tester.state(find.byType(MapScreen)) as dynamic;
        await tester.runAsync(() => state.startDriving() as Future<void>);
        await frames();
        final session = await tester.runAsync(ForegroundService.activeSession);
        expect(session, isNotNull);
        expect(find.byKey(const Key('drive_open_group')), findsNothing);
        final member = service.forOwner(f.runtime.owner.lease);
        final activeGroup = await member.create();
        await member.startRide(activeGroup.id);
        await frames();
        // Membership alone is enough: GPS sharing is still off.
        await click(const Key('drive_open_group'));
        expect(find.text('Devam eden sürüş'), findsNothing);
        expect(find.byKey(const Key('group_go_to_drive')), findsOneWidget);
        await click(const Key('group_share_start'));
        await click(const Key('group_background_consent'));
        await click(const Key('group_consent_confirm'));
        expect(source.opens, 1);
        // Home must retain the recorder route underneath, not pop/dispose it.
        await click(const Key('group_back_home'));
        expect(source.cancels, 0);
        expect(
          (await tester.runAsync(ForegroundService.activeSession))!.id,
          session!.id,
        );
        await click(const Key('home_group_card'));
        await click(const Key('group_go_to_drive'));
        expect(identical(tester.state(find.byType(MapScreen)), state), true);
        expect(state.isDriving, true);
        expect(source.cancels, 0);
        // A notification opens the same named group route without arguments.
        navigation.currentState!.pushNamed('/group');
        await frames();
        await click(const Key('group_go_to_drive'));
        expect(identical(tester.state(find.byType(MapScreen)), state), true);
        expect(source.opens, 1);
        final elapsed = state.elapsedSeconds as int;
        // startDriving ran in runAsync for its real countdown; its timers
        // therefore use real time rather than the widget fake clock.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
        await frames();
        expect(state.elapsedSeconds, greaterThan(elapsed));
        await click(const Key('drive_open_group'));
        await click(const Key('group_share_pause'));
        expect(source.cancels, 1);
        final current = await tester.runAsync(ForegroundService.activeSession);
        expect(current!.id, session.id);
        expect(current.state, 'recording');
        await click(const Key('group_go_to_drive'));
        expect(identical(tester.state(find.byType(MapScreen)), state), true);
        // Normal back retains its real save/exit warning.
        unawaited(navigation.currentState!.maybePop());
        await frames();
        expect(find.text('Devam eden sürüş'), findsOneWidget);
        await tester.tap(find.text('Sürüşe dön'));
        await frames();
        // Resume reuses the explicit approval for this same membership.
        await click(const Key('drive_open_group'));
        await click(const Key('group_share_start'));
        expect(find.byKey(const Key('group_consent_confirm')), findsNothing);
        expect(source.opens, 2);
        await click(const Key('group_go_to_drive'));
        await tester.runAsync(() async {
          unawaited(state.stopDriving() as Future<void>);
        });
        for (var i = 0; i < 30 && state.isDriving == true; i++) {
          await tester.runAsync(ForegroundService.inspectRecovery);
          await frames();
        }
        expect(state.isDriving, false);
        expect(
          source.cancels,
          1,
          reason: 'Recording stop must retain group GPS',
        );
        final stopped = await tester.runAsync(
          () => f.runtime.gps.journal.session(session.id),
        );
        expect(stopped!.state, 'stopped');
        expect(find.byKey(const Key('drive_open_group')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await frames();
        await service.close();
        await source.stream.close();
        maps.GoogleMapsFlutterPlatform.instance = oldMaps;
        GeolocatorPlatform.instance = oldLocation;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          null,
        );
      }
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
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await f.runtime.closeAfterProducerDetached();
          await f.boot(application: true);
        });
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
        await tester.runAsync(() => f.runtime.owner.worldSettled);
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
