import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/drive_session.dart';

class DriveDetailScreen extends StatefulWidget {
  final DriveSession drive;

  const DriveDetailScreen({
    super.key,
    required this.drive,
  });

  @override
  State<DriveDetailScreen> createState() => _DriveDetailScreenState();
}

class _DriveDetailScreenState extends State<DriveDetailScreen> {
  GoogleMapController? _controller;

  late final Set<Polyline> _polylines;
  late final Set<Marker> _markers;

  @override
  void initState() {
    super.initState();

    _createPolyline();
    _createMarkers();
  }

  void _createPolyline() {
    final points = widget.drive.route
        .map(
          (e) => LatLng(
            e.latitude,
            e.longitude,
          ),
        )
        .toList();

    _polylines = {
      Polyline(
        polylineId: const PolylineId("drive"),
        points: points,
        width: 6,
        color: Colors.blue,
      ),
    };
  }

  void _createMarkers() {
    if (widget.drive.route.isEmpty) {
      _markers = {};
      return;
    }

    final start = widget.drive.route.first;
    final finish = widget.drive.route.last;

    _markers = {
      Marker(
        markerId: const MarkerId("start"),
        position: LatLng(
          start.latitude,
          start.longitude,
        ),
        infoWindow: const InfoWindow(
          title: "Başlangıç",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      ),

      Marker(
        markerId: const MarkerId("finish"),
        position: LatLng(
          finish.latitude,
          finish.longitude,
        ),
        infoWindow: const InfoWindow(
          title: "Bitiş",
        ),
      ),
    };
  }

  void _fitRoute() {
    if (_controller == null) return;

    if (widget.drive.route.isEmpty) return;

    double minLat = widget.drive.route.first.latitude;
    double maxLat = widget.drive.route.first.latitude;
    double minLng = widget.drive.route.first.longitude;
    double maxLng = widget.drive.route.first.longitude;

    for (final p in widget.drive.route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;

      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            minLat,
            minLng,
          ),
          northeast: LatLng(
            maxLat,
            maxLng,
          ),
        ),
        70,
      ),
    );
  }

  String _duration() {
    final d = Duration(
      seconds: widget.drive.durationSeconds,
    );

    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) {
      return "$h saat $m dk";
    }

    return "$m dk $s sn";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sürüş Detayı"),
      ),
      body: Column(
        children: [          Hero(
            tag: widget.drive.id,
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.drive.route.isNotEmpty
                      ? LatLng(
                          widget.drive.route.first.latitude,
                          widget.drive.route.first.longitude,
                        )
                      : const LatLng(39.925533, 32.866287),
                  zoom: 15,
                ),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                compassEnabled: true,
                polylines: _polylines,
                markers: _markers,
                onMapCreated: (controller) {
                  _controller = controller;

                  Future.delayed(
                    const Duration(milliseconds: 300),
                    _fitRoute,
                  );
                },
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.route,
                          title: "Mesafe",
                          value:
                              "${(widget.drive.distance / 1000).toStringAsFixed(2)} km",
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer,
                          title: "Süre",
                          value: _duration(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.speed,
                          title: "Ort. Hız",
                          value:
                              "${widget.drive.averageSpeed.toStringAsFixed(1)} km/h",
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.flash_on,
                          title: "Maks. Hız",
                          value:
                              "${widget.drive.maxSpeed.toStringAsFixed(1)} km/h",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 28,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Sürüş Tarihi",
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${widget.drive.date.day}.${widget.drive.date.month}.${widget.drive.date.year}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
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
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 14,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.blue,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}