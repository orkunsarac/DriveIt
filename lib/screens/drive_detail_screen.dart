import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/drive_session.dart';
import '../services/drive_storage_service.dart';

class DriveDetailScreen extends StatefulWidget {
  final DriveSession drive;

  const DriveDetailScreen({super.key, required this.drive});

  @override
  State<DriveDetailScreen> createState() => _DriveDetailScreenState();
}

class _DriveDetailScreenState extends State<DriveDetailScreen> {
  static const _background = Color(0xff020c1d);
  static const _blue = Color(0xff3b93ff);
  static const _darkMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#0b172b"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#91a4c2"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#0b172b"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1d3150"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#12233d"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#061124"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]}
  ]''';

  GoogleMapController? _mapController;
  late final Set<Polyline> _polylines;
  Set<Marker> _markers = {};
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: DriveStorageService.getDriveName(widget.drive.id),
    );
    _createPolyline();
    _createMarkers();
    _loadEndpointIcons();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createPolyline() {
    final points = widget.drive.route
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    _polylines = {
      if (points.length > 1)
        Polyline(
          polylineId: const PolylineId('drive'),
          points: points,
          width: 6,
          color: _blue,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };
  }

  void _createMarkers({
    BitmapDescriptor? startIcon,
    BitmapDescriptor? finishIcon,
  }) {
    if (widget.drive.route.isEmpty) {
      _markers = {};
      return;
    }

    // Wait for the small neon assets instead of showing large Google pins.
    if (startIcon == null || finishIcon == null) {
      _markers = {};
      return;
    }

    final start = widget.drive.route.first;
    final finish = widget.drive.route.last;
    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(start.latitude, start.longitude),
        infoWindow: const InfoWindow(title: 'Başlangıç'),
        icon: startIcon,
        anchor: const Offset(.5, .5),
      ),
      Marker(
        markerId: const MarkerId('finish'),
        position: LatLng(finish.latitude, finish.longitude),
        infoWindow: const InfoWindow(title: 'Bitiş'),
        icon: finishIcon,
        anchor: const Offset(.5, .5),
      ),
    };
  }

  Future<void> _loadEndpointIcons() async {
    final start = await _createRaceEndpointIcon(
      const ui.Color(0xff42d8ff),
      isFinish: false,
    );
    final finish = await _createRaceEndpointIcon(
      const ui.Color(0xffef405d),
      isFinish: true,
    );
    if (!mounted) return;
    setState(() => _createMarkers(startIcon: start, finishIcon: finish));
  }

  Future<BitmapDescriptor> _createRaceEndpointIcon(
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

  void _fitRoute() {
    final controller = _mapController;
    final route = widget.drive.route;
    if (controller == null || route.isEmpty) return;
    if (route.length == 1) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(route.first.latitude, route.first.longitude),
          15,
        ),
      );
      return;
    }

    var minLat = route.first.latitude;
    var maxLat = route.first.latitude;
    var minLng = route.first.longitude;
    var maxLng = route.first.longitude;
    for (final point in route.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    if ((maxLat - minLat).abs() < 0.00001 &&
        (maxLng - minLng).abs() < 0.00001) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15),
      );
      return;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        52,
      ),
    );
  }

  Future<void> _saveName() async {
    await DriveStorageService.saveDriveName(
      widget.drive.id,
      _nameController.text,
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff102747),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Text('Sürüş adı kaydedildi'),
      ),
    );
  }

  String _duration() {
    final duration = Duration(seconds: widget.drive.durationSeconds);
    if (duration.inHours > 0) {
      return '${duration.inHours} sa ${duration.inMinutes.remainder(60)} dk';
    }
    return '${duration.inMinutes} dk ${duration.inSeconds.remainder(60)} sn';
  }

  String _stoppedDuration() {
    final duration = Duration(seconds: widget.drive.stoppedSeconds);
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes} dk ${duration.inSeconds.remainder(60)} sn';
    }
    return '${duration.inSeconds} sn';
  }

  String _date() {
    final date = widget.drive.date;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mapHeight = (width * 0.77).clamp(250.0, 360.0).toDouble();
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                title: _nameController.text.isEmpty
                    ? 'Sürüş detayı'
                    : _nameController.text,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: mapHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xff1b4779),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.drive.route.isNotEmpty
                            ? LatLng(
                                widget.drive.route.first.latitude,
                                widget.drive.route.first.longitude,
                              )
                            : const LatLng(39.925533, 32.866287),
                        zoom: 14,
                      ),
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      // The detail page is a scroll view. Eagerly claim
                      // gestures inside the map so vertical drags are not
                      // routed to the page's parent scroll view.
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                      style: _darkMapStyle,
                      polylines: _polylines,
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        Future.delayed(
                          const Duration(milliseconds: 350),
                          _fitRoute,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NameEditor(controller: _nameController, onSave: _saveName),
                    const SizedBox(height: 16),
                    const Text(
                      'Sürüş özeti',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _DetailStat(
                            icon: Icons.speed_rounded,
                            title: 'Ortalama hız',
                            value:
                                '${widget.drive.averageSpeed.toStringAsFixed(1)} km/h',
                            color: const Color(0xff4bb7ff),
                          ),
                          _DetailStat(
                            icon: Icons.route_rounded,
                            title: 'Toplam mesafe',
                            value:
                                '${(widget.drive.distance / 1000).toStringAsFixed(2)} km',
                            color: const Color(0xff4be0ca),
                          ),
                          _DetailStat(
                            icon: Icons.timer_outlined,
                            title: 'Sürüş süresi',
                            value: _duration(),
                            color: const Color(0xffa66eff),
                          ),
                          _DetailStat(
                            icon: Icons.bolt_rounded,
                            title: 'Maksimum hız',
                            value:
                                '${widget.drive.maxSpeed.toStringAsFixed(1)} km/h',
                            color: const Color(0xffff9c3e),
                          ),
                          _DetailStat(
                            icon: Icons.calendar_month_rounded,
                            title: 'Sürüş tarihi',
                            value: _date(),
                            color: const Color(0xff6faeff),
                          ),
                          _DetailStat(
                            icon: Icons.pause_circle_outline_rounded,
                            title: 'Duruş sayısı',
                            value: '${widget.drive.stopCount}',
                            color: const Color(0xffff6b8a),
                          ),
                          _DetailStat(
                            icon: Icons.hourglass_bottom_rounded,
                            title: 'Toplam duruş',
                            value: _stoppedDuration(),
                            color: const Color(0xffcf76ff),
                          ),
                        ];
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: cards
                              .map(
                                (card) => SizedBox(
                                  width: (constraints.maxWidth - 10) / 2,
                                  child: card,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Row(
        children: [
          Material(
            color: const Color(0xff0a1d36),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.route_rounded, color: Color(0xff4e9fff), size: 25),
        ],
      ),
    );
  }
}

class _NameEditor extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  const _NameEditor({required this.controller, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xff091a31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff1b4779)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, color: Color(0xff76b4ff), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Bu sürüşe bir isim ver',
                hintStyle: TextStyle(color: Color(0xff7992b2), fontSize: 14),
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
          TextButton(
            onPressed: onSave,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xff76b4ff),
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _DetailStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xff091a31),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xff173b66)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xff8ea5c2), fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
