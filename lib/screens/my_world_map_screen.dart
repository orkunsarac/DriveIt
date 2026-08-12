import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/my_world/models/world_map_read_model.dart';
import '../features/my_world/services/my_world_runtime.dart';
import '../theme/drive_map_visuals.dart';
import 'world_mode_selection_screen.dart';

class MyWorldMapScreen extends StatefulWidget {
  const MyWorldMapScreen({super.key, this.loadData});

  final MyWorldDataLoader? loadData;

  @override
  State<MyWorldMapScreen> createState() => _MyWorldMapScreenState();
}

class _MyWorldMapScreenState extends State<MyWorldMapScreen> {
  static const _fallback = LatLng(39.0, 35.0);
  static const _palette = <Color>[
    Color(0xff53d7ff),
    Color(0xff3b93ff),
    Color(0xff6ba8ff),
    Color(0xff31c7e8),
  ];

  GoogleMapController? _mapController;
  late final Future<MyWorldMapData> _loadFuture;
  MyWorldMapData? _data;
  CameraPosition _camera = const CameraPosition(target: _fallback, zoom: 5);
  String? _selectedTraceId;

  @override
  void initState() {
    super.initState();
    _loadFuture = (widget.loadData ?? MyWorldRuntime.readService().load)();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DriveMapVisuals.background,
    appBar: AppBar(
      backgroundColor: DriveMapVisuals.background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Benim Dünyam',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            'Kalıcı neon yol ağın',
            style: TextStyle(color: Color(0xff8fa1ba), fontSize: 11),
          ),
        ],
      ),
    ),
    body: FutureBuilder<MyWorldMapData>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xff3b93ff)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _WorldReadError(onRetry: () => Navigator.of(context).pop());
        }
        _data ??= snapshot.data;
        if (_data!.hasOnlyBrokenReferences) {
          return _WorldReadError(onRetry: () => Navigator.of(context).pop());
        }
        return _buildMap(_data!);
      },
    ),
  );

  Widget _buildMap(MyWorldMapData data) => Stack(
    children: [
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
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        polylines: _polylines(data),
        onCameraMove: (position) => _camera = position,
        onCameraIdle: () {
          if (mounted) setState(() {});
        },
        onMapCreated: (controller) {
          _mapController = controller;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (data.viewport != null) {
              _showWorld();
            } else {
              _centerOnLocation(requestPermission: false);
            }
          });
        },
      ),
      Positioned(
        top: 14,
        left: 14,
        child: _WorldStatsChip(data: data),
      ),
      if (data.isEmpty)
        const Positioned(
          left: 20,
          right: 20,
          bottom: 116,
          child: _EmptyWorldMessage(),
        ),
      Positioned(
        right: 14,
        bottom: 26,
        child: Column(
          children: [
            if (_camera.bearing.abs() > 2)
              _MapControl(
                tooltip: 'Kuzeye dön',
                icon: Icons.explore_outlined,
                onTap: _resetBearing,
              ),
            if (_camera.bearing.abs() > 2) const SizedBox(height: 9),
            _MapControl(
              key: const Key('show_my_world_button'),
              tooltip: 'Dünyamı Göster',
              icon: Icons.public,
              onTap: data.viewport == null ? null : _showWorld,
            ),
            const SizedBox(height: 9),
            _MapControl(
              key: const Key('my_location_button'),
              tooltip: 'Konumum',
              icon: Icons.my_location,
              onTap: () => _centerOnLocation(requestPermission: true),
            ),
          ],
        ),
      ),
    ],
  );

  Set<Polyline> _polylines(MyWorldMapData data) {
    final output = <Polyline>{};
    for (final item in data.traces) {
      final points = item.geometry
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false);
      final color = _palette[item.visualVariant % _palette.length];
      final selected = item.trace.id == _selectedTraceId;
      output.add(
        Polyline(
          polylineId: PolylineId('world_glow:${item.trace.id}'),
          points: points,
          color: color.withAlpha(selected ? 115 : 65),
          width: selected ? 15 : 12,
          zIndex: 1,
          geodesic: true,
        ),
      );
      output.add(
        Polyline(
          polylineId: PolylineId('world_core:${item.trace.id}'),
          points: points,
          color: selected ? const Color(0xffbcefff) : color,
          width: selected ? 7 : 5,
          zIndex: 2,
          geodesic: true,
          consumeTapEvents: true,
          onTap: () {
            setState(() => _selectedTraceId = item.trace.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                duration: Duration(milliseconds: 900),
                content: Text('Dünya izin seçildi.'),
              ),
            );
          },
        ),
      );
    }
    return output;
  }

  Future<void> _showWorld() async {
    final controller = _mapController;
    final viewport = _data?.viewport;
    if (controller == null || viewport == null) return;
    final latitudePadding =
        (viewport.maxLatitude - viewport.minLatitude).abs() < .0001 ? .001 : 0;
    final longitudePadding =
        (viewport.maxLongitude - viewport.minLongitude).abs() < .0001
        ? .001
        : 0;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            viewport.minLatitude - latitudePadding,
            viewport.minLongitude - longitudePadding,
          ),
          northeast: LatLng(
            viewport.maxLatitude + latitudePadding,
            viewport.maxLongitude + longitudePadding,
          ),
        ),
        58,
      ),
    );
  }

  Future<void> _centerOnLocation({required bool requestPermission}) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (requestPermission) _message('Konum servisi kapalı.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (requestPermission) {
          _message('Konum izni olmadan harita kullanılabilir.');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (_) {
      if (requestPermission) _message('Konum şu anda alınamıyor.');
    }
  }

  Future<void> _resetBearing() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _camera.target,
          zoom: _camera.zoom,
          tilt: _camera.tilt,
          bearing: 0,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _WorldStatsChip extends StatelessWidget {
  const _WorldStatsChip({required this.data});
  final MyWorldMapData data;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xe6071529),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x663b93ff)),
    ),
    child: Text(
      '${(data.totalActiveDistanceMeters / 1000).toStringAsFixed(1)} km  •  '
      '${data.processedDriveCount} sürüş',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xee07172d),
    shape: const CircleBorder(
      side: BorderSide(color: Color(0x663b93ff)),
    ),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      color: onTap == null ? Colors.white30 : const Color(0xff61c7ff),
      icon: Icon(icon),
    ),
  );
}

class _EmptyWorldMessage extends StatelessWidget {
  const _EmptyWorldMessage();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xea07172d),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x663b93ff)),
    ),
    child: const Text(
      'Dünyan henüz boş.\nİlk sürüşünü yap ve izini bırak.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
    ),
  );
}

class _WorldReadError extends StatelessWidget {
  const _WorldReadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xff5baeff), size: 42),
          const SizedBox(height: 14),
          const Text(
            'Dünya verileri şu anda açılamıyor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Geri dön')),
        ],
      ),
    ),
  );
}
