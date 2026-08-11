import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

class DriveTaskHandler extends TaskHandler {
  int seconds = 0;
  StreamSubscription<Position>? _positionSubscription;
  final List<Map<String, dynamic>> _route = [];
  Position? _motionAnchor;
  Position? _lastRecordedPosition;
  DateTime? _stationarySince;
  bool _isStopped = true;
  bool _currentStopRegistered = false;
  int _stopCount = 0;
  int _stoppedSeconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _isStopped = true;
    _currentStopRegistered = false;
    _stationarySince = timestamp;
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            intervalDuration: Duration(milliseconds: 500),
          ),
        ).listen((position) {
          _updateStopState(position);
          if (_shouldRecord(position)) {
            _route.add({
              'lat': position.latitude,
              'lng': position.longitude,
              'accuracy': position.accuracy,
              'speed': position.speed,
              'heading': position.heading,
              'altitude': position.altitude,
              'time': position.timestamp.millisecondsSinceEpoch,
            });
            _lastRecordedPosition = position;
            FlutterForegroundTask.saveData(
              key: 'driveit_background_route',
              value: jsonEncode(_route),
            );
          }
        });
  }

  bool _shouldRecord(Position position) {
    if (!position.accuracy.isFinite || position.accuracy > 30) return false;
    final last = _lastRecordedPosition;
    if (last == null) return true;
    if (_isStopped) return false;
    final distance = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );
    return distance >= 5 && distance <= 120;
  }

  void _updateStopState(Position position) {
    final now = DateTime.now();
    _motionAnchor ??= position;
    final anchorDistance = Geolocator.distanceBetween(
      _motionAnchor!.latitude,
      _motionAnchor!.longitude,
      position.latitude,
      position.longitude,
    );
    final moving = anchorDistance > 10.0;
    final likelyStopped = !moving;
    if (moving) _motionAnchor = position;
    if (_isStopped) {
      if (moving) {
        if (_currentStopRegistered && _stationarySince != null) {
          _stoppedSeconds += now.difference(_stationarySince!).inSeconds;
        }
        _isStopped = false;
        _currentStopRegistered = false;
        _stationarySince = null;
      } else {
        _stationarySince ??= now;
        if (!_currentStopRegistered &&
            now.difference(_stationarySince!).inSeconds >= 3) {
          _currentStopRegistered = true;
          _stopCount++;
        }
      }
    } else if (likelyStopped) {
      _stationarySince ??= now;
      if (now.difference(_stationarySince!).inSeconds >= 3) {
        _isStopped = true;
        _currentStopRegistered = true;
        _stopCount++;
      }
    } else {
      _stationarySince = null;
    }
    final activeStoppedSeconds =
        _isStopped && _currentStopRegistered && _stationarySince != null
        ? now.difference(_stationarySince!).inSeconds
        : 0;
    FlutterForegroundTask.saveData(
      key: 'driveit_stop_count',
      value: _stopCount,
    );
    FlutterForegroundTask.saveData(
      key: 'driveit_stopped_seconds',
      value: _stoppedSeconds + activeStoppedSeconds,
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    seconds++;
    FlutterForegroundTask.updateService(
      notificationTitle: 'DriveIt - Sürüş devam ediyor',
      notificationText: 'Arka planda kayıt: ${seconds}s',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSubscription?.cancel();
    await FlutterForegroundTask.saveData(
      key: 'driveit_background_route',
      value: jsonEncode(_route),
    );
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_drive') {
      // Bildirim aksiyonu yalnızca sürüş ekranını açar. Kayıt, kullanıcı
      // sürüş ekranındaki normal bitirme butonuna bastığında sonlandırılır.
      FlutterForegroundTask.sendDataToMain({'openDrive': true});
      FlutterForegroundTask.launchApp();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain({'openDrive': true});
    FlutterForegroundTask.launchApp();
  }

  @override
  void onReceiveData(Object data) {}
}
