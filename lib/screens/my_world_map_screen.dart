import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/my_world/models/world_map_read_model.dart';
import '../features/my_world/models/world_trace_detail.dart';
import '../features/my_world/services/my_world_runtime.dart';
import '../features/my_world/services/my_world_settings_service.dart';
import '../features/my_world/services/world_intro_policy.dart';
import '../features/my_world/services/world_trace_detail_service.dart';
import '../models/drive_score_record.dart';
import '../models/drive_session.dart';
import '../services/drive_score_storage_service.dart';
import '../services/drive_storage_service.dart';
import '../theme/drive_map_visuals.dart';
import 'drive_detail_screen.dart';
import 'world_mode_selection_screen.dart';

class MyWorldMapScreen extends StatefulWidget {
  const MyWorldMapScreen({
    super.key,
    this.loadData,
    this.settingsStore,
    this.detailService,
  });

  final MyWorldDataLoader? loadData;
  final MyWorldSettingsStore? settingsStore;
  final WorldTraceDetailService? detailService;

  @override
  State<MyWorldMapScreen> createState() => _MyWorldMapScreenState();
}

class _MyWorldMapScreenState extends State<MyWorldMapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _fallback = LatLng(39.0, 35.0);
  static const _palette = <Color>[
    Color(0xff53d7ff),
    Color(0xff3b93ff),
    Color(0xff6ba8ff),
    Color(0xff31c7e8),
  ];

  GoogleMapController? _mapController;
  late final Future<MyWorldMapData> _loadFuture;
  late final AnimationController _introController;
  late final MyWorldSettingsStore _settingsStore;
  late final WorldTraceDetailService _detailService;
  MyWorldMapData? _data;
  CameraPosition _camera = const CameraPosition(target: _fallback, zoom: 5);
  String? _selectedTraceId;
  String? _highlightedDriveId;
  bool _introConfigured = false;
  bool _introPlaying = false;

  bool get _interactionEnabled => !_introPlaying;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsStore = widget.settingsStore ?? const HiveMyWorldSettingsStore();
    _detailService =
        widget.detailService ??
        WorldTraceDetailService(
          driveLoader: DriveStorageService.getDrive,
          scoreLoader: (driveId) => DriveScoreStorageService.get(
            driveId: driveId,
            algorithmVersion: DriveScoreRecord.currentAlgorithmVersion,
          ),
          activeDistanceLoader:
              MyWorldRuntime.indexRepository().activeDistanceForDrive,
        );
    _loadFuture = (widget.loadData ?? MyWorldRuntime.readService().load)();
    _introController =
        AnimationController(vsync: this, duration: WorldIntroPolicy.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _introPlaying = false);
            }
          });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_introPlaying && state != AppLifecycleState.resumed) {
      _completeIntro();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: FutureBuilder<MyWorldMapData>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(color: Colors.black);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _WorldReadError(onRetry: () => Navigator.of(context).pop());
        }
        _data ??= snapshot.data;
        if (_data!.hasOnlyBrokenReferences) {
          return _WorldReadError(onRetry: () => Navigator.of(context).pop());
        }
        _configureIntro(_data!);
        return _buildMap(_data!);
      },
    ),
  );

  void _configureIntro(MyWorldMapData data) {
    if (_introConfigured) return;
    _introConfigured = true;
    _introPlaying = WorldIntroPolicy.shouldPlay(
      data: data,
      skipIntroAnimation: _settingsStore.skipIntroAnimation,
    );
  }

  void _maybeStartIntro() {
    if (!_introPlaying || _introController.isAnimating) return;
    _introController.forward();
  }

  void _completeIntro() {
    _introController.value = 1;
    if (mounted) setState(() => _introPlaying = false);
  }

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
        zoomGesturesEnabled: _interactionEnabled,
        scrollGesturesEnabled: _interactionEnabled,
        rotateGesturesEnabled: _interactionEnabled,
        tiltGesturesEnabled: _interactionEnabled,
        polylines: _polylines(data),
        onTap: _selectedTraceId == null ? null : (_) => _clearSelection(),
        onCameraMove: (position) => _camera = position,
        onCameraIdle: () {
          if (mounted && _interactionEnabled) setState(() {});
        },
        onMapCreated: (controller) {
          _mapController = controller;
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            if (data.viewport != null) {
              await _showWorld();
            } else {
              await _centerOnLocation(requestPermission: false);
            }
            if (mounted) _maybeStartIntro();
          });
        },
      ),
      AnimatedOpacity(
        opacity: _interactionEnabled ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: IgnorePointer(
          ignoring: !_interactionEnabled,
          child: _MapChrome(
            data: data,
            cameraBearing: _camera.bearing,
            hasLastWorldDrive: _lastProcessedDrive(data) != null,
            onBack: () => Navigator.of(context).pop(),
            onSettings: _openSettings,
            onResetBearing: _resetBearing,
            onShowWorld: data.viewport == null ? null : _showWorld,
            onShowLastDrive: () => _showLastWorldDrive(data),
            onLocation: () => _centerOnLocation(requestPermission: true),
          ),
        ),
      ),
      if (data.isEmpty)
        const Positioned(
          left: 20,
          right: 20,
          bottom: 116,
          child: _EmptyWorldMessage(),
        ),
      if (_introPlaying)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _introController,
            builder: (context, _) => _WorldIntroOverlay(
              data: data,
              progress: _introController.value,
              palette: _palette,
            ),
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
      final highlighted =
          item.trace.sourceDriveSessionId == _highlightedDriveId;
      final otherSelected = _selectedTraceId != null && !selected;
      output.add(
        Polyline(
          polylineId: PolylineId('world_glow:${item.trace.id}'),
          points: points,
          color: color.withAlpha(
            selected || highlighted ? 125 : (otherSelected ? 35 : 65),
          ),
          width: selected || highlighted ? 16 : 12,
          zIndex: 1,
          geodesic: true,
        ),
      );
      output.add(
        Polyline(
          polylineId: PolylineId('world_core:${item.trace.id}'),
          points: points,
          color: selected || highlighted
              ? const Color(0xffbcefff)
              : color.withAlpha(otherSelected ? 150 : 255),
          width: selected || highlighted ? 7 : 5,
          zIndex: 2,
          geodesic: true,
          consumeTapEvents: true,
          onTap: () => _selectTrace(item),
        ),
      );
    }
    return output;
  }

  Future<void> _selectTrace(ResolvedWorldTrace item) async {
    if (!_interactionEnabled) return;
    setState(() => _selectedTraceId = item.trace.id);
    await _fitResolvedTraces([item], padding: 116);
    final detail = await _detailService.load(item.trace.sourceDriveSessionId);
    if (!mounted) return;
    if (detail == null) {
      _message('Bu izin sürüş kaydı artık mevcut değil.');
      _clearSelection();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WorldTraceDetailSheet(
        detail: detail,
        onViewDrive: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DriveDetailScreen(drive: detail.drive),
            ),
          );
        },
      ),
    );
    if (mounted) _clearSelection();
  }

  void _clearSelection() {
    if (_selectedTraceId == null) return;
    setState(() => _selectedTraceId = null);
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MyWorldSettingsSheet(store: _settingsStore),
    );
  }

  Future<void> _showWorld() async {
    final viewport = _data?.viewport;
    if (viewport == null) return;
    await _fitBounds(
      minLatitude: viewport.minLatitude,
      maxLatitude: viewport.maxLatitude,
      minLongitude: viewport.minLongitude,
      maxLongitude: viewport.maxLongitude,
      padding: 58,
    );
  }

  Future<void> _showLastWorldDrive(MyWorldMapData data) async {
    final drive = _lastProcessedDrive(data);
    if (drive == null) {
      _message('İşlenmiş bir Dünya sürüşü bulunamadı.');
      return;
    }
    final traces = data.traces
        .where((item) => item.trace.sourceDriveSessionId == drive.id)
        .toList(growable: false);
    if (traces.isEmpty) {
      _message('Son Dünya sürüşünün aktif rekor izi kalmamış.');
      return;
    }
    await _fitResolvedTraces(traces, padding: 70);
    if (!mounted) return;
    setState(() => _highlightedDriveId = drive.id);
    _message(
      '${(drive.distance / 1000).toStringAsFixed(1).replaceAll('.', ',')} km sürüş  •  '
      '${(traces.fold<double>(0, (sum, item) => sum + item.trace.distanceMeters) / 1000).toStringAsFixed(1).replaceAll('.', ',')} km aktif iz',
    );
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _highlightedDriveId == drive.id) {
        setState(() => _highlightedDriveId = null);
      }
    });
  }

  DriveSession? _lastProcessedDrive(MyWorldMapData data) =>
      WorldTraceDetailService.latestProcessedDrive(
        processedDriveIds: data.processedDriveSessionIds,
        drives: DriveStorageService.getAllDrives(),
      );

  Future<void> _fitResolvedTraces(
    List<ResolvedWorldTrace> traces, {
    required double padding,
  }) async {
    if (traces.isEmpty) return;
    var minLatitude = double.infinity;
    var maxLatitude = double.negativeInfinity;
    var minLongitude = double.infinity;
    var maxLongitude = double.negativeInfinity;
    for (final item in traces) {
      for (final point in item.geometry) {
        minLatitude = math.min(minLatitude, point.latitude);
        maxLatitude = math.max(maxLatitude, point.latitude);
        minLongitude = math.min(minLongitude, point.longitude);
        maxLongitude = math.max(maxLongitude, point.longitude);
      }
    }
    await _fitBounds(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
      padding: padding,
    );
  }

  Future<void> _fitBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    required double padding,
  }) async {
    final controller = _mapController;
    if (controller == null || !minLatitude.isFinite || !minLongitude.isFinite) {
      return;
    }
    final latitudePadding = (maxLatitude - minLatitude).abs() < .0001
        ? .001
        : 0;
    final longitudePadding = (maxLongitude - minLongitude).abs() < .0001
        ? .001
        : 0;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            minLatitude - latitudePadding,
            minLongitude - longitudePadding,
          ),
          northeast: LatLng(
            maxLatitude + latitudePadding,
            maxLongitude + longitudePadding,
          ),
        ),
        padding,
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

