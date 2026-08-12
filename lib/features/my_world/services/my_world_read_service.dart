import 'dart:math' as math;

import '../models/validated_road.dart';
import '../models/world_map_read_model.dart';
import '../repositories/my_world_index_repository.dart';
import '../repositories/my_world_repository.dart';
import 'world_trace_geometry_resolver.dart';
import 'world_trace_visual_variants.dart';

class MyWorldReadService {
  factory MyWorldReadService({
    required MyWorldSourceRepository repository,
    required MyWorldIndexRepository indexRepository,
    WorldTraceGeometryResolver geometryResolver =
        const WorldTraceGeometryResolver(),
    WorldTraceVisualVariants visualVariants = const WorldTraceVisualVariants(),
  }) => MyWorldReadService._(
    repository,
    indexRepository,
    geometryResolver,
    visualVariants,
  );

  const MyWorldReadService._(
    this._repository,
    this._indexRepository,
    this._geometryResolver,
    this._visualVariants,
  );

  final MyWorldSourceRepository _repository;
  final MyWorldIndexRepository _indexRepository;
  final WorldTraceGeometryResolver _geometryResolver;
  final WorldTraceVisualVariants _visualVariants;

  Future<MyWorldMapData> load() async {
    final snapshot = await _indexRepository.getActiveSnapshot();
    final roadCache = <String, ValidatedRoad?>{};
    final resolved = <ResolvedWorldTrace>[];
    var brokenReferences = 0;

    for (final trace in snapshot.traces) {
      final road = roadCache.containsKey(trace.validatedRoadId)
          ? roadCache[trace.validatedRoadId]
          : await _repository.getValidatedRoad(trace.validatedRoadId);
      roadCache[trace.validatedRoadId] = road;
      if (road == null) {
        brokenReferences++;
        continue;
      }
      final geometry = _geometryResolver.resolve(trace: trace, road: road);
      if (geometry.length < 2) {
        brokenReferences++;
        continue;
      }
      resolved.add(
        ResolvedWorldTrace(trace: trace, geometry: geometry, visualVariant: 0),
      );
    }

    final variants = _visualVariants.assign(resolved.map((item) => item.trace));
    final styled = resolved
        .map(
          (item) => item.withVisualVariant(
            variants[item.trace.sourceDriveSessionId] ?? 0,
          ),
        )
        .toList(growable: false);
    return MyWorldMapData(
      snapshotGeneration: snapshot.generation,
      traces: List.unmodifiable(styled),
      totalActiveDistanceMeters: snapshot.traces.fold<double>(
        0,
        (sum, trace) => sum + trace.distanceMeters,
      ),
      processedDriveCount: snapshot.processedDriveSessionIds.toSet().length,
      processedDriveSessionIds: List.unmodifiable(
        snapshot.processedDriveSessionIds.toSet().toList()..sort(),
      ),
      skippedBrokenTraceCount: brokenReferences,
      viewport: _dominantViewport(styled),
    );
  }

  WorldMapViewport? _dominantViewport(List<ResolvedWorldTrace> traces) {
    if (traces.isEmpty) return null;
    const cellSizeDegrees = .5;
    final weights = <(int, int), double>{};
    for (final item in traces) {
      final centerLatitude =
          (item.trace.minLatitude + item.trace.maxLatitude) / 2;
      final centerLongitude =
          (item.trace.minLongitude + item.trace.maxLongitude) / 2;
      final cell = (
        (centerLatitude / cellSizeDegrees).floor(),
        (centerLongitude / cellSizeDegrees).floor(),
      );
      weights[cell] = (weights[cell] ?? 0) + item.trace.distanceMeters;
    }
    final dominant = weights.entries.reduce((a, b) {
      if ((a.value - b.value).abs() > .001) {
        return a.value > b.value ? a : b;
      }
      if (a.key.$1 != b.key.$1) return a.key.$1 < b.key.$1 ? a : b;
      return a.key.$2 <= b.key.$2 ? a : b;
    }).key;
    final cluster = traces.where((item) {
      final latitude = (item.trace.minLatitude + item.trace.maxLatitude) / 2;
      final longitude = (item.trace.minLongitude + item.trace.maxLongitude) / 2;
      final cell = (
        (latitude / cellSizeDegrees).floor(),
        (longitude / cellSizeDegrees).floor(),
      );
      return (cell.$1 - dominant.$1).abs() <= 1 &&
          (cell.$2 - dominant.$2).abs() <= 1;
    });
    var minLatitude = double.infinity;
    var maxLatitude = double.negativeInfinity;
    var minLongitude = double.infinity;
    var maxLongitude = double.negativeInfinity;
    for (final item in cluster) {
      for (final point in item.geometry) {
        minLatitude = math.min(minLatitude, point.latitude);
        maxLatitude = math.max(maxLatitude, point.latitude);
        minLongitude = math.min(minLongitude, point.longitude);
        maxLongitude = math.max(maxLongitude, point.longitude);
      }
    }
    if (!minLatitude.isFinite || !minLongitude.isFinite) return null;
    return WorldMapViewport(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
      source: 'dominantActiveTraceCluster',
    );
  }
}
