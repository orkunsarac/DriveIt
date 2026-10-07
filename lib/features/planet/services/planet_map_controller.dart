import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/planet_viewport.dart';
import 'planet_map_repository.dart';

/// Request sequencing also invalidates results after dispose/viewport changes.
/// Camera idle callers debounce; successful identical viewports are cached
/// only for 15 seconds, so revisiting the same view can see a new generation.
class PlanetMapController extends ChangeNotifier {
  PlanetMapController(this.repository);
  final PlanetMapRepository repository;
  PlanetSnapshot? snapshot;
  String? error;
  bool loading = false;
  Timer? _timer;
  int _request = 0;
  bool _disposed = false;
  String? _lastKey;
  DateTime? _loadedAt;
  PlanetViewport? _viewport;
  BigInt? _highestGeneration;
  void cameraIdle(PlanetViewport viewport, {bool force = false}) {
    if (_disposed) return;
    _viewport = viewport;
    if (!force &&
        _lastKey == viewport.key &&
        error == null &&
        (loading ||
            (_loadedAt != null &&
                DateTime.now().difference(_loadedAt!) <
                    const Duration(seconds: 15)))) {
      return;
    }
    _timer?.cancel();
    final request = ++_request;
    _lastKey = viewport.key;
    snapshot =
        null; // old viewport geometry must not masquerade as this viewport
    error = null;
    loading = true;
    notifyListeners();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => _read(viewport, request),
    );
  }

  Future<void> _read(PlanetViewport viewport, int request) async {
    try {
      final result = await repository.read(viewport);
      if (_disposed || request != _request) return;
      if (_highestGeneration != null &&
          result.generation < _highestGeneration!) {
        throw const PlanetReadFailure(
          'Gezegen güncelleniyor. Tekrar deneyebilirsin.',
        );
      }
      _highestGeneration = result.generation;
      snapshot = result;
      _loadedAt = DateTime.now();
    } catch (e) {
      if (_disposed || request != _request) return;
      error = e is PlanetReadFailure
          ? e.message
          : 'Gezegen verileri alınamadı.';
    }
    if (_disposed || request != _request) return;
    loading = false;
    notifyListeners();
  }

  void retry() {
    if (_viewport != null) cameraIdle(_viewport!, force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _timer?.cancel();
    super.dispose();
  }
}