class _WorldIntroOverlay extends StatelessWidget {
  const _WorldIntroOverlay({
    required this.data,
    required this.progress,
    required this.palette,
  });

  final MyWorldMapData data;
  final double progress;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final revealOpacity = 1 - ((progress - .82) / .18).clamp(0.0, 1.0);
    final blackOpacity = 1 - ((progress - .72) / .28).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withAlpha((blackOpacity * 255).round()),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: revealOpacity,
              child: CustomPaint(
                painter: _WorldNetworkPainter(
                  data: data,
                  progress: progress,
                  palette: palette,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldNetworkPainter extends CustomPainter {
  const _WorldNetworkPainter({
    required this.data,
    required this.progress,
    required this.palette,
  });

  final MyWorldMapData data;
  final double progress;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = data.viewport;
    if (viewport == null || size.isEmpty) return;
    final latSpan = math.max(
      viewport.maxLatitude - viewport.minLatitude,
      .0001,
    );
    final lngSpan = math.max(
      viewport.maxLongitude - viewport.minLongitude,
      .0001,
    );
    final scale = math.min(
      size.width * .88 / lngSpan,
      size.height * .78 / latSpan,
    );
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = progress > .65 && progress < .86
        ? math.sin((progress - .65) / .21 * math.pi)
        : 0.0;

    for (var traceIndex = 0; traceIndex < data.traces.length; traceIndex++) {
      final item = data.traces[traceIndex];
      final reveal = WorldIntroPolicy.revealProgress(
        animationProgress: progress,
        traceIndex: traceIndex,
        traceCount: data.traces.length,
      );
      if (reveal <= 0 || item.geometry.length < 2) continue;
      final offsets = item.geometry
          .map((point) {
            final x =
                center.dx +
                (point.longitude - viewport.centerLongitude) * scale;
            final y =
                center.dy - (point.latitude - viewport.centerLatitude) * scale;
            return Offset(x, y);
          })
          .toList(growable: false);
      final path = _partialPath(offsets, reveal);
      final color = palette[item.visualVariant % palette.length];
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 10 + pulse * 5
          ..color = color.withAlpha(65 + (pulse * 50).round())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + pulse * 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3.5 + pulse
          ..color = color,
      );
    }
  }

  Path _partialPath(List<Offset> points, double fraction) {
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }
    final target = lengths.last * fraction;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      if (lengths[i] <= target) {
        path.lineTo(points[i].dx, points[i].dy);
        continue;
      }
      final segment = lengths[i] - lengths[i - 1];
      if (segment > 0 && target > lengths[i - 1]) {
        final ratio = (target - lengths[i - 1]) / segment;
        final point = Offset.lerp(points[i - 1], points[i], ratio)!;
        path.lineTo(point.dx, point.dy);
      }
      break;
    }
    return path;
  }

  @override
  bool shouldRepaint(_WorldNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.data != data;
}

