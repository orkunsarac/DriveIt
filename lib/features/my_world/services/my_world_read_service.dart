import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../../models/canonical_telemetry_point.dart';
import '../models/validated_road.dart';
import '../models/world_map_read_model.dart';
import '../repositories/my_world_index_repository.dart';
import '../repositories/my_world_repository.dart';
import 'world_trace_travel_direction_resolver.dart';
import '../models/world_trace_travel_direction.dart';
import 'world_trace_geometry_resolver.dart';
import 'world_trace_visual_variants.dart';

class MyWorldReadService {
  factory MyWorldReadService({
    required MyWorldSourceRepository repository,
    required MyWorldIndexRepository indexRepository,
    WorldTraceGeometryResolver geometryResolver =
        const WorldTraceGeometryResolver(),
    WorldTraceVisualVariants visualVariants = const WorldTraceVisualVariants(),
    Future<List<CanonicalTelemetryPoint>> Function(String driveId)?
    telemetryLoader,
    WorldTraceTravelDirectionResolver directionResolver =
        const WorldTraceTravelDirectionResolver(),
  }) => MyWorldReadService._(
    repository,
    indexRepository,
    geometryResolver,
    visualVariants,
    telemetryLoader,
    directionResolver,
  );

  const MyWorldReadService._(
    this._repository,
    this._indexRepository,
    this._geometryResolver,
    this._visualVariants,
    this._telemetryLoader,
    this._directionResolver,
  );

  final MyWorldSourceRepository _repository;
  final MyWorldIndexRepository _indexRepository;
  final WorldTraceGeometryResolver _geometryResolver;
  final WorldTraceVisualVariants _visualVariants;
  final Future<List<CanonicalTelemetryPoint>> Function(String driveId)?
  _telemetryLoader;
  final WorldTraceTravelDirectionResolver _directionResolver;

  Future<MyWorldMapData> load() async {
    final snapshot = await _indexRepository.getActiveSnapshot();
    if (kDebugMode) {
      debugPrint(
        '[WORLD_READ] loadedSnapshotGeneration=${snapshot.generation} '
        'loadedSnapshotVersion=${snapshot.validatedRoadProcessingVersion} '
        'cacheHit=false cacheInvalidated=false',
      );
    }
    final roadCache = <String, ValidatedRoad?>{};
    final telemetryCache = <String, List<CanonicalTelemetryPoint>>{};
    final directionCache = <String, WorldTraceTravelDirectionResult>{};
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
      var presentationGeometry = geometry;
      var direction = const WorldTraceTravelDirectionResult.unknown();
      if (_telemetryLoader != null) {
        final driveId = trace.sourceDriveSessionId;
        final telemetry = telemetryCache.containsKey(driveId)
            ? telemetryCache[driveId]!
            : await _telemetryLoader(driveId);
        telemetryCache[driveId] = telemetry;
        final directionKey =
            '$driveId:${trace.validatedRoadId}:${trace.matchedSectionId}';
        final cachedDirection = directionCache[directionKey];
        if (cachedDirection != null) {
          direction = cachedDirection;
        } else {
          direction = _directionResolver.resolve(
            trace: trace,
            road: road,
            telemetry: telemetry,
          );
          directionCache[directionKey] = direction;
        }
        if (direction.direction == WorldTraceTravelDirection.reverse) {
          presentationGeometry = geometry.reversed.toList(growable: false);
        }
      }
      resolved.add(
        ResolvedWorldTrace(
          trace: trace,
          geometry: presentationGeometry,
          visualVariant: 0,
          travelDirection: direction.direction,
          directionConfidence: direction.confidence,
          firstProjectedOffset: direction.firstProjectedOffset,
          lastProjectedOffset: direction.lastProjectedOffset,
          projectedSampleCount: direction.projectedSampleCount,
        ),
      );
      if (kDebugMode && trace.distanceMeters < 2000) {
        debugPrint(
          '[WORLD_RENDER_TRACE] polylineId=${trace.id} '
          'activeTraceId=${trace.id} sourceDriveId=${trace.sourceDriveSessionId} '
          'renderSegmentIndex=0 renderSegmentLengthMeters=${trace.distanceMeters} '
          'originalActiveTraceLengthMeters=${trace.distanceMeters} '
          'reasonForSegmentation=NONE',
        );
      }
    }

    final variants = _visualVariants.assign(resolved.map((item) => item.trace));
    final styled = resolved
        .map(
          (item) => item.withVisualVariant(
            variants[item.trace.sourceDriveSessionId] ?? 0,
          ),
        )
        .toList(growable: false);
    final result = MyWorldMapData(
      snapshotGeneration: snapshot.generation,
      traces: List.unmodifiable(styled),
      totalActiveDistanceMeters: snapshot.traces.fold<double>(
        0,
        (sum, trace) => sum + trace.distanceMeters,
      ),
      // Count processed source drives, not the number of active trace pieces.
      // A single drive can be split into multiple active traces after record
      // replacement, so using traces.length understated the drive count.
      processedDriveCount: snapshot.processedDriveSessionIds.toSet().length,
      processedDriveSessionIds: List.unmodifiable(
        snapshot.processedDriveSessionIds.toSet().toList()..sort(),
      ),
      skippedBrokenTraceCount: brokenReferences,
      viewport: _dominantViewport(styled),
    );
    return result;
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
