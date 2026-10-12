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

/// Visible-app access only. Never configures a Geolocator foreground
/// notification and never starts/stops DriveIt's recording foreground service.
class AndroidGroupGpsSource implements GroupGpsSource {
  AndroidGroupGpsSource({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance,
      _injected = platform != null;
  final GeolocatorPlatform _platform;
  final bool _injected;
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
    if (!await _platform.isLocationServiceEnabled()) {
      throw const GroupGpsException('location_disabled');
    }
    var permission = await _platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }
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
    return await _platform.isLocationServiceEnabled() &&
        _allowed(await _platform.checkPermission());
  }

  @override
  Stream<Position> positions() {
    _android();
    // Match the drive producer's acquisition settings if the UI engine's
    // Geolocator stream is shared. Group publication is independently filtered.
    return _platform.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