class _MapChrome extends StatelessWidget {
  const _MapChrome({
    required this.data,
    required this.cameraBearing,
    required this.hasLastWorldDrive,
    required this.onBack,
    required this.onSettings,
    required this.onResetBearing,
    required this.onShowWorld,
    required this.onShowLastDrive,
    required this.onLocation,
  });

  final MyWorldMapData data;
  final double cameraBearing;
  final bool hasLastWorldDrive;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onResetBearing;
  final VoidCallback? onShowWorld;
  final VoidCallback onShowLastDrive;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(
      children: [
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _MapControl(
                tooltip: 'Geri',
                icon: Icons.arrow_back,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(child: _WorldStatsChip(data: data)),
              const SizedBox(width: 10),
              _MapControl(
                key: const Key('world_settings_button'),
                tooltip: 'Dünya Ayarları',
                icon: Icons.tune,
                onTap: onSettings,
              ),
            ],
          ),
        ),
        Positioned(
          right: 14,
          bottom: 26,
          child: Column(
            children: [
              if (cameraBearing.abs() > 2)
                _MapControl(
                  tooltip: 'Kuzeye dön',
                  icon: Icons.explore_outlined,
                  onTap: onResetBearing,
                ),
              if (cameraBearing.abs() > 2) const SizedBox(height: 9),
              _MapControl(
                key: const Key('show_my_world_button'),
                tooltip: 'Dünyamı Göster',
                icon: Icons.public,
                onTap: onShowWorld,
              ),
              const SizedBox(height: 9),
              _MapControl(
                key: const Key('show_last_world_drive_button'),
                tooltip: 'Son Sürüş',
                icon: Icons.history_toggle_off,
                onTap: hasLastWorldDrive ? onShowLastDrive : null,
              ),
              const SizedBox(height: 9),
              _MapControl(
                key: const Key('my_location_button'),
                tooltip: 'Konumum',
                icon: Icons.my_location,
                onTap: onLocation,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MyWorldSettingsSheet extends StatefulWidget {
  const MyWorldSettingsSheet({super.key, required this.store});
  final MyWorldSettingsStore store;

  @override
  State<MyWorldSettingsSheet> createState() => _MyWorldSettingsSheetState();
}

class _MyWorldSettingsSheetState extends State<MyWorldSettingsSheet> {
  late bool _skipIntro;

  @override
  void initState() {
    super.initState();
    _skipIntro = widget.store.skipIntroAnimation;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Material(
      color: const Color(0xff07172d),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 42,
                child: Divider(color: Colors.white30, thickness: 3),
              ),
            ),
            const Text(
              'Dünya Ayarları',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              key: const Key('skip_world_intro_switch'),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: const Color(0xff3b93ff),
              title: const Text('Dünya animasyonunu geç'),
              subtitle: const Text(
                'Bir sonraki açılışta haritayı doğrudan gösterir.',
                style: TextStyle(color: Color(0xff8fa1ba), fontSize: 12),
              ),
              value: _skipIntro,
              onChanged: (value) async {
                await widget.store.setSkipIntroAnimation(value);
                if (mounted) setState(() => _skipIntro = value);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class WorldTraceDetailSheet extends StatelessWidget {
  const WorldTraceDetailSheet({
    super.key,
    required this.detail,
    required this.onViewDrive,
  });

  final WorldTraceDetail detail;
  final VoidCallback onViewDrive;

  @override
  Widget build(BuildContext context) {
    final drive = detail.drive;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xff07172d),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xff27568d))),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 42,
                child: Divider(color: Colors.white30, thickness: 3),
              ),
              Row(
                children: [
                  const Text(
                    'Dünya Rekoru',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x223b93ff),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xff3b93ff)),
                    ),
                    child: const Text(
                      'REKOR',
                      style: TextStyle(
                        color: Color(0xff75c8ff),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDate(drive.date),
                  style: const TextStyle(
                    color: Color(0xff92a4bd),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _metric(
                    'Drive Score',
                    detail.score == null
                        ? 'Mevcut değil'
                        : detail.score!.totalScore.round().toString(),
                  ),
                  _metric(
                    'Sürüş Süresi',
                    _formatDuration(drive.durationSeconds),
                  ),
                  _metric('Maksimum Hız', '${drive.maxSpeed.round()} km/s'),
                  _metric('Ortalama Hız', '${drive.averageSpeed.round()} km/s'),
                  _metric('Toplam Mesafe', _formatDistance(drive.distance)),
                  _metric(
                    'Dünya’daki Rekor İzi',
                    _formatDistance(detail.activeWorldDistanceMeters),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('view_world_trace_drive_button'),
                  onPressed: onViewDrive,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff3b93ff),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Sürüşü Görüntüle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xff0a203a),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x442f79c8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xff8fa1ba), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0
        ? '$hours sa ${minutes.toString().padLeft(2, '0')} dk'
        : '$minutes dk';
  }

  static String _formatDistance(double meters) =>
      '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
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
      textAlign: TextAlign.center,
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
    shape: const CircleBorder(side: BorderSide(color: Color(0x663b93ff))),
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
  Widget build(BuildContext context) => ColoredBox(
    color: DriveMapVisuals.background,
    child: Center(
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
    ),
  );
}
