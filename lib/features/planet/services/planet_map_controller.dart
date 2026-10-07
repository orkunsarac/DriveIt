import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/planet_viewport.dart';
import 'planet_map_repository.dart';

class _LoadedRegion {
  _LoadedRegion(this.viewport, this.data, this.loadedAt, this.revision);
  final PlanetViewport viewport;
  final PlanetSnapshot data;
  final DateTime loadedAt;
  final int revision;
}

/// Generation-scoped session LRU. RPC returns complete active-span geometry,
/// not viewport-clipped fragments; deterministic IDs can safely be merged.
class PlanetMapController extends ChangeNotifier {
  PlanetMapController(
    this.repository, {
    this.maxRegions = 8,
    this.maxTraces = 200,
    this.maxVertices = 100000,
    this.coverageLifetime = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : assert(maxRegions > 0 && maxTraces > 0 && maxVertices >= 2),
       _now = now ?? DateTime.now;
  final PlanetMapRepository repository;
  final int maxRegions, maxTraces, maxVertices;
  final Duration coverageLifetime;
  final DateTime Function() _now;
  final _regions = <_LoadedRegion>[];
  PlanetSnapshot? snapshot;
  String? error;
  bool loading = false, zoomIn = false;
  bool get initialLoading => loading && snapshot == null;
  int get cachedRegionCount => _regions.length;
  // Synthetic UX metrics; no identities or geometry are logged.
  int requestCount = 0, mergeCount = 0, drawingSetChanges = 0;
  Timer? _timer;
  int _request = 0;
  int _revision = 0;
  bool _disposed = false;
  PlanetViewport? _viewport, _pending;
  BigInt? _highestGeneration;

  void cameraIdle(PlanetViewport viewport, {bool force = false}) {
    if (_disposed) return;
    _viewport = viewport;
    if (!viewport.canFetch) {
      _timer?.cancel();
      _request++;
      _pending = null;
      loading = false;
      zoomIn = true;
      error = null;
      notifyListeners();
      return;
    }
    zoomIn = false;
    if (!force) {
      if (loading && _pending?.contains(viewport) == true) return;
      final index = _regions.indexWhere(
        (r) =>
            r.viewport.contains(viewport) &&
            _now().difference(r.loadedAt) < coverageLifetime,
      );
      if (index >= 0) {
        final region = _regions.removeAt(index);
        _regions.add(region);
        _timer?.cancel();
        _request++;
        _pending = null;
        loading = false;
        error = null;
        notifyListeners();
        return;
      }
    }
    _timer?.cancel();
    final request = ++_request;
    final fetch = viewport.buffered();
    _pending = fetch;
    error = null;
    loading = true;
    notifyListeners();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => _read(fetch, request),
    );
  }

  Future<void> _read(PlanetViewport viewport, int request) async {
    try {
      requestCount++;
      final result = await repository.read(viewport);
      if (_disposed || request != _request) return;
      if (_highestGeneration != null &&
          result.generation < _highestGeneration!) {
        throw const PlanetReadFailure(
          'Gezegen güncelleniyor. Tekrar deneyebilirsin.',
        );
      }
      if (_highestGeneration != result.generation) {
        // Previous drawing remains until a ready authoritative result exists.
        _regions.clear();
        _highestGeneration = result.generation;
      }
      zoomIn = result.zoomIn;
      if (!result.zoomIn) {
        if (result.traces.length > maxTraces ||
            result.traces.fold<int>(0, (n, t) => n + t.geometry.length) >
                maxVertices) {
          throw const PlanetReadFailure(
            'Yolları görmek için haritaya yakınlaş.',
          );
        }
        _regions.removeWhere((r) => r.viewport.key == viewport.key);
        _regions.add(_LoadedRegion(viewport, result, _now(), ++_revision));
        _merge(result.generation);
      }
    } catch (e) {
      if (_disposed || request != _request) return;
      error = e is PlanetReadFailure
          ? e.message
          : 'Gezegen verileri alınamadı.';
    }
    if (_disposed || request != _request) return;
    _pending = null;
    loading = false;
    notifyListeners();
  }

  void _merge(BigInt generation) {
    Map<String, PlanetTrace> collect() => {
      // LRU access order must not overwrite fresher metadata with older data.
      for (final region
          in (_regions.toList()
            ..sort((a, b) => a.revision.compareTo(b.revision))))
        for (final trace in region.data.traces) trace.id: trace,
    };
    var traces = collect();
    while (_regions.length > 1 &&
        (_regions.length > maxRegions ||
            traces.length > maxTraces ||
            _regions.fold<int>(
                  0,
                  (n, r) =>
                      n +
                      r.data.traces.fold<int>(
                        0,
                        (m, t) => m + t.geometry.length,
                      ),
                ) >
                maxVertices)) {
      // Evict coverage with geometry; never claim removed data is loaded.
      _regions.removeAt(0);
      traces = collect();
    }
    mergeCount++;
    final ordered = traces.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final old = snapshot;
    if (old != null &&
        old.generation == generation &&
        old.traces.length == ordered.length &&
        List.generate(ordered.length, (i) => i).every(
          (i) =>
              old.traces[i].id == ordered[i].id &&
              old.traces[i].styleKey == ordered[i].styleKey &&
              old.traces[i].distanceMeters == ordered[i].distanceMeters &&
              listEquals(old.traces[i].geometry, ordered[i].geometry),
        )) {
      return;
    }
    snapshot = PlanetSnapshot(generation, false, List.unmodifiable(ordered));
    drawingSetChanges++;
  }

  void retry() {
    if (_viewport != null) cameraIdle(_viewport!, force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _timer?.cancel();
    _regions.clear();
    super.dispose();
  }
}
