import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'canonical_telemetry_pipeline.dart';
import 'gps_recording_writer.dart';
import 'gps_session_store.dart';
import 'gps_session_runtime.dart';
import 'gps_failure.dart';
import 'gps_stream_supervisor.dart';

class DriveTaskHandler extends TaskHandler {
  DriveTaskHandler({
    Future<GpsSessionStore> Function()? openJournal,
    this.verifySessionOwner,
  }) : _openJournal = openJournal ?? openGpsJournal;
  final Future<GpsSessionStore> Function() _openJournal;
  final Future<void> Function(String sessionId)? verifySessionOwner;
  int seconds = 0;
  GpsStreamSupervisor<Position>? _gps;
  GpsSessionStore? _store;
  GpsRecordingWriter? _writer;
  bool _writeFailed = false;
  GpsFailure? _failure;
  String? _activeSessionId;
  bool _draining = false;
  bool _starting = false;
  DateTime? _lastRawTimestamp;
  Future<void> _eventTail = Future.value();
  TaskStarter? _starter;
  Position? _motionAnchor;
  DateTime? _stationarySince;
  bool _isStopped = true;
  bool _currentStopRegistered = false;
  int _stopCount = 0;
  int _stoppedSeconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _starter = starter;
    if (_starting || _writer != null) return;
    _starting = true;
    try {
      await _store?.close();
      _store = await _openJournal();
      final session = await _store!.active();
      if (session == null || session.state != 'recording') {
        _recordingError(true, failure: GpsFailure(GpsErrorCode.recovery));
        _starting = false;
        return;
      }
      await verifySessionOwner?.call(session.id);
      _activeSessionId = session.id;
      final writer = GpsRecordingWriter(
        _store!,
        session.id,
        onError: (failed) => _recordingError(
          failed,
          failure: failed
              ? GpsFailure(
                  _writer?.queueOverflowed == true
                      ? GpsErrorCode.queueCapacity
                      : GpsErrorCode.sqliteWrite,
                )
              : null,
        ),
      );
      await writer.restore();
      _lastRawTimestamp = (await _store!.last(session.id))?.point.timestamp;
      _stopCount =
          (await FlutterForegroundTask.getData(key: 'driveit_stop_count')
              as int?) ??
          0;
      _stoppedSeconds =
          (await FlutterForegroundTask.getData(key: 'driveit_stopped_seconds')
              as int?) ??
          0;
      _writer = writer;
      _recordingError(
        writer.queueOverflowed,
        failure: writer.queueOverflowed
            ? GpsFailure(GpsErrorCode.queueCapacity)
            : null,
      );
    } catch (error) {
      _starting = false;
      _recordingError(
        true,
        failure: GpsFailure.from(error, GpsErrorCode.recovery),
      );
      return;
    }
    _isStopped = true;
    _currentStopRegistered = false;
    _stationarySince = timestamp;
    List<Map<String, Object?>> events;
    try {
      events = await _store!.events(_activeSessionId!);
    } catch (error) {
      _starting = false;
      _recordingError(
        true,
        failure: GpsFailure.from(error, GpsErrorCode.sqliteRead),
      );
      await _writer?.close();
      _writer = null;
      return;
    }
    if (events.any((event) => event['kind'] == 'stop_requested')) {
      _starting = false;
      await _drain(_activeSessionId!);
      return;
    }
    _gps = GpsStreamSupervisor<Position>(
      isFresh: (position) {
        if (_lastRawTimestamp != null &&
            !position.timestamp.isAfter(_lastRawTimestamp!)) {
          return false;
        }
        _lastRawTimestamp = position.timestamp;
        return true;
      },
      available: () async {
        if (!await Geolocator.isLocationServiceEnabled()) return false;
        final permission = await Geolocator.checkPermission();
        return permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
      },
      open: () => Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: Duration(milliseconds: 500),
        ),
      ),
      onState: (state) {
        if (state == GpsFlowState.stopping) return;
        final at = DateTime.now();
        final kind = switch (state) {
          GpsFlowState.recording => 'gps_resumed',
          GpsFlowState.permissionBlocked => 'permission_blocked',
          _ => 'gps_waiting',
        };
        _eventTail = _eventTail
            .then((_) => _store!.recordFlowEvent(_activeSessionId!, kind, at))
            .catchError((Object error) {
              _recordingError(
                true,
                failure: GpsFailure.from(error, GpsErrorCode.sqliteWrite),
              );
            });
        if (_writer?.hasPendingFailure == true) return;
        if (state == GpsFlowState.recording) {
          if (_failure?.code == GpsErrorCode.gpsUnavailable) {
            _recordingError(false);
          }
        } else {
          _recordingError(
            true,
            failure: GpsFailure(GpsErrorCode.gpsUnavailable),
          );
        }
      },
      onSample: (position) {
        if (_failure?.code == GpsErrorCode.gpsUnavailable) {
          _recordingError(false);
        }
        _updateStopState(position);
        final before = _writer!.sequence;
        unawaited(
          _writer!
              .add(
                RawTelemetryInput(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  timestamp: position.timestamp,
                  speedMps: position.speed,
                  speedAccuracyMps: position.speedAccuracy,
                  headingDegrees: position.heading,
                  altitudeMeters: position.altitude,
                  accuracyMeters: position.accuracy,
                ),
              )
              .then((_) {
                if (_writeFailed &&
                    _writer!.sequence > before &&
                    !_writer!.hasPendingFailure) {
                  _recordingError(false);
                }
              })
              .catchError((Object error) {
                _recordingError(
                  true,
                  failure: _writer?.queueOverflowed == true
                      ? GpsFailure(GpsErrorCode.queueCapacity)
                      : GpsFailure.from(error, GpsErrorCode.sqliteWrite),
                );
              }),
        );
      },
    );
    _recordingError(true, failure: GpsFailure(GpsErrorCode.gpsUnavailable));
    await _gps!.poll();
    _starting = false;
  }

  void _recordingError(bool failed, {GpsFailure? failure}) {
    final next = _writer?.queueOverflowed == true
        ? GpsFailure(GpsErrorCode.queueCapacity)
        : failed
        ? (failure ?? _failure ?? GpsFailure(GpsErrorCode.sqliteWrite))
        : null;
    // Do not queue repeated database/status writes behind a blocked disk.
    if (_failure?.id == next?.id && _writeFailed == failed) return;
    if (_failure?.id != next?.id && next != null) {
      next.report('foreground_task');
    }
    _failure = next;
    failed = next != null;
    _writeFailed = failed;
    FlutterForegroundTask.sendDataToMain({
      'gpsRecordingError': failed,
      'gpsErrorCode': next?.id,
    });
    unawaited(
      FlutterForegroundTask.saveData(
        key: 'driveit_gps_write_error',
        value: failed,
      ).catchError((Object _) => false),
    );
    if (_activeSessionId != null && _store != null) {
      unawaited(
        _store!.setError(_activeSessionId!, next?.id).catchError((Object _) {}),
      );
    }
    FlutterForegroundTask.updateService(
      notificationTitle: failed
          ? next.code == GpsErrorCode.gpsUnavailable
                ? 'DriveIt - GPS bekleniyor'
                : 'DriveIt - Kritik kayıt hatası'
          : 'DriveIt - Sürüş devam ediyor',
      notificationText: failed
          ? '${next.id}: ${next.description}'
          : 'GPS kaydı devam ediyor',
    );
  }

  Future<void> _drain(String id) async {
    if (_draining || _writer?.sessionId != id) return;
    _draining = true;
    try {
      await _store!.requestStop(id);
      await _gps?.close();
      await _eventTail;
      await _writer!.drain();
      await _store!.stop(id, expectedSequence: _writer!.sequence);
    } catch (error) {
      _recordingError(
        true,
        failure: GpsFailure.from(error, GpsErrorCode.sqliteWrite),
      );
    } finally {
      _draining = false;
    }
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
    if (_writer == null && _starter != null) {
      unawaited(onStart(timestamp, _starter!));
    }
    if (_gps != null && !_draining) {
      unawaited(_gps!.poll().catchError((Object _) {}));
    }
    if (_writeFailed) {
      _recordingError(true);
      return;
    }
    seconds++;
    FlutterForegroundTask.updateService(
      notificationTitle: 'DriveIt - Sürüş devam ediyor',
      notificationText: 'Arka planda kayıt: ${seconds}s',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _gps?.close();
    await _eventTail;
    try {
      await _writer?.close();
    } catch (error) {
      _recordingError(
        true,
        failure: GpsFailure.from(error, GpsErrorCode.sqliteWrite),
      );
    }
    await _store?.close();
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
  void onReceiveData(Object data) {
    if (data is Map && data['drainSession'] is String) {
      unawaited(_drain(data['drainSession'] as String));
    }
  }
}
