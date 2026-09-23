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

class OnboardingPermissionService {
  const OnboardingPermissionService();

  Future<OnboardingPermissionSnapshot> readStatus() async {
    final location = await Geolocator.checkPermission();
    final notification = await permissions.Permission.notification.status;
    return _snapshot(location, notification);
  }

  Future<OnboardingPermissionSnapshot> requestSequentially() async {
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
