import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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
    await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: '🚗 DriveIt',
      notificationText: 'Sürüş başlatıldı',
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    
  }
}