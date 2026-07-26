import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class DriveTaskHandler extends TaskHandler {
  int seconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    seconds++;

    FlutterForegroundTask.updateService(
      notificationTitle: "🚗 DriveIt",
      notificationText: "Sürüş süresi: ${seconds}s",
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onReceiveData(Object data) {}
}