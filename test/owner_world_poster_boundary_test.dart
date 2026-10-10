import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:driveit_project/screens/my_world_map_screen.dart';
import 'package:driveit_project/screens/world_trace_detail_screen.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
import 'package:driveit_project/features/my_world/models/world_map_read_model.dart';
import 'package:driveit_project/features/my_world/services/my_world_settings_service.dart';
import 'package:driveit_project/features/my_world/services/world_trace_detail_service.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/legacy_asset_transfer.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/services/my_world_rebuild_service.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/drive_poster/poster_store.dart';
import 'package:driveit_project/features/drive_poster/poster_screens.dart';
import 'package:driveit_project/features/drive_poster/poster_background.dart';
import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'local_lifecycle_foundation_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late TestAuth auth;
  late LocalOwnerLifecycle runtime;
  late OwnerScopedLocalStore store;
  late maps.GoogleMapsFlutterPlatform originalMaps;
  late _Maps mapPlatform;
  late _NoNetworkProvider provider;
  Future<void> switchTo(String? id) async {
    auth.emit(id);
    await runtime.settled;
  }

  LocalSourceBundle source() {
    final f = fixtures.fixture('same');
    final r = f.roads.single;
    final road = ValidatedRoad(
      id: r.id,
      driveSessionId: r.driveSessionId,
      geometry: r.geometry,
      sections: r.sections,
      validDistanceMeters: r.validDistanceMeters,
      status: r.status,
      validatedAt: r.validatedAt,
      providerId: r.providerId,
      confidence: r.confidence,
      processingVersion: MyWorldRules.validatedRoadProcessingVersion,
      directionKey: r.directionKey,
      averageHeadingDegrees: r.averageHeadingDegrees,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
    return LocalSourceBundle(
      drive: f.drive,
      score: f.score,
      telemetry: f.telemetry,
      roads: [road],
      ownerScope: runtime.lease.owner.targetStore,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'driveit_world_poster_synthetic_',
    );
    auth = TestAuth();
    originalMaps = maps.GoogleMapsFlutterPlatform.instance;
    mapPlatform = _Maps();
    maps.GoogleMapsFlutterPlatform.instance = mapPlatform;
    provider = _NoNetworkProvider();
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      driveInProgress: () async => false,
      worldRoadMatching: RoadMatchingService(provider: provider),
      openStore: (owner) async {
        store = await OwnerScopedLocalStore.open(root: root.path, owner: owner);
        return store;
      },
    );
    await runtime.start();
  });
  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await root.delete(recursive: true);
    maps.GoogleMapsFlutterPlatform.instance = originalMaps;
  });
  Future<void> prepare() async =>
      store.repositories(store.owner).prepareSource(source());

  test(
    'World trace deletion preserves History Career and other owner',
    () async {
      await prepare();
      final bundle = source();
      await store.repositories(store.owner).prepareCareerBaseline([
        bundle,
      ], fixtures.totals([bundle]));
      await runtime.lease.put('drives', 'same', bundle.drive);
      await runtime.lease.rebuildWorld();
      final id = (await runtime.lease.worldSnapshot())!.traces.single.id;
      final careerBefore = runtime.lease.career().totalDistanceMeters;
      await switchTo(b);
      await prepare();
      await runtime.lease.rebuildWorld();
      await switchTo(a);
      await runtime.lease.deleteWorldTrace(id);
      expect(runtime.lease.requireDrive('same').id, 'same');
      expect(runtime.lease.career().totalDistanceMeters, careerBefore);
      expect((await runtime.lease.worldMap()).traces, isEmpty);
      await runtime.lease.enqueueWorldDrive('same');
      await runtime.lease.drainWorldJobs();
      expect(provider.calls, 0);
      expect((await runtime.lease.worldMap()).traces, isEmpty);
      await switchTo(b);
      expect((await runtime.lease.worldMap()).traces.single.trace.id, id);
    },
  );

  test(
    'History deletion keeps independent World detail source and Career',
    () async {
      await prepare();
      final bundle = source();
      await store.repositories(store.owner).prepareCareerBaseline([
        bundle,
      ], fixtures.totals([bundle]));
      await runtime.lease.put('drives', 'same', bundle.drive);
      await runtime.lease.rebuildWorld();
      final id = (await runtime.lease.worldSnapshot())!.traces.single.id;
      final generation = (await runtime.lease.worldSnapshot())!.generation;
      await runtime.lease.deleteHistory('same');
      expect(runtime.lease.drives(), isEmpty);
      expect((await runtime.lease.worldSnapshot())!.generation, generation);
      expect((await runtime.lease.worldTraceDetail(id))!.drive.id, 'same');
      expect(runtime.lease.career().drives, hasLength(1));
    },
  );

  test(
    'pending validated road reuse stays owner scoped and makes no network call',
    () async {
      await prepare();
      await runtime.lease.enqueueWorldDrive('same');
      await runtime.lease.drainWorldJobs();
      expect(provider.calls, 0);
      expect((await runtime.lease.worldMap()).traces, hasLength(1));
      expect(await runtime.lease.worldPendingJobs(), isEmpty);
      await switchTo(b);
      expect((await runtime.lease.worldSnapshot())!.generation, 0);
    },
  );

  test(
    'deletion queued with pending processing cannot resurrect trace',
    () async {
      await prepare();
      await runtime.lease.rebuildWorld();
      final id = (await runtime.lease.worldSnapshot())!.traces.single.id;
      await runtime.lease.enqueueWorldDrive('same');
      await Future.wait([
        runtime.lease.drainWorldJobs(),
        runtime.lease.deleteWorldTrace(id),
      ]);
      expect((await runtime.lease.worldMap()).traces, isEmpty);
      await runtime.lease.drainWorldJobs();
      expect((await runtime.lease.worldMap()).traces, isEmpty);
    },
  );

  test('direct trace ID from another owner is unavailable', () async {
    await prepare();
    await runtime.lease.rebuildWorld();
    final id = (await runtime.lease.worldSnapshot())!.traces.single.id;
    await switchTo(b);
    expect(await runtime.lease.resolveWorldTrace(id), null);
    expect(await runtime.lease.worldTraceDetail(id), null);
    await expectLater(runtime.lease.deleteWorldTrace(id), throwsStateError);
  });

  test(
    'persisted intent before rebuild hides trace and retries idempotently',
    () async {
      await prepare();
      await runtime.lease.rebuildWorld();
      final id = (await runtime.lease.worldSnapshot())!.traces.single.id;
      final priorGeneration = (await runtime.lease.worldSnapshot())!.generation;
      await runtime.lease.put('local_lifecycle_v1', 'worldTrace:$id', {
        'version': 1,
        'state': 'prepared',
        'sourceId': 'same',
        'roadId': source().roads.single.id,
        'sectionId': source().roads.single.sections.single.id,
        'start': 0.0,
        'end': 6000.0,
      });
      expect((await runtime.lease.worldMap()).traces, isEmpty);
      expect(
        (await runtime.lease.worldSnapshot())!.generation,
        priorGeneration,
      );
      await runtime.lease.drainWorldJobs();
      final generation = (await runtime.lease.worldSnapshot())!.generation;
      expect(
        runtime.lease.read<Map>(
          'local_lifecycle_v1',
          'worldTrace:$id',
        )!['state'],
        'completed',
      );
      await runtime.lease.deleteWorldTrace(id);
      expect((await runtime.lease.worldSnapshot())!.generation, generation);
    },
  );

  testWidgets(
    'gate OFF injectable legacy World still renders without scoped migration',
    (tester) async {
      const empty = MyWorldMapData(
        snapshotGeneration: 0,
        traces: [],
        totalActiveDistanceMeters: 0,
        processedDriveCount: 0,
        processedDriveSessionIds: [],
        skippedBrokenTraceCount: 0,
        viewport: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MyWorldMapScreen(
            loadData: () async => empty,
            settingsStore: MemoryMyWorldSettingsStore(skipIntroAnimation: true),
            detailService: WorldTraceDetailService(
              driveLoader: (_) => null,
              scoreLoader: (_) => null,
              activeDistanceLoader: (_) async => 0,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('owner map ignores global injection and clears on epoch revoke', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await prepare();
      await runtime.lease.rebuildWorld();
    });
    final lease = runtime.lease;
    await tester.runAsync(
      () =>
          runtime.lease.put('my_world_settings', 'skip_intro_animation', true),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyWorldMapScreen(
          ownerLease: lease,
          loadData: () => throw StateError('global fallback'),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump();
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(
      map.polylines.where((p) => p.polylineId.value.startsWith('world_core:')),
      hasLength(1),
    );
    final oldCameraCallback = map.onCameraMove!;
    // A tombstone changes visibility even if the generation did not change.
    await tester.runAsync(() async {
      final snapshot = (await lease.worldSnapshot())!;
      final trace = snapshot.traces.single;
      await lease.put('local_lifecycle_v1', 'worldTrace:${trace.id}', {
        'version': 1,
        'state': 'completed',
        'sourceId': trace.sourceDriveSessionId,
        'roadId': trace.validatedRoadId,
        'sectionId': trace.matchedSectionId,
        'start': trace.startOffsetMeters,
        'end': trace.endOffsetMeters,
      });
      await lease.drainWorldJobs();
      await Future<void>.delayed(Duration.zero);
      expect((await lease.worldSnapshot())!.generation, snapshot.generation);
    });
    await tester.pump();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines, isEmpty);
    await tester.runAsync(() => switchTo(b));
    oldCameraCallback(const CameraPosition(target: LatLng(1, 1)));
    await tester.pump();
    expect(find.byType(GoogleMap), findsNothing);
    expect(
      find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
    await tester.pumpWidget(
      MaterialApp(
        home: MyWorldMapScreen(
          key: ValueKey(runtime.lease.epoch),
          ownerLease: runtime.lease,
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('direct foreign World detail is fail closed without a map', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OwnedWorldTraceDetailScreen(
          lease: runtime.lease,
          traceId: 'foreign',
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.byType(GoogleMap), findsNothing);
    expect(
      find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'known World detail survives History deletion and revokes on owner switch',
    (tester) async {
      late String id;
      await tester.runAsync(() async {
        await prepare();
        final bundle = source();
        await store.repositories(store.owner).prepareCareerBaseline([
          bundle,
        ], fixtures.totals([bundle]));
        await runtime.lease.put('drives', 'same', bundle.drive);
        await runtime.lease.rebuildWorld();
        id = (await runtime.lease.worldSnapshot())!.traces.single.id;
        await runtime.lease.deleteHistory('same');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OwnedWorldTraceDetailScreen(lease: runtime.lease, traceId: id),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(find.text('İz Detayı'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('view_full_drive_button')),
            )
            .onPressed,
        null,
      );
      await tester.runAsync(() => switchTo(b));
      await tester.pump();
      expect(find.byType(GoogleMap), findsNothing);
      expect(
        find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  PosterSaveRequest request({String? background}) => PosterSaveRequest(
    driveId: 'same',
    png: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]),
    backgroundSourceType: PosterBackgroundSourceType.customImage,
    backgroundPath: background,
    startLabel: 'start',
    endLabel: 'end',
    showMaxSpeed: true,
  );

  test('World rebuild and generation remain scoped through A B A', () async {
    await prepare();
    expect((await runtime.lease.rebuildWorld()).success, true);
    expect((await runtime.lease.worldSnapshot())!.generation, 1);
    expect((await runtime.lease.worldMap()).traces, hasLength(1));
    await switchTo(b);
    expect(await runtime.lease.worldRoads(), isEmpty);
    expect((await runtime.lease.worldSnapshot())!.generation, 0);
    expect(await runtime.lease.worldDetails().load('same'), null);
    await switchTo(a);
    expect((await runtime.lease.worldSnapshot())!.generation, 1);
    expect(
      (await runtime.lease.worldMap()).traces.single.trace.distanceMeters,
      6000,
    );
  });
  test('same source ID and trace ID are independent across owners', () async {
    await prepare();
    await runtime.lease.rebuildWorld();
    final aTrace = (await runtime.lease.worldSnapshot())!.traces.single.id;
    await switchTo(b);
    await prepare();
    await runtime.lease.rebuildWorld();
    expect((await runtime.lease.worldSnapshot())!.traces.single.id, aTrace);
    await runtime.lease.put('local_lifecycle_v1', 'world:same', {
      'version': 1,
      'state': 'prepared',
    });
    expect((await runtime.lease.rebuildWorld()).resultingTraceCount, 0);
    await switchTo(a);
    expect((await runtime.lease.worldSnapshot())!.traces, hasLength(1));
  });
  test('pending jobs respect only this owner tombstone', () async {
    final job = WorldPendingJob.pending(
      driveSessionId: 'same',
      type: WorldJobType.validateRoad,
      now: DateTime.utc(2026),
    );
    expect(await store.worldSources(store.owner).enqueueIfAbsent(job), true);
    expect(await runtime.lease.worldPendingJobs(), hasLength(1));
    await switchTo(b);
    await runtime.lease.put('local_lifecycle_v1', 'world:same', {
      'version': 1,
      'state': 'prepared',
    });
    expect(await store.worldSources(store.owner).enqueueIfAbsent(job), false);
    await switchTo(a);
    expect(await runtime.lease.worldPendingJobs(), hasLength(1));
  });
  test('revoked World read cannot show old owner results', () async {
    await prepare();
    final lease = runtime.lease;
    final done = Completer<String>();
    final result = lease.load((_) => done.future);
    await switchTo(b);
    done.complete('old world');
    expect(await result, null);
    expect(() => lease.worldDetails(), throwsStateError);
  });
  test(
    'in-flight rebuild drains in A while B sees only B generation',
    () async {
      await prepare();
      final lease = runtime.lease;
      final fixedStore = store;
      final entered = Completer<void>(), release = Completer<void>();
      final sources = fixedStore
          .repositories(fixedStore.owner)
          .rebuildSources();
      final lifecycle = ScopedLifecycle(fixedStore);
      final service = MyWorldRebuildService(
        repository: fixedStore.worldSources(fixedStore.owner),
        indexRepository: fixedStore.worldIndex(fixedStore.owner),
        driveLoader: () async => sources.map((s) => s.drive).toList(),
        telemetryLoader: (id) async => sources.single.telemetry!.points,
        worldDeleted: lifecycle.worldDeleted,
        traceFilter: lifecycle.filterTraces,
      );
      final processing = lease.run(() async {
        entered.complete();
        await release.future;
        return service.rebuild(targetVersion: DriveScoreAlgorithmVersion.v1);
      });
      await entered.future;
      auth.emit(b);
      expect(lease.isCurrent, false);
      release.complete();
      expect((await processing).success, true);
      await runtime.settled;
      expect((await runtime.lease.worldSnapshot())!.generation, 0);
      await switchTo(a);
      expect((await runtime.lease.worldSnapshot())!.generation, 1);
    },
  );
  test(
    'queued rebuild is rejected after external Auth invalidates admission',
    () async {
      await prepare();
      final lease = runtime.lease;
      final result = lease.rebuildWorld();
      auth.emit(b);
      await expectLater(result, throwsStateError);
      await runtime.settled;
      expect(lease.isCurrent, false);
      expect((await runtime.lease.worldSnapshot())!.generation, 0);
      await switchTo(a);
      expect((await runtime.lease.worldSnapshot())!.generation, 0);
    },
  );
  test('poster store and metadata are owner scoped', () async {
    await runtime.lease.put('drives', 'same', source().drive);
    final posters = await runtime.lease.posters();
    final saved = await posters.save(request());
    expect(await posters.file(saved).exists(), true);
    await switchTo(b);
    expect((await runtime.lease.posters()).all, isEmpty);
    expect(() => posters.all, throwsStateError);
    await switchTo(a);
    expect((await runtime.lease.posters()).all.single.id, saved.id);
  });
  test('absolute cross-owner path and traversal are rejected', () async {
    await runtime.lease.put('drives', 'same', source().drive);
    final posters = await runtime.lease.posters();
    SavedDrivePoster forged(String file) => SavedDrivePoster(
      id: 'x',
      driveId: 'same',
      createdAt: DateTime.utc(2026),
      fileName: file,
      backgroundSourceType: PosterBackgroundSourceType.customImage,
      startLabel: '',
      endLabel: '',
      showMaxSpeed: true,
    );
    expect(
      () => posters.file(forged('${root.path}/other-owner.png')),
      throwsA(isA<ImportFailure>()),
    );
    expect(
      () => posters.file(forged('../other.png')),
      throwsA(isA<ImportFailure>()),
    );
  });
  test(
    'poster save after owner switch neither writes B nor falls back',
    () async {
      await runtime.lease.put('drives', 'same', source().drive);
      final posters = await runtime.lease.posters();
      await switchTo(b);
      await expectLater(posters.save(request()), throwsStateError);
      expect((await runtime.lease.posters()).all, isEmpty);
    },
  );
  test('missing authoritative drive blocks poster creation', () async {
    final posters = await runtime.lease.posters();
    await expectLater(posters.save(request()), throwsStateError);
    expect(posters.all, isEmpty);
  });
  testWidgets(
    'saved poster screen ignores global store injection and revokes',
    (tester) async {
      final lease = runtime.lease;
      await tester.runAsync(() => switchTo(b));
      await tester.pumpWidget(
        MaterialApp(
          home: SavedPostersScreen(
            ownerLease: runtime.lease,
            store: Completer<PosterStore>().future,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SavedPostersScreen(
            ownerLease: lease,
            store: Completer<PosterStore>().future,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Kişisel veri erişimi hazır değil. Veriler korunuyor.'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
    },
  );
}

class _NoNetworkProvider implements RoadMatchingProvider {
  int calls = 0;
  @override
  String get providerId => 'synthetic';
  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    calls++;
    throw StateError('Unexpected provider call');
  }
}

/// Rendering harness only: no native map or real location/network service.
class _Maps extends maps.GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    dynamic onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
    maps.MapObjects mapObjects = const maps.MapObjects(),
  }) => const SizedBox();
}
