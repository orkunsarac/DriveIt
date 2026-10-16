import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/local_owner_lifecycle.dart';
import '../../theme/drive_map_visuals.dart';
import '../../widgets/local_owner_view.dart';
import 'group_drive_models.dart';

/// Existing Google Maps SDK, with its device-location layer always disabled.
/// Only the current, consented group locations can become markers.
class GroupDriveMap extends StatelessWidget {
  const GroupDriveMap({
    super.key,
    required this.lease,
    required this.group,
    required this.isSimulation,
  });
  final LocalOwnerLease lease;
  final GroupDriveSnapshot group;
  final bool isSimulation;
  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: lease,
    builder: (_) => _GroupMap(
      key: ValueKey(group.id),
      lease: lease,
      group: group,
      isSimulation: isSimulation,
    ),
  );
}

class _GroupMap extends StatefulWidget {
  const _GroupMap({
    super.key,
    required this.lease,
    required this.group,
    required this.isSimulation,
  });
  final LocalOwnerLease lease;
  final GroupDriveSnapshot group;
  final bool isSimulation;
  @override
  State<_GroupMap> createState() => _GroupMapState();
}

class _GroupMapState extends State<_GroupMap> {
  GoogleMapController? _controller;
  Timer? _freshness;
  late DateTime _now;
  final Stopwatch _elapsedSinceSnapshot = Stopwatch();
  String? _selected;
  bool _userMovedCamera = false;
  bool _programmaticCameraMove = false;
  bool _autoFocused = false;
  bool get _current => mounted && widget.lease.isCurrent;
  @override
  void initState() {
    super.initState();
    _resetClock();
  }

  @override
  void didUpdateWidget(covariant _GroupMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetClock();
    if (!_visible.any((member) => member.membershipId == _selected)) {
      _selected = null;
    }
    if (_visible.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current) unawaited(_autoFocus());
      });
    }
  }

  void _resetClock() {
    _now = widget.group.observedAt;
    _elapsedSinceSnapshot
      ..reset()
      ..start();
    _scheduleFreshness();
  }

  List<GroupDriveMember> get _visible => widget.group.isActive
      ? widget.group.members
            .where(
              (member) =>
                  member.sharingStatus == GroupSharingStatus.sharing &&
                  member.location != null &&
                  isGroupGpsTimestampFresh(member.location!.recordedAt, _now),
            )
            .toList()
      : [];
  void _scheduleFreshness() {
    _freshness?.cancel();
    DateTime? next;
    for (final member in widget.group.members) {
      if (member.location == null) continue;
      for (final seconds in [15]) {
        final boundary = member.location!.recordedAt.add(
          Duration(seconds: seconds, milliseconds: 1),
        );
        if (boundary.isAfter(_now) &&
            (next == null || boundary.isBefore(next))) {
          next = boundary;
        }
      }
    }
    if (next != null) {
      final deadline = next;
      _freshness = Timer(deadline.difference(_now), () {
        if (!_current) return;
        setState(() {
          final wallEstimate = estimateGroupServerTime(
            widget.group.observedAt,
            _elapsedSinceSnapshot.elapsed,
          );
          _now = wallEstimate.isAfter(deadline) ? wallEstimate : deadline;
          if (!_visible.any((member) => member.membershipId == _selected)) {
            _selected = null;
          }
        });
        _scheduleFreshness();
      });
    }
  }

  Future<void> _focus(GroupDriveMember member) async {
    if (!_current ||
        !_visible.any((m) => m.membershipId == member.membershipId)) {
      return;
    }
    setState(() => _selected = member.membershipId);
    final controller = _controller;
    if (controller == null) return;
    final point = member.location!;
    // No delayed camera callback: validate this exact controller immediately
    // before issuing the command. Dispose clears it and cancels freshness work.
    if (!_current || !identical(controller, _controller)) return;
    await _animateCamera(
      controller,
      CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 15),
    );
  }

  Future<void> _autoFocus() async {
    if (!_current || _autoFocused || _userMovedCamera || _visible.isEmpty) {
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    final points = _visible
        .map((member) => member.location!)
        .toList(growable: false);
    _autoFocused = true;
    if (points.length == 1 ||
        points.every(
          (point) =>
              point.latitude == points.first.latitude &&
              point.longitude == points.first.longitude,
        )) {
      await _animateCamera(
        controller,
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          15,
        ),
      );
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(
        points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b),
        points.map((point) => point.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b),
        points.map((point) => point.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );
    await _animateCamera(controller, CameraUpdate.newLatLngBounds(bounds, 48));
  }

  Future<void> _animateCamera(
    GoogleMapController controller,
    CameraUpdate update,
  ) async {
    if (!_current || !identical(controller, _controller)) return;
    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(update);
    } finally {
      _programmaticCameraMove = false;
    }
  }

  @override
  void dispose() {
    _freshness?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selected = visible
        .where((member) => member.membershipId == _selected)
        .firstOrNull;
    final own = visible
        .where((member) => member.accountId == widget.lease.owner.userId)
        .firstOrNull;
    final center = own ?? visible.firstOrNull;
    final markers = visible.map((member) {
      final point = member.location!;
      final elapsed = _now.difference(point.recordedAt);
      final age = elapsed.inSeconds;
      final mine = member.accountId == widget.lease.owner.userId;
      const hues = <double>[0, 35, 65, 100, 140, 175, 230, 275, 320, 345];
      return Marker(
        markerId: MarkerId(member.membershipId),
        position: LatLng(point.latitude, point.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          mine ? BitmapDescriptor.hueAzure : hues[member.colorIndex],
        ),
        alpha: 1,
        infoWindow: InfoWindow(
          title: '${member.displayName}${mine ? ' (Sen)' : ''}',
          snippet:
              '${point.origin == GroupLocationOrigin.synthetic ? 'Sentetik' : 'Cihaz GPS (${point.accuracyMeters!.round()} m)'} • $age sn önce',
        ),
        onTap: () => unawaited(_focus(member)),
      );
    }).toSet();
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          key: const Key('group_google_map'),
          style: DriveMapVisuals.darkMapStyle,
          initialCameraPosition: CameraPosition(
            target: center == null
                ? const LatLng(0, 0)
                : LatLng(center.location!.latitude, center.location!.longitude),
            zoom: center == null ? 2 : 13,
          ),
          markers: markers,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            if (!_current) {
              controller.dispose();
              return;
            }
            final old = _controller;
            _controller = controller;
            if (!identical(old, controller)) old?.dispose();
            if (_visible.isNotEmpty) unawaited(_autoFocus());
          },
          onCameraMoveStarted: () {
            if (!_programmaticCameraMove) _userMovedCamera = true;
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          right: 8,
          child: IgnorePointer(
            child: Container(
              color: const Color(0xcc020a18),
              padding: const EdgeInsets.all(8),
              child: Text(
                _statusLabel(visible),
                key: const Key('group_marker_count'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                color: const Color(0xcc020a18),
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Seçili: ${selected.displayName} • ${selected.location!.origin == GroupLocationOrigin.synthetic ? 'Sentetik' : 'Cihaz GPS'}',
                  key: const Key('group_selected_member'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _statusLabel(List<GroupDriveMember> visible) {
    if (widget.isSimulation) {
      return 'Sentetik test konumları • ${visible.length} görünür üye';
    }
    final gpsCount = visible
        .where(
          (member) => member.location!.origin == GroupLocationOrigin.deviceGps,
        )
        .length;
    return gpsCount == 0
        ? 'Henüz canlı konum alınmadı'
        : 'Canlı GPS • $gpsCount görünür üye';
  }
}
