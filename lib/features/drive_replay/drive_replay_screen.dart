import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/drive_session.dart';
import '../../theme/drive_map_visuals.dart';
import 'drive_replay_controller.dart';

enum ReplayCameraMode { close, medium, overview, free }

class DriveReplayScreen extends StatefulWidget {
  final DriveSession drive;

  const DriveReplayScreen({super.key, required this.drive});

  @override
  State<DriveReplayScreen> createState() => _DriveReplayScreenState();
}

class _DriveReplayScreenState extends State<DriveReplayScreen>
    with SingleTickerProviderStateMixin {
  late final DriveReplayController _replay;
  late final Ticker _ticker;
  GoogleMapController? _mapController;
  BitmapDescriptor? _navigationIcon;
  Duration? _lastTick;
  Duration _lastRenderedTick = Duration.zero;
  DateTime _lastCameraUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  ReplayCameraMode _cameraMode = ReplayCameraMode.medium;
  bool _didAutoplay = false;
  int _activePointers = 0;
  int _programmaticCameraMoves = 0;

  @override
  void initState() {
    super.initState();
    _replay = DriveReplayController(widget.drive)
      ..addListener(_onReplayChanged);
    _ticker = createTicker(_onTick)..start();
    _loadNavigationIcon();
  }

  Future<void> _loadNavigationIcon() async {
    final icon = await DriveMapVisuals.createNavigationArrow();
    if (!mounted) return;
    setState(() => _navigationIcon = icon);
    _tryAutoplay();
  }

  void _tryAutoplay() {
    if (_didAutoplay ||
        _mapController == null ||
        _navigationIcon == null ||
        !_replay.canReplay) {
      return;
    }
    _didAutoplay = true;
    unawaited(
      _followCamera(force: true).whenComplete(() {
        if (mounted) _replay.play();
      }),
    );
  }

  void _onTick(Duration elapsed) {
    if (!_replay.isPlaying) {
      _lastTick = elapsed;
      return;
    }
    final previous = _lastTick ?? elapsed;
    // A 30 FPS visual update is smooth on the map while avoiding unnecessary
    // marker/polyline rebuilds on every display refresh.
    if (elapsed - _lastRenderedTick < const Duration(milliseconds: 33)) return;
    final delta = elapsed - previous;
    _lastTick = elapsed;
    _lastRenderedTick = elapsed;
    _replay.advance(delta);
  }

  void _onReplayChanged() {
    if (!mounted) return;
    setState(() {});
    if (_replay.isPlaying && _cameraMode != ReplayCameraMode.free) {
      _followCamera();
    }
    if (_replay.isComplete && _cameraMode != ReplayCameraMode.free) {
      _showEntireRoute();
    }
  }

  Future<void> _followCamera({bool force = false}) async {
    final controller = _mapController;
    if (controller == null ||
        !_replay.canReplay ||
        _cameraMode == ReplayCameraMode.free) {
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastCameraUpdate).inMilliseconds < 140) {
      return;
    }
    _lastCameraUpdate = now;
    final frame = _replay.frame;
    await _animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(frame.latitude, frame.longitude),
          zoom: switch (_cameraMode) {
            ReplayCameraMode.close => 17.8,
            ReplayCameraMode.medium => 16.3,
            ReplayCameraMode.overview => 14.5,
            ReplayCameraMode.free => 16.3,
          },
          bearing: _cameraMode == ReplayCameraMode.overview ? 0 : frame.heading,
          tilt: switch (_cameraMode) {
            ReplayCameraMode.close => 55,
            ReplayCameraMode.medium => 42,
            ReplayCameraMode.overview => 0,
            ReplayCameraMode.free => 0,
          },
        ),
      ),
    );
  }

  Future<void> _showEntireRoute() async {
    final controller = _mapController;
    final points = _replay.timeline;
    if (controller == null || points.length < 2) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    await _animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        62,
      ),
    );
  }

  void _changeCameraMode(ReplayCameraMode mode) {
    if (mode == ReplayCameraMode.free) return;
    setState(() => _cameraMode = mode);
    unawaited(_followCamera(force: true));
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;
    _programmaticCameraMoves++;
    try {
      await controller.animateCamera(update);
    } finally {
      // Some platform implementations deliver onCameraMoveStarted slightly
      // after animateCamera completes. Keep the guard for one short frame.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      _programmaticCameraMoves--;
    }
  }

  void _onCameraMoveStarted() {
    // Programmatic follow callbacks have no active pointer. A pointer on the
    // map means the user deliberately took control, even if a previous smooth
    // follow animation is just finishing.
    final isUserGesture = _activePointers > 0;
    final isOnlyProgrammaticMove =
        _programmaticCameraMoves > 0 && !isUserGesture;
    if (isOnlyProgrammaticMove || !isUserGesture) return;
    if (_cameraMode != ReplayCameraMode.free && mounted) {
      setState(() => _cameraMode = ReplayCameraMode.free);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _replay
      ..removeListener(_onReplayChanged)
      ..dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_replay.canReplay) {
      return _UnavailableReplay(onBack: () => Navigator.of(context).pop());
    }
    final frame = _replay.frame;
    final fullRoute = _replay.timeline
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final visited = <LatLng>[
      ...fullRoute.take(frame.segmentIndex + 1),
      LatLng(frame.latitude, frame.longitude),
    ];

    return Scaffold(
      backgroundColor: DriveMapVisuals.background,
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) => _activePointers++,
            onPointerUp: (_) =>
                _activePointers = (_activePointers - 1).clamp(0, 10),
            onPointerCancel: (_) =>
                _activePointers = (_activePointers - 1).clamp(0, 10),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: fullRoute.first,
                zoom: 16.3,
              ),
              style: DriveMapVisuals.darkMapStyle,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              onCameraMoveStarted: _onCameraMoveStarted,
              polylines: {
                Polyline(
                  polylineId: const PolylineId('replay_full_route'),
                  points: fullRoute,
                  color: DriveMapVisuals.pendingRouteColor,
                  width: DriveMapVisuals.activeRouteWidth,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
                Polyline(
                  polylineId: const PolylineId('replay_visited_route'),
                  points: visited,
                  color: DriveMapVisuals.activeRouteColor,
                  width: DriveMapVisuals.activeRouteWidth,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              },
              markers: {
                if (_navigationIcon != null)
                  Marker(
                    markerId: const MarkerId('driveit_replay_vehicle'),
                    position: LatLng(frame.latitude, frame.longitude),
                    icon: _navigationIcon!,
                    anchor: const Offset(.5, .72),
                    flat: true,
                    rotation: frame.heading,
                  ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
                _tryAutoplay();
              },
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _MapVignette())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              child: Column(
                children: [
                  _ReplayHeader(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 10),
                  _TelemetryHud(
                    speedKmh: frame.speedKmh,
                    distanceKm: frame.distanceMeters / 1000,
                    elapsed: frame.elapsed,
                  ),
                  const Spacer(),
                  if (_replay.isComplete) _CompletionCard(drive: widget.drive),
                  const SizedBox(height: 10),
                  _CameraModeSelector(
                    selected: _cameraMode,
                    onChanged: _changeCameraMode,
                  ),
                  const SizedBox(height: 10),
                  _ReplayControls(
                    replay: _replay,
                    onSeek: (value) {
                      _replay.seek(value);
                      if (_cameraMode != ReplayCameraMode.free) {
                        unawaited(_followCamera(force: true));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ReplayHeader({required this.onBack});

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 2),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sürüş Animasyonu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'DRIVEIT REPLAY',
                style: TextStyle(
                  color: Color(0xff5eabff),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.route_rounded, color: Color(0xff4e9fff)),
        const SizedBox(width: 10),
      ],
    ),
  );
}

class _TelemetryHud extends StatelessWidget {
  final double speedKmh;
  final double distanceKm;
  final Duration elapsed;
  const _TelemetryHud({
    required this.speedKmh,
    required this.distanceKm,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Row(
      children: [
        _HudValue(
          label: 'ANLIK HIZ',
          value: speedKmh.toStringAsFixed(0),
          unit: 'km/h',
          color: const Color(0xff4e9fff),
        ),
        const _HudDivider(),
        _HudValue(
          label: 'GİDİLEN MESAFE',
          value: distanceKm.toStringAsFixed(2),
          unit: 'km',
          color: const Color(0xff4be0ca),
        ),
        const _HudDivider(),
        _HudValue(
          label: 'GEÇEN SÜRE',
          value: _formatDuration(elapsed),
          color: const Color(0xffa66eff),
        ),
      ],
    ),
  );
}

class _HudValue extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  const _HudValue({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(Icons.circle, color: color, size: 7),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: Color(0xff91a4c2),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(color: Color(0xff91a4c2), fontSize: 8.5),
        ),
      ],
    ),
  );
}

