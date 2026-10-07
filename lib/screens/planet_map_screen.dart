import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../features/planet/services/planet_map_controller.dart';
import '../features/planet/services/planet_map_repository.dart';
import '../features/planet/services/planet_map_presentation.dart';
import '../features/planet/models/planet_viewport.dart';
import '../theme/drive_map_visuals.dart';

class PlanetMapScreen extends StatefulWidget {
  const PlanetMapScreen({super.key, this.repository, this.mapBuilder});
  final PlanetMapRepository? repository;
  // Platform map boundary for widget tests; production always uses GoogleMap.
  final Widget Function(PlanetMapDrawing drawing)? mapBuilder;
  @override
  State<PlanetMapScreen> createState() => _PlanetMapScreenState();
}

class _PlanetMapScreenState extends State<PlanetMapScreen>
    with WidgetsBindingObserver {
  late final PlanetMapController _data;
  GoogleMapController? _map;
  CameraPosition _camera = const CameraPosition(
    target: LatLng(39, 35),
    zoom: 11,
  );
  int _idle = 0;
  PlanetSnapshot? _drawnSnapshot;
  double? _drawnZoom;
  PlanetMapDrawing _drawing = const PlanetMapDrawing({}, {});
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _data = PlanetMapController(
      widget.repository ?? SupabasePlanetMapRepository(),
    )..addListener(_changed);
    if (widget.mapBuilder != null) {
      _data.cameraIdle(const PlanetViewport(40.6, 40.8, 29.8, 30, 12));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _data.retry();
  }

  Future<void> _cameraIdle() async {
    final sequence = ++_idle, controller = _map;
    if (controller == null) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted || sequence != _idle) return;
      _data.cameraIdle(
        PlanetViewport(
          bounds.southwest.latitude,
          bounds.northeast.latitude,
          bounds.southwest.longitude,
          bounds.northeast.longitude,
          _camera.zoom,
        ),
      );
    } catch (_) {
      /* Native map may already have been disposed. */
    }
  }

  Future<void> _location() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final point = await Geolocator.getLastKnownPosition();
      if (mounted && point != null) {
        await _map?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(point.latitude, point.longitude),
            12,
          ),
        );
      }
    } catch (_) {
      /* Map remains usable without GPS; never request a new permission. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle++;
    _data.removeListener(_changed);
    _data.dispose();
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _data.snapshot;
    if (snapshot != _drawnSnapshot || _camera.zoom != _drawnZoom) {
      _drawnSnapshot = snapshot;
      _drawnZoom = _camera.zoom;
      _drawing = snapshot == null
          ? const PlanetMapDrawing({}, {})
          : PlanetMapPresentation.draw(snapshot, _camera.zoom);
    }
    final message =
        _data.error ??
        (_data.zoomIn
            ? 'Yolları görmek için haritaya yakınlaş.'
            : snapshot != null && snapshot.traces.isEmpty
            ? 'Bu bölgede henüz gezegen izi yok.'
            : null);
    return Scaffold(
      backgroundColor: DriveMapVisuals.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.mapBuilder?.call(_drawing) ??
              GoogleMap(
                initialCameraPosition: _camera,
                style: DriveMapVisuals.darkMapStyle,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                buildingsEnabled: false,
                indoorViewEnabled: false,
                trafficEnabled: false,
                polylines: _drawing.polylines,
                circles: _drawing.circles,
                onCameraMove: (p) {
                  _camera = p;
                  _idle++;
                },
                onCameraIdle: () => unawaited(_cameraIdle()),
                onMapCreated: (controller) {
                  _map = controller;
                  unawaited(_location().whenComplete(_cameraIdle));
                },
              ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _control(
                        Icons.arrow_back,
                        () => Navigator.of(context).pop(),
                        'Geri',
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'DriveIt Gezegeni',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _control(Icons.refresh, _data.retry, 'Yenile'),
                    ],
                  ),
                  if (snapshot != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Generation ${snapshot.generation} • ${snapshot.traces.length} iz',
                        style: const TextStyle(color: Color(0xff9babc2)),
                      ),
                    ),
                  const Spacer(),
                  if (_data.initialLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (message != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xee07172d),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x663b93ff)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (_data.error != null)
                            TextButton(
                              onPressed: _data.retry,
                              child: const Text('Tekrar Dene'),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _control(
                        Icons.my_location,
                        () => unawaited(_location()),
                        'Konumum',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _control(IconData icon, VoidCallback action, String tooltip) =>
      Material(
        color: const Color(0xee07172d),
        shape: const CircleBorder(side: BorderSide(color: Color(0x663b93ff))),
        child: IconButton(
          onPressed: action,
          tooltip: tooltip,
          icon: Icon(icon, color: const Color(0xff61c7ff)),
        ),
      );
}
