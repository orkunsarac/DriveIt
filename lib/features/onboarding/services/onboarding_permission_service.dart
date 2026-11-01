import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

class OnboardingPermissionSnapshot {
  const OnboardingPermissionSnapshot({
    required this.locationGranted,
    required this.locationPermanentlyDenied,
    required this.notificationGranted,
  });

  final bool locationGranted;
  final bool locationPermanentlyDenied;
  final bool notificationGranted;
}

abstract interface class OnboardingPermissionGateway {
  Future<OnboardingPermissionSnapshot> readStatus();
  Future<OnboardingPermissionSnapshot> requestSequentially();
  Future<bool> openSettings();
}

class OnboardingPermissionService implements OnboardingPermissionGateway {
  const OnboardingPermissionService();

  @override
  Future<OnboardingPermissionSnapshot> readStatus() async {
    final location = await Geolocator.checkPermission();
    final notification = await permissions.Permission.notification.status;
    return _snapshot(location, notification);
  }

  @override
  Future<OnboardingPermissionSnapshot> requestSequentially() async {
    // The geolocator Android implementation requests coarse and fine together,
    // allowing Android 12+ to present its precise/approximate choice. Background
    // access is deliberately not requested in this foreground permission step.
    var location = await Geolocator.checkPermission();
    if (location == LocationPermission.denied) {
      location = await Geolocator.requestPermission();
    }

    var notification = await permissions.Permission.notification.status;
    if (!notification.isGranted) {
      notification = await permissions.Permission.notification.request();
    }
    return _snapshot(location, notification);
  }

  @override
  Future<bool> openSettings() => permissions.openAppSettings();

  OnboardingPermissionSnapshot _snapshot(
    LocationPermission location,
    permissions.PermissionStatus notification,
  ) {
    return OnboardingPermissionSnapshot(
      locationGranted:
          location == LocationPermission.whileInUse ||
          location == LocationPermission.always,
      locationPermanentlyDenied: location == LocationPermission.deniedForever,
      notificationGranted: notification.isGranted,
    );
  }
}