class _HudDivider extends StatelessWidget {
  const _HudDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 42, color: const Color(0xff1b4779));
}

class _CameraModeSelector extends StatelessWidget {
  final ReplayCameraMode selected;
  final ValueChanged<ReplayCameraMode> onChanged;
  const _CameraModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: const EdgeInsets.all(4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected == ReplayCameraMode.free) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff102f55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff2f8dff)),
            ),
            child: const Text(
              'SERBEST',
              style: TextStyle(
                color: Color(0xff76b4ff),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
              ),
            ),
          ),
          const SizedBox(width: 3),
        ],
        ...const [
          ReplayCameraMode.close,
          ReplayCameraMode.medium,
          ReplayCameraMode.overview,
        ].map(
          (mode) => _ModeButton(
            label: switch (mode) {
              ReplayCameraMode.close => 'Yakın',
              ReplayCameraMode.medium => 'Orta',
              ReplayCameraMode.overview => 'Genel',
              ReplayCameraMode.free => 'Serbest',
            },
            selected: mode == selected,
            onTap: () => onChanged(mode),
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xff174782) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xff91a4c2),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _ReplayControls extends StatelessWidget {
  final DriveReplayController replay;
  final ValueChanged<double> onSeek;
  const _ReplayControls({required this.replay, required this.onSeek});

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    child: Column(
      children: [
        Row(
          children: [
            IconButton.filled(
              onPressed: replay.isPlaying ? replay.pause : replay.play,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xff2f8dff),
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                replay.isPlaying
                    ? Icons.pause_rounded
                    : replay.isComplete
                    ? Icons.replay_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xff3b93ff),
                  inactiveTrackColor: const Color(0xff173558),
                  thumbColor: const Color(0xff77c3ff),
                  overlayColor: const Color(0x333b93ff),
                  trackHeight: 3,
                ),
                child: Slider(value: replay.progress, onChanged: onSeek),
              ),
            ),
            PopupMenuButton<double>(
              initialValue: replay.displayPlaybackSpeed,
              onSelected: replay.setDisplayPlaybackSpeed,
              color: const Color(0xff0a1d36),
              tooltip: 'Oynatma hızı',
              itemBuilder: (_) => const [1.0, 2.0, 5.0, 10.0]
                  .map(
                    (speed) => PopupMenuItem(
                      value: speed,
                      child: Text('${speed.toInt()}×'),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xff23528a)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${replay.displayPlaybackSpeed.toInt()}×',
                  style: const TextStyle(
                    color: Color(0xff76b4ff),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          '${_formatDuration(replay.currentTime)} / ${_formatDuration(replay.totalDuration)}',
          style: const TextStyle(color: Color(0xff91a4c2), fontSize: 11),
        ),
      ],
    ),
  );
}

