import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:convert';
import 'task_handler.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DriveTaskHandler());
}

class ForegroundService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driveit_service',
        channelName: 'DriveIt Service',
        channelDescription: 'DriveIt sürüş kaydı',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    await FlutterForegroundTask.saveData(
      key: 'driveit_start_time',
      value: DateTime.now().millisecondsSinceEpoch,
    );
    await FlutterForegroundTask.saveData(key: 'driveit_background_route', value: '[]');
    await FlutterForegroundTask.saveData(key: 'driveit_is_driving', value: true);
    await FlutterForegroundTask.saveData(key: 'driveit_stop_requested', value: false);
    await FlutterForegroundTask.saveData(key: 'driveit_stop_count', value: 0);
    await FlutterForegroundTask.saveData(key: 'driveit_stopped_seconds', value: 0);
    await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: 'DriveIt - Sürüş devam ediyor',
      notificationText: 'Konum ve rota arka planda kaydediliyor',
      notificationInitialRoute: '/',
      serviceTypes: const [ForegroundServiceTypes.location],
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.saveData(key: 'driveit_is_driving', value: false);
  }

  static Future<bool> isDriveActive() async =>
      await FlutterForegroundTask.getData(key: 'driveit_is_driving') == true;

  static Future<DateTime?> readDriveStartTime() async {
    final value = await FlutterForegroundTask.getData(key: 'driveit_start_time');
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static Future<int> readStopCount() async =>
      (await FlutterForegroundTask.getData(key: 'driveit_stop_count') as int?) ?? 0;

  static Future<int> readStoppedSeconds() async =>
      (await FlutterForegroundTask.getData(key: 'driveit_stopped_seconds') as int?) ?? 0;

  static Future<bool> consumeStopRequest() async {
    final requested = await FlutterForegroundTask.getData(key: 'driveit_stop_requested') == true;
    if (requested) {
      await FlutterForegroundTask.saveData(key: 'driveit_stop_requested', value: false);
    }
    return requested;
  }

  static Future<List<Map<String, dynamic>>> readBackgroundRoute() async {
    final value = await FlutterForegroundTask.getData(key: 'driveit_background_route');
    if (value is! String || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
