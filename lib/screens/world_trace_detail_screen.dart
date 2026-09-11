import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/my_world/models/matched_road_point.dart';
import '../features/my_world/models/world_trace_detail.dart';
import '../services/profile_storage_service.dart';
import '../theme/drive_map_visuals.dart';
import 'drive_detail_screen.dart';

class WorldTraceDetailScreen extends StatefulWidget {
  const WorldTraceDetailScreen({
    super.key,
    required this.detail,
    required this.geometry,
    this.traceColor = const Color(0xff53d7ff),
  });

  final WorldTraceDetail detail;
  final List<MatchedRoadPoint> geometry;
  final Color traceColor;

  @override
  State<WorldTraceDetailScreen> createState() => _WorldTraceDetailScreenState();
}

class _WorldTraceDetailScreenState extends State<WorldTraceDetailScreen> {
  GoogleMapController? _controller;
  Uint8List? _photo;
  String? _name;
  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _finishIcon;

  List<LatLng> get _points => widget.geometry
      .map((point) => LatLng(point.latitude, point.longitude))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadEndpointIcons();
  }

  Future<void> _loadEndpointIcons() async {
    final start = await _createEndpointIcon(
      const ui.Color(0xff42d8ff),
      isFinish: false,
    );
    final finish = await _createEndpointIcon(
      const ui.Color(0xffef405d),
      isFinish: true,
    );
    if (!mounted) return;
    setState(() {
      _startIcon = start;
      _finishIcon = finish;
    });
  }

  Future<BitmapDescriptor> _createEndpointIcon(
    ui.Color color, {
    required bool isFinish,
  }) async {
    const logicalSize = 18.0;
    const pixelRatio = 4.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio);
    const center = ui.Offset(logicalSize / 2, logicalSize / 2);
    canvas.drawCircle(
      center,
      6.5,
      ui.Paint()
        ..color = color.withAlpha(105)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      4.8,
      ui.Paint()..color = const ui.Color(0xff071426),
    );
    canvas.drawCircle(
      center,
      4.8,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color,
    );
    canvas.drawCircle(
      center,
      isFinish ? 2.0 : 1.8,
      ui.Paint()
        ..color = isFinish
            ? const ui.Color(0xffffd9df)
            : const ui.Color(0xffd9f3ff),
    );
    final image = await recorder.endRecording().toImage(
      (logicalSize * pixelRatio).toInt(),
      (logicalSize * pixelRatio).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      Uint8List.view(bytes!.buffer),
      imagePixelRatio: pixelRatio,
    );
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileStorageService.open();
      if (!mounted) return;
      setState(() {
        _name = profile.name;
        _photo = profile.photo;
      });
    } catch (_) {}
  }

  void _fitRoute() {
    final points = _points;
    final controller = _controller;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    if ((maxLat - minLat).abs() < .00001 && (maxLng - minLng).abs() < .00001) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        42,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final points = _points;
    final score = detail.worldTraceScore ?? detail.score?.totalScore;
    final segmentScore = detail.worldTraceScore != null;
    return Scaffold(
      backgroundColor: const Color(0xff020a18),
      appBar: AppBar(
        backgroundColor: const Color(0xff020a18),
        title: const Text('İz Detayı'),
        actions: [
          IconButton(
            tooltip: 'Rotayı ekrana sığdır',
            onPressed: _fitRoute,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = (constraints.maxHeight * .42).clamp(230.0, 390.0);
          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: mapHeight,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: points.isEmpty
                          ? const LatLng(39, 35)
                          : points.first,
                      zoom: 12,
                    ),
                    style: DriveMapVisuals.darkMapStyle,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    polylines: {
                      if (points.length > 1)
                        Polyline(
                          polylineId: const PolylineId('selected_world_trace'),
                          points: points,
                          color: widget.traceColor,
                          width: 3,
                          zIndex: 2,
                          geodesic: true,
                        ),
                    },
                    markers: {
                      if (points.isNotEmpty && _startIcon != null)
                        Marker(
                          markerId: const MarkerId('trace_start'),
                          position: points.first,
                          icon: _startIcon!,
                          anchor: const Offset(.5, .5),
                          zIndexInt: 5,
                        ),
                      if (points.length > 1 && _finishIcon != null)
                        Marker(
                          markerId: const MarkerId('trace_end'),
                          position: points.last,
                          icon: _finishIcon!,
                          anchor: const Offset(.5, .5),
                          zIndexInt: 5,
                        ),
                    },
                    onMapCreated: (controller) {
                      _controller = controller;
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _fitRoute(),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      16,
                      18,
                      MediaQuery.viewPaddingOf(context).bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xff12345a),
                              backgroundImage: _photo == null
                                  ? null
                                  : MemoryImage(_photo!),
                              child: _photo == null
                                  ? const Icon(
                                      Icons.person_outline,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name ?? 'DriveIt sürücüsü',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDate(detail.drive.date),
                                    style: const TextStyle(
                                      color: Color(0xff8fa1ba),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _stats(detail),
                        const SizedBox(height: 14),
                        _scoreCard(score, segmentScore),
                        const SizedBox(height: 14),
                        _infoCard(detail),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          key: const Key('view_full_drive_button'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  DriveDetailScreen(drive: detail.drive),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('TAM SÜRÜŞÜ GÖR →'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff248fff),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
        },
      ),
    );
  }

  Widget _stats(WorldTraceDetail detail) {
    final distance =
        detail.traceDistanceMeters ?? detail.activeWorldDistanceMeters;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      mainAxisExtent: 68,
      children: [
        _metric('Mesafe', _formatDistance(distance)),
        _metric(
          'Süre',
          detail.traceDurationSeconds == null
              ? '—'
              : _formatDuration(detail.traceDurationSeconds!),
        ),
        _metric(
          'Ortalama hız',
          detail.traceAverageSpeed == null
              ? '—'
              : '${detail.traceAverageSpeed!.round()} km/s',
        ),
        _metric(
          'Maksimum hız',
          detail.traceMaxSpeed == null
              ? '—'
              : '${detail.traceMaxSpeed!.round()} km/s',
        ),
      ],
    );
  }

  Widget _scoreCard(double? score, bool segmentScore) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          segmentScore ? 'DRIVE SCORE' : 'KAYNAK SÜRÜŞ SKORU',
          style: const TextStyle(
            color: Color(0xff8fa1ba),
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              score == null ? '—' : score.round().toString(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Text(
              _quality(score),
              style: const TextStyle(
                color: Color(0xff75c8ff),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score == null ? 0 : (score / 1000).clamp(0, 1),
            minHeight: 5,
            backgroundColor: const Color(0xff18304b),
            valueColor: const AlwaysStoppedAnimation(Color(0xff3b93ff)),
          ),
        ),
        if (score != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Drive Score v${widget.detail.score?.algorithmVersion ?? 1}',
              style: const TextStyle(color: Color(0xff71849e), fontSize: 10),
            ),
          ),
      ],
    ),
  );

  Widget _infoCard(WorldTraceDetail detail) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İz Bilgileri',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _infoRow('İlk bırakılma', _formatDate(detail.drive.date)),
        _infoRow(
          'İz yönü',
          detail.travelDirection == 'forward' ||
                  detail.travelDirection == 'reverse'
              ? detail.travelDirection!
              : '—',
        ),
        _infoRow(
          'İz uzunluğu',
          _formatDistance(
            detail.traceDistanceMeters ?? detail.activeWorldDistanceMeters,
          ),
        ),
      ],
    ),
  );

  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff07172d),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x442f79c8)),
    ),
    child: child,
  );
  Widget _metric(String label, String value) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xff8fa1ba), fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    ),
  );
  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xff8fa1ba), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  static String _quality(double? score) => score == null
      ? 'Mevcut değil'
      : score >= 800
      ? 'Çok İyi'
      : score >= 600
      ? 'İyi'
      : 'Geliştirilebilir';
  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '$h sa ${m.toString().padLeft(2, '0')} dk' : '$m dk';
  }

  static String _formatDistance(double meters) =>
      '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
