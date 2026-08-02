import '../services/analysis/telemetry_session.dart';
import '../services/analysis/flow_analyzer.dart';
import '../services/telemetry/telemetry_recorder.dart';
import '../services/route_service.dart';
import '../services/speed_service.dart';
import '../services/foreground_service.dart';
import '../widgets/drive_summary_dialog.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SpeedService speedService = SpeedService();
  final RouteService routeService = RouteService();
  final TelemetryRecorder telemetryRecorder =
    TelemetryRecorder();

  GoogleMapController? mapController;

  StreamSubscription<Position>? positionStream;

  bool isDriving = false;

  DateTime? driveStartTime;
  Duration driveDuration = Duration.zero;

  double maxSpeed = 0;
  double averageSpeed = 0;
  double currentSpeed = 0;

  Position? currentPosition;

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

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        17,
      ),
    );
  }

  Future<void> startDriving() async {
    if (isDriving) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ForegroundService.start() çağrıldı")),
    );

    await ForegroundService.start();

    setState(() {
      speedService.reset();
      routeService.reset();
      telemetryRecorder.clear();

      isDriving = true;

      averageSpeed = 0;
      maxSpeed = 0;

      driveStartTime = DateTime.now();
    });

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          setState(() {
            routeService.addPosition(position);

            speedService.update(position);

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
    await ForegroundService.stop();

    await positionStream?.cancel();

    setState(() {
      isDriving = false;
    });

    driveDuration = DateTime.now().difference(driveStartTime!);

    if (driveDuration.inSeconds > 0) {
      averageSpeed =
    (routeService.distance / 1000) /
    (driveDuration.inSeconds / 3600);
    }

    if (!mounted) return;

    final route = routeService.getRouteForSave();

    final session = TelemetrySession(
  samples: telemetryRecorder.samples,
);

final report =
    FlowAnalyzer().analyze(session);

debugPrint("========== FLOW ==========");
debugPrint(
    "Score : ${report.score.toStringAsFixed(1)}");
debugPrint(
    "Cruise : ${report.cruiseSpeed.toStringAsFixed(1)} km/h");
debugPrint(
    "Stability : ${report.speedStability.toStringAsFixed(1)}");
debugPrint(
    "Oscillation : ${report.oscillationCount}");

    await DriveSummaryDialog.show(
      context,
      flowReport: report,
      totalDistance: routeService.distance,
      driveDuration: driveDuration,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      mapImagePath: "",
      route: route,
    );

    debugPrint(
      "Telemetry Samples: ${telemetryRecorder.samples.length}",
  );
  }

  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
    await requestPermissions();
    await getCurrentLocation();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DriveIt Harita")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            polylines: routeService.polylines,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),

          Positioned(
            left: 16,
            bottom: 16,
            child: AnimatedOpacity(
              opacity: isDriving ? 1 : 0,
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (isDriving) {
            stopDriving();
          } else {
            startDriving();
          }
        },
        icon: Icon(isDriving ? Icons.stop : Icons.play_arrow),
        label: Text(isDriving ? "Sürüşü Bitir" : "Sürüşü Başlat"),
      ),
    );
  }
} //
