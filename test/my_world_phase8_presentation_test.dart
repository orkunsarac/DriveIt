import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/models/world_map_read_model.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_index_repository.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_repository.dart';
import 'package:driveit_project/features/my_world/services/geo_distance.dart';
import 'package:driveit_project/features/my_world/services/my_world_read_service.dart';
import 'package:driveit_project/features/my_world/services/world_trace_geometry_resolver.dart';
import 'package:driveit_project/features/my_world/services/world_trace_visual_variants.dart';
import 'package:driveit_project/screens/world_mode_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = WorldTraceGeometryResolver();

  group('Phase 8 active trace geometry', () {
    test('full section resolves its complete ordered geometry', () {
      final road = _road('road-a', 'drive-a');
      final geometry = resolver.resolve(
        trace: _trace(
          road: road,
          id: 'full',
          start: 0,
          end: road.sections.single.distanceMeters,
        ),
        road: road,
      );
      expect(geometry, hasLength(3));
      expect(geometry.first.longitude, 29);
      expect(geometry.last.longitude, 29.02);
    });

    test('partial offsets interpolate exact clipping boundaries', () {
      final road = _road('road-a', 'drive-a');
      final distance = road.sections.single.distanceMeters;
      final geometry = resolver.resolve(
        trace: _trace(
          road: road,
          id: 'partial',
          start: distance * .25,
          end: distance * .75,
        ),
        road: road,
      );
      expect(geometry, hasLength(3));
      expect(geometry.first.longitude, closeTo(29.005, .00001));
      expect(geometry[1].longitude, closeTo(29.01, .00001));
      expect(geometry.last.longitude, closeTo(29.015, .00001));
    });

    test('disconnected sections resolve as separate drawing traces', () async {
      final first = _section('road:a', const [
        MatchedRoadPoint(latitude: 41, longitude: 29),
        MatchedRoadPoint(latitude: 41, longitude: 29.01),
      ]);
      final second = _section('road:b', const [
        MatchedRoadPoint(latitude: 41.2, longitude: 29.2),
        MatchedRoadPoint(latitude: 41.2, longitude: 29.21),
      ]);
      final road = _road('road', 'drive', sections: [first, second]);
      final traces = [
        _trace(road: road, id: 'a', start: 0, end: first.distanceMeters),
        _trace(
          road: road,
          id: 'b',
          section: second,
          start: first.distanceMeters,
          end: first.distanceMeters + second.distanceMeters,
        ),
      ];
      final data = await _service(roads: [road], traces: traces).load();
      expect(data.traces, hasLength(2));
      expect(data.traces.first.geometry.last.longitude, closeTo(29.01, .00001));
      expect(data.traces.last.geometry.first.longitude, closeTo(29.2, .00001));
    });

    test('reverse-direction road preserves stored travel order', () {
      final section = _section('reverse:geometry', const [
        MatchedRoadPoint(latitude: 41, longitude: 29.02),
        MatchedRoadPoint(latitude: 41, longitude: 29.01),
        MatchedRoadPoint(latitude: 41, longitude: 29),
      ]);
      final road = _road(
        'reverse',
        'reverse-drive',
        sections: [section],
        directionKey: 'westbound',
      );
      final geometry = resolver.resolve(
        trace: _trace(
          road: road,
          id: 'reverse',
          start: 0,
          end: section.distanceMeters,
        ),
        road: road,
      );
      expect(geometry.first.longitude, 29.02);
      expect(geometry.last.longitude, 29);
    });

    test('zero or tiny invalid geometry is safely skipped', () {
      final section = MatchedRoadSection(
        id: 'tiny:geometry',
        geometry: const [MatchedRoadPoint(latitude: 41, longitude: 29)],
        distanceMeters: 10,
        confidence: 1,
        sourceTraceIndex: 0,
        sourceChunkIndex: 0,
      );
      final road = _road('tiny', 'drive', sections: [section]);
      expect(
        resolver.resolve(
          trace: _trace(road: road, id: 'tiny', start: 0, end: 10),
          road: road,
        ),
        isEmpty,
      );
    });
  });

  group('Phase 8 read projection', () {
    test('empty snapshot yields safe empty data', () async {
      final data = await _service().load();
      expect(data.isEmpty, isTrue);
      expect(data.viewport, isNull);
    });

    test('broken references are skipped without throwing', () async {
      final road = _road('missing', 'drive');
      final data = await _service(
        traces: [
          _trace(
            road: road,
            id: 'broken',
            start: 0,
            end: road.validDistanceMeters,
          ),
        ],
      ).load();
      expect(data.traces, isEmpty);
      expect(data.skippedBrokenTraceCount, 1);
      expect(data.hasOnlyBrokenReferences, isTrue);
    });

    test(
      'distance and unique processed-drive statistics are correct',
      () async {
        final road = _road('road', 'drive');
        final half = road.validDistanceMeters / 2;
        final data = await _service(
          roads: [road],
          traces: [
            _trace(road: road, id: 'one', start: 0, end: half),
            _trace(road: road, id: 'two', start: half, end: half * 2),
          ],
          processed: const ['drive', 'drive', 'other-drive'],
        ).load();
        expect(
          data.totalActiveDistanceMeters,
          closeTo(road.validDistanceMeters, .1),
        );
        expect(data.processedDriveCount, 2);
      },
    );

    test('same source keeps a variant and adjacent sources differ', () {
      final road = _road('road', 'drive-a');
      final length = road.validDistanceMeters;
      final traces = [
        _trace(road: road, id: 'a1', start: 0, end: length / 3),
        _trace(
          road: road,
          id: 'b',
          sourceDriveId: 'drive-b',
          start: length / 3,
          end: length * 2 / 3,
        ),
        _trace(road: road, id: 'a2', start: length * 2 / 3, end: length),
      ];
      const assigner = WorldTraceVisualVariants();
      final first = assigner.assign(traces);
      final second = assigner.assign(traces.reversed);
      expect(first, second);
      expect(first['drive-a'], isNot(first['drive-b']));
    });

    test('dominant cluster ignores one distant short trace', () async {
      final main = _road('main', 'main-drive');
      final remote = _road(
        'remote',
        'remote-drive',
        sections: [
          _section('remote:geometry', const [
            MatchedRoadPoint(latitude: 48, longitude: 2),
            MatchedRoadPoint(latitude: 48, longitude: 2.001),
          ]),
        ],
      );
      final data = await _service(
        roads: [main, remote],
        traces: [
          _trace(
            road: main,
            id: 'main',
            start: 0,
            end: main.validDistanceMeters,
          ),
          _trace(
            road: remote,
            id: 'remote',
            start: 0,
            end: remote.validDistanceMeters,
          ),
        ],
      ).load();
      expect(data.viewport!.centerLatitude, closeTo(41, .1));
      expect(data.viewport!.centerLongitude, closeTo(29.01, .1));
      expect(data.viewport!.source, 'dominantActiveTraceCluster');
    });
  });

  testWidgets('selection screen exposes active and locked World modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorldModeSelectionScreen(
          loadData: () async => const MyWorldMapData(
            snapshotGeneration: 0,
            traces: [],
            totalActiveDistanceMeters: 0,
            processedDriveCount: 0,
            processedDriveSessionIds: [],
            skippedBrokenTraceCount: 0,
            viewport: null,
          ),
          myWorldBuilder: (_) =>
              const Scaffold(key: Key('my_world_destination')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BENİM DÜNYAM'), findsOneWidget);
    expect(find.text('DRIVEIT GEZEGENİ'), findsOneWidget);
    expect(find.text('YAKINDA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('driveit_planet_card')));
    await tester.pump();
    expect(find.text('DriveIt Gezegeni yakında.'), findsOneWidget);
    expect(find.byKey(const Key('my_world_destination')), findsNothing);

    await tester.tap(find.byKey(const Key('my_world_card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my_world_destination')), findsOneWidget);
  });
}

MyWorldReadService _service({
  List<ValidatedRoad> roads = const [],
  List<ActiveWorldTrace> traces = const [],
  List<String> processed = const [],
}) => MyWorldReadService(
  repository: _FakeSourceRepository(roads),
  indexRepository: _FakeIndexRepository(traces, processed),
);

ValidatedRoad _road(
  String id,
  String driveId, {
  List<MatchedRoadSection>? sections,
  String directionKey = 'eastbound',
}) {
  final roadSections =
      sections ??
      [
        _section('$id:geometry', const [
          MatchedRoadPoint(latitude: 41, longitude: 29),
          MatchedRoadPoint(latitude: 41, longitude: 29.01),
          MatchedRoadPoint(latitude: 41, longitude: 29.02),
        ]),
      ];
  return ValidatedRoad(
    id: id,
    driveSessionId: driveId,
    geometry: roadSections.expand((section) => section.geometry).toList(),
    sections: roadSections,
    validDistanceMeters: roadSections.fold(
      0,
      (sum, section) => sum + section.distanceMeters,
    ),
    status: RoadValidationStatus.validated,
    validatedAt: DateTime.utc(2026, 8, 12),
    providerId: 'test',
    confidence: 1,
    processingVersion: 2,
    directionKey: directionKey,
    averageHeadingDegrees: directionKey == 'eastbound' ? 90 : 270,
    createdAt: DateTime.utc(2026, 8, 12),
    updatedAt: DateTime.utc(2026, 8, 12),
  );
}

MatchedRoadSection _section(String id, List<MatchedRoadPoint> geometry) {
  var distance = 0.0;
  for (var i = 1; i < geometry.length; i++) {
    distance += GeoDistance.between(
      geometry[i - 1].latitude,
      geometry[i - 1].longitude,
      geometry[i].latitude,
      geometry[i].longitude,
    );
  }
  return MatchedRoadSection(
    id: id,
    geometry: geometry,
    distanceMeters: distance,
    confidence: 1,
    sourceTraceIndex: 0,
    sourceChunkIndex: 0,
  );
}

ActiveWorldTrace _trace({
  required ValidatedRoad road,
  required String id,
  required double start,
  required double end,
  MatchedRoadSection? section,
  String? sourceDriveId,
}) {
  final target = section ?? road.sections.first;
  final points = target.geometry;
  return ActiveWorldTrace(
    id: id,
    sourceDriveSessionId: sourceDriveId ?? road.driveSessionId,
    validatedRoadId: road.id,
    matchedSectionId: target.id,
    startOffsetMeters: start,
    endOffsetMeters: end,
    directionKey: road.directionKey,
    minLatitude: points
        .map((point) => point.latitude)
        .reduce((a, b) => a < b ? a : b),
    maxLatitude: points
        .map((point) => point.latitude)
        .reduce((a, b) => a > b ? a : b),
    minLongitude: points
        .map((point) => point.longitude)
        .reduce((a, b) => a < b ? a : b),
    maxLongitude: points
        .map((point) => point.longitude)
        .reduce((a, b) => a > b ? a : b),
    createdAt: DateTime.utc(2026, 8, 12),
    updatedAt: DateTime.utc(2026, 8, 12),
    processingVersion: 2,
  );
}

class _FakeSourceRepository implements MyWorldSourceRepository {
  _FakeSourceRepository(List<ValidatedRoad> roads)
    : _roads = {for (final road in roads) road.id: road};
  final Map<String, ValidatedRoad> _roads;

  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async => _roads[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIndexRepository implements MyWorldIndexRepository {
  _FakeIndexRepository(this.traces, this.processed);
  final List<ActiveWorldTrace> traces;
  final List<String> processed;

  @override
  Future<WorldIndexSnapshot> getActiveSnapshot() async => WorldIndexSnapshot(
    generation: 1,
    operationId: 'test',
    traces: traces,
    processedDriveSessionIds: processed,
    driveScoreAlgorithmVersion: 1,
    validatedRoadProcessingVersion: 2,
    createdAt: DateTime.utc(2026, 8, 12),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
