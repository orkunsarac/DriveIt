import '../services/foreground_service.dart';
import '../models/route_point.dart';
import '../widgets/drive_summary_dialog.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;

  StreamSubscription<Position>? positionStream;

bool isDriving = false;

List<LatLng> routePoints = [];

double totalDistance = 0;

DateTime? driveStartTime;
Duration driveDuration = Duration.zero;

double maxSpeed = 0;
double averageSpeed = 0;
double currentSpeed = 0;

Set<Polyline> polylines = {};

Position? currentPosition;
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
      LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      ),
      17,
    ),
  );
}

Future<void> startDriving() async {
  if (isDriving) return;

  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text("ForegroundService.start() çağrıldı"),
  ),
);

  await ForegroundService.start();

  setState(() {
    isDriving = true;
    routePoints.clear();
    totalDistance = 0;
    polylines.clear();

    averageSpeed = 0;
    maxSpeed = 0;

    driveStartTime = DateTime.now();
  });

  positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    ),
  ).listen((Position position) {
    setState(() {
      routePoints.add(
        LatLng(position.latitude, position.longitude),
      );

      double speedKmH = position.speed * 3.6;

      currentSpeed = speedKmH.clamp(0, 999);

      if (speedKmH > maxSpeed) {
        maxSpeed = speedKmH;
}

      if (routePoints.length > 1) {
  totalDistance += Geolocator.distanceBetween(
    routePoints[routePoints.length - 2].latitude,
    routePoints[routePoints.length - 2].longitude,
    routePoints.last.latitude,
    routePoints.last.longitude,
  );
}

      polylines = {
        Polyline(
          polylineId: const PolylineId("drive_route"),
          points: routePoints,
          color: Colors.blue,
          width: 6,
        ),
      };
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
      (totalDistance / 1000) / (driveDuration.inSeconds / 3600);
}

  if (!mounted) return;

final route = routePoints
    .map(
      (p) => RoutePoint(
        latitude: p.latitude,
        longitude: p.longitude,
      ),
    )
    .toList();

  await DriveSummaryDialog.show(
    context,
    totalDistance: totalDistance,
    driveDuration: driveDuration,
    averageSpeed: averageSpeed,
    maxSpeed: maxSpeed,
    mapImagePath: "",
    route: route,
);
}

  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 14,
  );

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    getCurrentLocation();
  });
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("DriveIt Harita"),
    ),
    body: Stack(
  children: [
    GoogleMap(
      initialCameraPosition: initialPosition,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      polylines: polylines,
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
          const Icon(
            Icons.speed,
            color: Colors.white,
            size: 20,
          ),
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
icon: Icon(
  isDriving ? Icons.stop : Icons.play_arrow,
),
label: Text(
  isDriving ? "Sürüşü Bitir" : "Sürüşü Başlat",
),
    ),
  );
}
} // 