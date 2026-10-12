import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/local_owner_lifecycle.dart';
import '../../theme/drive_map_visuals.dart';
import '../../widgets/local_owner_view.dart';
import 'group_drive_models.dart';

/// Existing Google Maps SDK, with its device-location layer always disabled.
/// Only the fake group's latest consented test points can become markers.
class GroupDriveMap extends StatelessWidget {
  const GroupDriveMap({super.key, required this.lease, required this.group});
  final LocalOwnerLease lease;
  final GroupDriveSnapshot group;
  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: lease,
    builder: (_) =>
        _GroupMap(key: ValueKey(group.id), lease: lease, group: group),
  );
}

class _GroupMap extends StatefulWidget {
  const _GroupMap({super.key, required this.lease, required this.group});
  final LocalOwnerLease lease;
  final GroupDriveSnapshot group;
  @override
  State<_GroupMap> createState() => _GroupMapState();
}

class _GroupMapState extends State<_GroupMap> {
  GoogleMapController? _controller;
  Timer? _freshness;
  late DateTime _now;
  late DateTime _receivedAt;
  String? _selected;
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
  }

  void _resetClock() {
    _now = widget.group.observedAt;
    _receivedAt = DateTime.now().toUtc();
    _scheduleFreshness();
  }

  List<GroupDriveMember> get _visible => widget.group.isActive
      ? widget.group.members
            .where(
              (member) =>
                  member.sharingStatus == GroupSharingStatus.sharing &&
                  member.location != null &&
                  !_now.difference(member.location!.recordedAt).isNegative &&
                  _now.difference(member.location!.recordedAt) <=
                      const Duration(minutes: 5),
            )
            .toList()
      : [];
  void _scheduleFreshness() {
    _freshness?.cancel();
    DateTime? next;
    for (final member in widget.group.members) {
      if (member.location == null) continue;
      for (final seconds in [15, 30, 300]) {
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
          final elapsed = DateTime.now().toUtc().difference(_receivedAt);
          final wallEstimate = widget.group.observedAt.add(
            elapsed.isNegative ? Duration.zero : elapsed,
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
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 15),
    );
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
        alpha: elapsed <= const Duration(seconds: 15)
            ? 1
            : elapsed <= const Duration(seconds: 30)
            ? .55
            : .3,
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
                '${visible.any((member) => member.location!.origin == GroupLocationOrigin.deviceGps) ? 'Cihaz GPS konumları' : 'Sentetik test konumları'} • ${markers.length} görünür üye',
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
}
