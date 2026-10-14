import 'dart:io';
import 'package:geolocator/geolocator.dart';

class GroupGpsException implements Exception {
  const GroupGpsException(this.code);
  final String code;
}

abstract interface class GroupGpsSource {
  Future<void> requestAccess();
  Future<bool> hasAccess();
  Stream<Position> positions();
}

abstract interface class GroupGpsDiagnosticSource implements GroupGpsSource {
  void Function(String event)? get diagnostics;
}

/// Visible-app access only. Never configures a Geolocator foreground
/// notification and never starts/stops DriveIt's recording foreground service.
class AndroidGroupGpsSource implements GroupGpsDiagnosticSource {
  AndroidGroupGpsSource({
    GeolocatorPlatform? platform,
    this._diagnostics,
  })
    : _platform = platform ?? GeolocatorPlatform.instance,
      _injected = platform != null;
  final GeolocatorPlatform _platform;
  final bool _injected;
  final void Function(String event)? _diagnostics;
  @override
  void Function(String event)? get diagnostics => _diagnostics;
  void _android() {
    if (!Platform.isAndroid && !_injected) {
      throw const GroupGpsException('android_required');
    }
  }

  bool _allowed(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
  @override
  Future<void> requestAccess() async {
    _android();
    final enabled = await _platform.isLocationServiceEnabled();
    _diagnostics?.call('location_services_enabled=$enabled');
    if (!enabled) {
      throw const GroupGpsException('location_disabled');
    }
    var permission = await _platform.checkPermission();
    _diagnostics?.call('permission_before_request=${permission.name}');
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }
    _diagnostics?.call('permission_after_request=${permission.name}');
    if (!_allowed(permission)) {
      throw GroupGpsException(
        permission == LocationPermission.deniedForever
            ? 'permission_denied_forever'
            : 'permission_denied',
      );
    }
  }

  @override
  Future<bool> hasAccess() async {
    _android();
    final enabled = await _platform.isLocationServiceEnabled();
    final permission = await _platform.checkPermission();
    _diagnostics?.call(
      'access_check=enabled:$enabled,permission:${permission.name}',
    );
    return enabled && _allowed(permission);
  }

  @override
  Stream<Position> positions() {
    _android();
    // Match the drive producer's acquisition settings if the UI engine's
    // Geolocator stream is shared. Group publication is independently filtered.
    _diagnostics?.call('position_stream_requested');
    var callbackCount = 0;
    return _platform.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
      ),
    ).map((position) {
      callbackCount++;
      _diagnostics?.call(
        'position_callback=count:$callbackCount,accuracy:${position.accuracy.isFinite ? position.accuracy.round() : 'invalid'}',
      );
      return position;
    });
  }
}
