import '../services/analysis/telemetry_session.dart';
import '../services/analysis/flow_analyzer.dart';
import '../services/telemetry/telemetry_recorder.dart';
import '../services/route_service.dart';
import '../services/speed_service.dart';
import '../services/foreground_service.dart';
import '../models/route_point.dart';
import '../widgets/drive_summary_dialog.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  final bool resumeDrive;
  final bool finishOnOpen;
  const MapScreen({
    super.key,
    this.resumeDrive = false,
    this.finishOnOpen = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SpeedService speedService = SpeedService();
  final RouteService routeService = RouteService();
  final TelemetryRecorder telemetryRecorder = TelemetryRecorder();

  GoogleMapController? mapController;

  StreamSubscription<Position>? positionStream;

  bool isDriving = false;
  bool isCountingDown = false;
  int countdownValue = 0;

  DateTime? driveStartTime;
  Duration driveDuration = Duration.zero;

  double maxSpeed = 0;
  double averageSpeed = 0;
  double currentSpeed = 0;
  int elapsedSeconds = 0;
  int stopCount = 0;
  int stoppedSeconds = 0;
  Timer? elapsedTimer;
  Timer? backgroundSyncTimer;
  int _backgroundRouteIndex = 0;

  Position? currentPosition;
  Set<Marker> locationMarkers = {};
  Set<Polyline> visiblePolylines = {};
  BitmapDescriptor? _arrowIcon;
  BitmapDescriptor? _stationaryIcon;
  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _finishIcon;
  double _lastIconZoom = 14;
  LatLng? _lastMarkerPosition;
  LatLng? _driveOrigin;
  double _markerRotation = 0;

  void _syncRouteOverlay() => visiblePolylines = routeService.polylines;

  bool get _hasStartMarker =>
      locationMarkers.any((marker) => marker.markerId.value == 'driveit_start');

  void _setStartMarker(LatLng position) {
    locationMarkers = {
      ...locationMarkers.where(
        (marker) => marker.markerId.value != 'driveit_start',
      ),
      Marker(
        markerId: const MarkerId('driveit_start'),
        position: position,
        icon:
            _startIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        anchor: const Offset(.5, .5),
        flat: true,
        infoWindow: const InfoWindow(title: 'Başlangıç noktası'),
      ),
    };
  }

  void _maybeSetStartMarker(double latitude, double longitude) {
    if (_hasStartMarker || !speedService.isMoving || _driveOrigin == null) {
      return;
    }
    final distanceFromOrigin = Geolocator.distanceBetween(
      _driveOrigin!.latitude,
      _driveOrigin!.longitude,
      latitude,
      longitude,
    );
    final elapsed = driveStartTime == null
        ? 0
        : DateTime.now().difference(driveStartTime!).inSeconds;
    // Keep the live arrow unobstructed at the beginning. Once movement is
    // confirmed, retain the true first point after 15 seconds or 1 km.
    if (distanceFromOrigin >= 1000 || elapsed >= 15) {
      _setStartMarker(_driveOrigin!);
    }
  }

  void _setFinishMarker(List<RoutePoint> route) {
    if (route.isEmpty) return;
    final end = route.last;
    final finish = Marker(
      markerId: const MarkerId('driveit_finish'),
      position: LatLng(end.latitude, end.longitude),
      icon:
          _finishIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
      anchor: const Offset(.5, .5),
      flat: true,
      infoWindow: const InfoWindow(title: 'Bitiş noktası'),
    );
    locationMarkers = {
      ...locationMarkers.where(
        (marker) => marker.markerId.value != 'driveit_finish',
      ),
      finish,
    };
  }

  Future<void> _createEndpointIcons() async {
    _startIcon = await _createRaceEndpointIcon(
      const ui.Color(0xff31e6ff),
      isFinish: false,
    );
    _finishIcon = await _createRaceEndpointIcon(
      const ui.Color(0xffff3d8d),
      isFinish: true,
    );
  }

  Future<BitmapDescriptor> _createRaceEndpointIcon(
    ui.Color color, {
    required bool isFinish,
  }) async {
    const size = 30.0;
    const pixelRatio = 4.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(pixelRatio);
    const center = ui.Offset(15, 15);
    canvas.drawCircle(
      center,
      10,
      ui.Paint()
        ..color = color.withAlpha(120)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      center,
      7,
      ui.Paint()..color = const ui.Color(0xff071426),
    );
    canvas.drawCircle(
      center,
      7,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
    canvas.drawCircle(
      center,
      isFinish ? 3.2 : 2.7,
      ui.Paint()..color = isFinish ? const ui.Color(0xffffffff) : color,
    );
    final image = await recorder.endRecording().toImage(
      (size * pixelRatio).toInt(),
      (size * pixelRatio).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      Uint8List.view(bytes!.buffer),
      imagePixelRatio: pixelRatio,
    );
  }

  Future<bool> _handleBack() async {
    if (isCountingDown) return false;
    if (!isDriving) return true;
    if (!mounted) return false;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Devam eden sürüş'),
        content: const Text(
          'Sürüşün hâlâ kaydediliyor. Sürüşü bitirmeden bu ekrandan çıkamazsın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Sürüşe dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'finish'),
            child: const Text('Sürüşü bitir ve kaydet'),
          ),
        ],
      ),
    );
    if (action == 'finish' && mounted) {
      await stopDriving();
    }
    return false;
  }

  Future<void> _createArrowIcon([double scale = 1]) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const pixelRatio = 4.0;
    final size = 36.0 * scale;
    final glow = ui.Paint()
      ..color = const ui.Color(0x99ff1744)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.scale(pixelRatio);
    final path = ui.Path()
      ..moveTo(size / 2, 4)
      ..lineTo(size - 9, size - 11)
      ..lineTo(size / 2, size - 19)
      ..lineTo(9, size - 11)
      ..close();
    canvas.drawPath(path, glow);
    final fill = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(size, size),
        [const ui.Color(0xffff4d6d), const ui.Color(0xffd50032)],
      );
    canvas.drawPath(path, fill);
    final edge = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const ui.Color(0xffffc1cc);
    canvas.drawPath(path, edge);
    final image = await recorder.endRecording().toImage(
      (size * pixelRatio).toInt(),
      (size * pixelRatio).toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null && mounted) {
      final icon = BitmapDescriptor.bytes(
        Uint8List.view(data.buffer),
        imagePixelRatio: pixelRatio,
      );
      setState(() {
        _arrowIcon = icon;
        if (_lastMarkerPosition != null) {
          locationMarkers = {
            ...locationMarkers.where(
              (marker) => marker.markerId.value != 'driveit_current_location',
            ),
            Marker(
              markerId: const MarkerId('driveit_current_location'),
              position: _lastMarkerPosition!,
              icon: speedService.isMoving ? icon : (_stationaryIcon ?? icon),
              anchor: speedService.isMoving
                  ? const Offset(.5, .72)
                  : const Offset(.5, .5),
              flat: true,
              rotation: _markerRotation,
            ),
          };
        }
      });
    }
  }

  void _updateLocationMarker(
    double latitude,
    double longitude, {
    double? heading,
  }) {
    final next = LatLng(latitude, longitude);
    final moving = speedService.isMoving;
    if (moving &&
        heading != null &&
        heading.isFinite &&
        heading >= 0 &&
        heading < 360) {
      _markerRotation = heading;
    } else if (moving && _lastMarkerPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastMarkerPosition!.latitude,
        _lastMarkerPosition!.longitude,
        latitude,
        longitude,
      );
      if (distance > 1) {
        _markerRotation = Geolocator.bearingBetween(
          _lastMarkerPosition!.latitude,
          _lastMarkerPosition!.longitude,
          latitude,
          longitude,
        );
      }
    }
    _lastMarkerPosition = next;
    locationMarkers = {
      ...locationMarkers.where(
        (marker) => marker.markerId.value != 'driveit_current_location',
      ),
      Marker(
        markerId: const MarkerId('driveit_current_location'),
        position: next,
        icon: moving
            ? (_arrowIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ))
            : (_stationaryIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  )),
        anchor: moving ? const Offset(.5, .72) : const Offset(.5, .5),
        flat: true,
        rotation: _markerRotation,
      ),
    };
  }

  Future<void> _createStationaryIcon() async {
    const logicalSize = 24.0;
    const pixelRatio = 4.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio);
    final center = const ui.Offset(logicalSize / 2, logicalSize / 2);
    canvas.drawCircle(
      center,
      7,
      ui.Paint()
        ..color = const ui.Color(0x8834d8ff)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      center,
      5,
      ui.Paint()..color = const ui.Color(0xff071426),
    );
    canvas.drawCircle(
      center,
      5,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const ui.Color(0xff48dfff),
    );
    final image = await recorder.endRecording().toImage(
      (logicalSize * pixelRatio).toInt(),
      (logicalSize * pixelRatio).toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null && mounted) {
      setState(
        () => _stationaryIcon = BitmapDescriptor.bytes(
          Uint8List.view(data.buffer),
          imagePixelRatio: pixelRatio,
        ),
      );
    }
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    currentPosition = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(
        () => _updateLocationMarker(
          currentPosition!.latitude,
          currentPosition!.longitude,
        ),
      );
    }

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        17,
      ),
    );
  }

  Future<void> startDriving() async {
    if (isDriving || isCountingDown) return;
    setState(() {
      isCountingDown = true;
      countdownValue = 3;
    });
    for (var value = 3; value >= 1; value--) {
      if (!mounted) return;
      setState(() => countdownValue = value);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() {
      isCountingDown = false;
      countdownValue = 0;
    });
    await _startDrivingSession();
  }

  Future<void> _startDrivingSession() async {
    if (isDriving) return;

    await ForegroundService.start();

    setState(() {
      speedService.reset();
      routeService.reset();
      visiblePolylines = {};
      _backgroundRouteIndex = 0;
      locationMarkers = locationMarkers
          .where(
            (marker) =>
                marker.markerId.value != 'driveit_start' &&
                marker.markerId.value != 'driveit_finish',
          )
          .toSet();
      telemetryRecorder.clear();

      isDriving = true;

      averageSpeed = 0;
      maxSpeed = 0;

      driveStartTime = DateTime.now();
      _driveOrigin = null;
      elapsedSeconds = 0;
      stopCount = 0;
      stoppedSeconds = 0;
    });
    elapsedTimer?.cancel();
    elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !isDriving) return;
      setState(() => elapsedSeconds++);
    });
    backgroundSyncTimer?.cancel();
    backgroundSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || !isDriving) return;
      final saved = await ForegroundService.readBackgroundRoute();
      if (saved.isEmpty) return;
      if (!mounted) return;
      setState(() {
        final newPoints = saved.skip(_backgroundRouteIndex).toList();
        _backgroundRouteIndex = saved.length;
        for (final point in newPoints) {
          final latitude = point['lat'];
          final longitude = point['lng'];
          final accuracy = point['accuracy'];
          if (latitude is num && longitude is num) {
            routeService.addCoordinate(
              latitude.toDouble(),
              longitude.toDouble(),
              accuracy: accuracy is num ? accuracy.toDouble() : null,
            );
            _syncRouteOverlay();
          }
        }
        final last = saved.last;
        final latitude = last['lat'];
        final longitude = last['lng'];
        final heading = last['heading'];
        if (latitude is num && longitude is num) {
          _updateLocationMarker(
            latitude.toDouble(),
            longitude.toDouble(),
            heading: heading is num ? heading.toDouble() : null,
          );
        }
      });
    });

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            intervalDuration: Duration(milliseconds: 500),
          ),
        ).listen((Position position) {
          setState(() {
            _driveOrigin ??= LatLng(position.latitude, position.longitude);
            speedService.update(position);
            _updateLocationMarker(
              position.latitude,
              position.longitude,
              heading: position.heading,
            );
            _maybeSetStartMarker(position.latitude, position.longitude);

            telemetryRecorder.add(
              position: position,
              distance: routeService.lastSegmentDistance,
              acceleration: 0,
            );

            currentSpeed = speedService.currentSpeed;
            maxSpeed = speedService.maxSpeed;
          });

          mapController?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        });
  }

  Future<void> stopDriving() async {
    // Capture foreground points before stopping; service shutdown persistence
    // is asynchronous and must not race with the final session snapshot.
    final routeBeforeStop = routeService.getRouteForSave();
    await ForegroundService.stop();
    elapsedTimer?.cancel();
    backgroundSyncTimer?.cancel();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    stopCount = await ForegroundService.readStopCount();
    stoppedSeconds = await ForegroundService.readStoppedSeconds();
    final backgroundRoute = await ForegroundService.readBackgroundRoute();
    final remainingBackgroundPoints = backgroundRoute.skip(
      _backgroundRouteIndex,
    );
    for (final point in remainingBackgroundPoints) {
      final latitude = point['lat'];
      final longitude = point['lng'];
      final accuracy = point['accuracy'];
      if (latitude is num && longitude is num) {
        routeService.addCoordinate(
          latitude.toDouble(),
          longitude.toDouble(),
          accuracy: accuracy is num ? accuracy.toDouble() : null,
        );
      }
    }
    _backgroundRouteIndex = backgroundRoute.length;
    _syncRouteOverlay();

    await positionStream?.cancel();

    setState(() {
      isDriving = false;
    });

    driveDuration = DateTime.now().difference(driveStartTime!);

    if (driveDuration.inSeconds > 0) {
      averageSpeed =
          (routeService.distance / 1000) / (driveDuration.inSeconds / 3600);
    }

    if (!mounted) return;

    final route = routeService.getRouteForSave();
    if (route.isEmpty && routeBeforeStop.isNotEmpty) {
      route.addAll(routeBeforeStop);
    }
    if (mounted) {
      setState(() => _setFinishMarker(route));
    }

    final session = TelemetrySession(samples: telemetryRecorder.samples);

    final report = FlowAnalyzer().analyze(session);

    debugPrint("========== FLOW ==========");
    debugPrint("Score : ${report.score.toStringAsFixed(1)}");
    debugPrint("Cruise : ${report.cruiseSpeed.toStringAsFixed(1)} km/h");
    debugPrint("Stability : ${report.speedStability.toStringAsFixed(1)}");
    debugPrint("Oscillation : ${report.oscillationCount}");

    await DriveSummaryDialog.show(
      context,
      flowReport: report,
      totalDistance: routeService.distance,
      driveDuration: driveDuration,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      mapImagePath: "",
      route: route,
      stopCount: stopCount,
      stoppedSeconds: stoppedSeconds,
    );

    debugPrint("Telemetry Samples: ${telemetryRecorder.samples.length}");
  }

  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();

    if (widget.resumeDrive) {
      isDriving = true;
      driveStartTime = null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await requestPermissions();
      await _createArrowIcon();
      await _createStationaryIcon();
      await _createEndpointIcons();
      await getCurrentLocation();
      if (widget.resumeDrive) {
        driveStartTime =
            await ForegroundService.readDriveStartTime() ?? DateTime.now();
        elapsedSeconds = DateTime.now().difference(driveStartTime!).inSeconds;
        elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !isDriving || driveStartTime == null) return;
          setState(
            () => elapsedSeconds = DateTime.now()
                .difference(driveStartTime!)
                .inSeconds,
          );
        });
        final savedRoute = await ForegroundService.readBackgroundRoute();
        for (final point in savedRoute) {
          final latitude = point['lat'];
          final longitude = point['lng'];
          final accuracy = point['accuracy'];
          if (latitude is num && longitude is num) {
            routeService.addCoordinate(
              latitude.toDouble(),
              longitude.toDouble(),
              accuracy: accuracy is num ? accuracy.toDouble() : null,
            );
            _syncRouteOverlay();
          }
        }
        _backgroundRouteIndex = savedRoute.length;
        if (savedRoute.isNotEmpty &&
            savedRoute.first['lat'] is num &&
            savedRoute.first['lng'] is num) {
          _driveOrigin = LatLng(
            (savedRoute.first['lat'] as num).toDouble(),
            (savedRoute.first['lng'] as num).toDouble(),
          );
        }
        positionStream =
            Geolocator.getPositionStream(
              locationSettings: AndroidSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 0,
                intervalDuration: Duration(milliseconds: 500),
              ),
            ).listen((position) {
              if (!mounted) return;
              setState(() {
                _driveOrigin ??= LatLng(position.latitude, position.longitude);
                speedService.update(position);
                _updateLocationMarker(
                  position.latitude,
                  position.longitude,
                  heading: position.heading,
                );
                _maybeSetStartMarker(position.latitude, position.longitude);
                currentSpeed = speedService.currentSpeed;
                maxSpeed = speedService.maxSpeed;
              });
            });
        backgroundSyncTimer = Timer.periodic(const Duration(seconds: 1), (
          _,
        ) async {
          if (!mounted || !isDriving) return;
          final saved = await ForegroundService.readBackgroundRoute();
          if (saved.length <= _backgroundRouteIndex || !mounted) return;
          final newPoints = saved.skip(_backgroundRouteIndex).toList();
          _backgroundRouteIndex = saved.length;
          setState(() {
            for (final point in newPoints) {
              final latitude = point['lat'];
              final longitude = point['lng'];
              final accuracy = point['accuracy'];
              if (latitude is num && longitude is num) {
                routeService.addCoordinate(
                  latitude.toDouble(),
                  longitude.toDouble(),
                  accuracy: accuracy is num ? accuracy.toDouble() : null,
                );
              }
            }
            _syncRouteOverlay();
          });
        });
        if (widget.finishOnOpen) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (mounted) await stopDriving();
        }
      }
    });
  }

  @override
  void dispose() {
    elapsedTimer?.cancel();
    backgroundSyncTimer?.cancel();
    positionStream?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: const Color(0xff071225),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: initialPosition,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: locationMarkers,
              onCameraMove: (camera) {
                if ((camera.zoom - _lastIconZoom).abs() > .8) {
                  _lastIconZoom = camera.zoom;
                  final scale = (camera.zoom / 14).clamp(.55, 1.0).toDouble();
                  _createArrowIcon(scale);
                }
              },
              polylines: visiblePolylines,
              onMapCreated: (controller) {
                mapController = controller;
                final position = currentPosition;
                if (position != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(position.latitude, position.longitude),
                      16,
                    ),
                  );
                }
                controller.setMapStyle(
                  '''[{"elementType":"geometry","stylers":[{"color":"#0b172b"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#91a4c2"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#0b172b"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#1d3150"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#061124"}]},{"featureType":"poi","stylers":[{"visibility":"off"}]}]''',
                );
              },
            ),

            Positioned(
              left: 16,
              bottom: 16,
              child: AnimatedOpacity(
                opacity: 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "${currentSpeed.toStringAsFixed(0)} km/h",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    _control(
                      Icons.arrow_back,
                      () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xee101c32),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDriving
                                    ? const Color(0xff48e8cb)
                                    : Colors.blueGrey.shade300,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'SÜRÜŞ MERKEZİ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatElapsed(),
                              style: const TextStyle(
                                color: Color(0xff4de3c8),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _control(Icons.my_location, getCurrentLocation),
                  ],
                ),
              ),
            ),
            Positioned(left: 16, right: 16, bottom: 16, child: _drivePanel()),
            if (isCountingDown) _countdownOverlay(),
          ],
        ),
        floatingActionButton: null /* FloatingActionButton.extended(
        onPressed: () {
          if (isDriving) {
            stopDriving();
          } else {
            startDriving();
          }
        },
        icon: Icon(isDriving ? Icons.stop : Icons.play_arrow),
        label: Text(isDriving ? "Sürüşü Bitir" : "Sürüşü Başlat"),
      ), */,
      ),
    );
  }

  Widget _control(IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xee101c32),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 58,
        height: 58,
        child: Icon(icon, color: Colors.white, size: 31),
      ),
    ),
  );

  Widget _countdownOverlay() => Positioned.fill(
    child: IgnorePointer(
      child: Container(
        color: const Color(0x99030b1b),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            '$countdownValue',
            key: ValueKey(countdownValue),
            style: const TextStyle(
              color: Color(0xff72b7ff),
              fontSize: 132,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: Color(0xff1688ff), blurRadius: 28),
                Shadow(color: Color(0xff54d9ff), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _drivePanel() => Container(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
    decoration: BoxDecoration(
      color: const Color(0xf20e182b),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white12),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 22)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _stat(
              '${currentSpeed.toStringAsFixed(0)}',
              'KM/SA',
              const Color(0xff50e4cb),
            ),
            _divider(),
            _stat(
              (routeService.distance / 1000).toStringAsFixed(2),
              'KM',
              Colors.white,
            ),
            _divider(),
            _stat(maxSpeed.toStringAsFixed(0), 'MAKS.', Colors.white),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 62,
          child: ElevatedButton.icon(
            onPressed: isDriving ? stopDriving : startDriving,
            icon: Icon(
              isDriving ? Icons.stop : Icons.play_arrow,
              color: Colors.black,
              size: 26,
            ),
            label: Text(
              isDriving ? 'SÜRÜŞÜ BİTİR' : 'SÜRÜŞE BAŞLA',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff72a6ff),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _stat(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 31,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );
  String _formatElapsed() =>
      '${(elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}';
  Widget _divider() => Container(width: 1, height: 58, color: Colors.white24);
} //
