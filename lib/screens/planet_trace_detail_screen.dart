import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../features/planet/models/planet_viewport.dart';
import '../features/planet/models/planet_trace_detail.dart';
import '../features/planet/services/planet_map_presentation.dart';
import '../features/planet/services/planet_trace_detail_repository.dart';
import '../theme/drive_map_visuals.dart';

class PlanetTraceDetailScreen extends StatefulWidget {
  const PlanetTraceDetailScreen({
    super.key,
    required this.trace,
    required this.generation,
    required this.repository,
    this.mapBuilder,
  });
  final PlanetTrace trace;
  final BigInt generation;
  final PlanetTraceDetailRepository repository;
  final Widget Function(PlanetMapDrawing)? mapBuilder;
  @override
  State<PlanetTraceDetailScreen> createState() =>
      _PlanetTraceDetailScreenState();
}

class _PlanetTraceDetailScreenState extends State<PlanetTraceDetailScreen> {
  late Future<PlanetTraceDetail> _detail;
  GoogleMapController? _map;
  double _zoom = 12;
  @override
  void initState() {
    super.initState();
    _detail = widget.repository.read(widget.trace.id);
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _fit() {
    final points = widget.trace.geometry;
    final lats = points.map((p) => p.latitude).toList()..sort();
    final longs = points.map((p) => p.longitude).toList()..sort();
    // Choose the shortest longitude interval, including dateline crossings.
    var gap = -1.0, index = 0;
    for (var i = 0; i < longs.length; i++) {
      final next = i + 1 < longs.length ? longs[i + 1] : longs.first + 360;
      if (next - longs[i] > gap) {
        gap = next - longs[i];
        index = i;
      }
    }
    final west = longs[(index + 1) % longs.length], east = longs[index];
    if (lats.last - lats.first < .00001 && 360 - gap < .00001) {
      unawaited(
        _map?.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15)) ??
            Future.value(),
      );
    } else {
      unawaited(
        _map?.animateCamera(
              CameraUpdate.newLatLngBounds(
                LatLngBounds(
                  southwest: LatLng(lats.first, west),
                  northeast: LatLng(lats.last, east),
                ),
                42,
              ),
            ) ??
            Future.value(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DriveMapVisuals.background,
    appBar: AppBar(
      title: const Text('Gezegen İz Detayı'),
      backgroundColor: DriveMapVisuals.background,
      actions: [
        IconButton(
          onPressed: _fit,
          icon: const Icon(Icons.fit_screen),
          tooltip: 'İzi kadraja al',
        ),
      ],
    ),
    body: FutureBuilder<PlanetTraceDetail>(
      future: _detail,
      builder: (context, state) {
        final failure = state.error;
        final retired =
            failure is PlanetDetailFailure &&
            (failure.code == 'trace_retired' ||
                failure.code == 'trace_changed');
        final baseDrawing = PlanetMapPresentation.draw(
          PlanetSnapshot(
            widget.generation,
            false,
            retired ? [] : [widget.trace],
          ),
          _zoom < 13 ? 13 : _zoom,
        );
        // Keep selected endpoint indicators legible even for a long-drive fit.
        // Presentation-only sizing; canonical geometry is never changed.
        final drawing = PlanetMapDrawing(baseDrawing.polylines, {
          for (final circle in baseDrawing.circles)
            circle.copyWith(
              radiusParam:
                  (4 *
                          156543.03392 *
                          math.cos(circle.center.latitude * math.pi / 180) /
                          math.pow(2, _zoom))
                      .clamp(2.0, 5000.0)
                      .toDouble(),
            ),
        });
        return LayoutBuilder(
          builder: (context, bounds) => Column(
            children: [
              SizedBox(
                height: bounds.maxHeight * .42,
                child:
                    widget.mapBuilder?.call(drawing) ??
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.trace.geometry.first,
                        zoom: 12,
                      ),
                      style: DriveMapVisuals.darkMapStyle,
                      polylines: drawing.polylines,
                      circles: drawing.circles,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      onMapCreated: (map) {
                        _map = map;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _fit();
                        });
                      },
                      onCameraMove: (camera) {
                        _zoom = camera.zoom;
                      },
                      onCameraIdle: () {
                        if (mounted) setState(() {});
                      },
                    ),
              ),
              Expanded(
                child: ListView(
                  key: const Key('planet-detail-panel'),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (state.connectionState != ConnectionState.done)
                      const Center(child: CircularProgressIndicator())
                    else if (failure != null) ...[
                      Text(
                        failure is PlanetDetailFailure
                            ? failure.message
                            : 'İz detayı alınamadı.',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (!retired)
                        TextButton(
                          onPressed: () {
                            final next = widget.repository.read(
                              widget.trace.id,
                            );
                            setState(() {
                              _detail = next;
                            });
                          },
                          child: const Text('Tekrar Dene'),
                        ),
                    ] else if (state.data case final detail?)
                      ..._content(detail),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  List<Widget> _content(PlanetTraceDetail d) {
    final name = d.displayName?.trim();
    final label = name == null || name.isEmpty ? 'DriveIt sürücüsü' : name;
    final date = d.date.toLocal();
    final duration = Duration(seconds: d.duration);
    return [
      Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xff173453),
            child: Text(label.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (d.username?.isNotEmpty == true)
                  Text(
                    '@${d.username}',
                    style: const TextStyle(color: Color(0xff76b4ff)),
                  ),
                Text(
                  '${date.day}.${date.month}.${date.year}',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Center(
        child: Text(
          d.score?.toString() ?? '—',
          style: const TextStyle(
            color: Color(0xff76b4ff),
            fontSize: 64,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const Center(
        child: Text(
          'DRIVE SCORE /1000',
          style: TextStyle(color: Colors.white60),
        ),
      ),
      const SizedBox(height: 20),
      _row('Sürüş mesafesi', '${(d.distance / 1000).toStringAsFixed(2)} km'),
      _row(
        'Süre',
        '${duration.inHours} sa ${duration.inMinutes.remainder(60)} dk ${duration.inSeconds.remainder(60)} sn',
      ),
      _row('Ortalama hız', '${d.averageSpeed.toStringAsFixed(1)} km/sa'),
      _row('Maksimum hız', '${d.maxSpeed.toStringAsFixed(1)} km/sa'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff10243c),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GEZEGENDEKİ İZ',
              style: TextStyle(color: Color(0xff76b4ff)),
            ),
            Text(
              '${(d.ownershipDistance / 1000).toStringAsFixed(2)} km',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Yalnızca seçilen aktif izin uzunluğu',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Drive Score dağılımı',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      for (final category in d.categories)
        _row(
          _labels[category.key] ?? category.key,
          !category.applicable
              ? 'N/A'
              : !category.sufficient
              ? 'Yetersiz veri'
              : '${category.score.round()} / ${category.maximum.round()}',
        ),
      const SizedBox(height: 20),
    ];
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white60)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

const _labels = {
  'brakingAnticipation': 'Frenleme & Öngörü',
  'tempoPerformance': 'Tempo & Performans',
  'corneringPerformance': 'Viraj Performansı',
  'drivingEndurance': 'Sürüş Dayanıklılığı',
  'drivingSmoothness': 'Sürüş Akıcılığı',
  'accelerationPerformance': 'Hızlanma & Gaz Performansı',
  'transitionControl': 'Geçiş Kontrolü',
};