class _CompletionCard extends StatelessWidget {
  final DriveSession drive;
  const _CompletionCard({required this.drive});

  @override
  Widget build(BuildContext context) => _GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.flag_rounded, color: Color(0xff4be0ca), size: 21),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Sürüş tekrarı tamamlandı',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${(drive.distance / 1000).toStringAsFixed(2)} km',
          style: const TextStyle(color: Color(0xff76b4ff)),
        ),
        const SizedBox(width: 10),
        Text(
          '${drive.maxSpeed.toStringAsFixed(0)} km/h',
          style: const TextStyle(color: Color(0xffff9c3e)),
        ),
      ],
    ),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xe6091a31),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff1b4779)),
      boxShadow: const [
        BoxShadow(color: Color(0x332f8dff), blurRadius: 18, spreadRadius: 1),
      ],
    ),
    child: child,
  );
}

class _MapVignette extends StatelessWidget {
  const _MapVignette();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xff020c1d).withValues(alpha: .38),
          Colors.transparent,
          const Color(0xff020c1d).withValues(alpha: .5),
        ],
        stops: const [0, .5, 1],
      ),
    ),
  );
}

class _UnavailableReplay extends StatelessWidget {
  final VoidCallback onBack;
  const _UnavailableReplay({required this.onBack});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DriveMapVisuals.background,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const Spacer(),
            const Icon(Icons.route_rounded, color: Color(0xff4e9fff), size: 48),
            const SizedBox(height: 14),
            const Text(
              'Bu sürüş oynatılamıyor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sürüş animasyonu için en az iki geçerli rota noktası gerekiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff91a4c2)),
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
