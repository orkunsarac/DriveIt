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
    bool recordingRequested = true,
  }) : _openJournal = openJournal ?? openGpsJournal,
       // The public option intentionally configures an internal demand.
       // ignore: prefer_initializing_formals
       _recordingRequested = recordingRequested;
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
  bool _recordingRequested;
  String? _groupToken;
  DateTime? _groupRenewed;
  bool _destroyed = false;
  Future<void> _commands = Future.value();
  Future<void> get settled => _commands;
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
    if (!_recordingRequested) return; // No journal or GPS on group-only boot.
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
    _motionAnchor = null;
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
    await _ensureGps();
    _starting = false;
  }

  Future<void> _ensureGps() async {
    if (_gps != null || _destroyed) return;
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
        if (state == GpsFlowState.permissionBlocked && _groupToken != null) {
          FlutterForegroundTask.sendDataToMain({'groupGpsError': _groupToken});
          _groupToken = null;
        }
        if (state == GpsFlowState.waiting &&
            _gps?.lastReceivedAt != null &&
            _groupToken != null) {
          FlutterForegroundTask.sendDataToMain({'groupGpsError': _groupToken});
          _groupToken = null;
        }
        if (_writer == null || !_recordingRequested || _draining) return;
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
        final token = _groupToken;
        if (token != null) {
          FlutterForegroundTask.sendDataToMain({
            'groupGpsSample': token,
            'position': position.toJson(),
          });
        }
        if (!_recordingRequested || _writer == null || _draining) return;
        final writer = _writer!;
        if (_failure?.code == GpsErrorCode.gpsUnavailable) {
          _recordingError(false);
        }
        _updateStopState(position);
        final before = writer.sequence;
        unawaited(
          writer
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
                    writer.sequence > before &&
                    !writer.hasPendingFailure) {
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
    if (_writer != null) {
      _recordingError(true, failure: GpsFailure(GpsErrorCode.gpsUnavailable));
    }
    await _gps!.poll();
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
      // The writer is drained independently from the shared physical source.
      if (_groupToken == null) {
        await _gps?.close();
        _gps = null;
      }
      await _eventTail;
      await _writer!.drain();
      await _store!.stop(id, expectedSequence: _writer!.sequence);
      await _writer!.close();
      _writer = null;
      _recordingRequested = false;
      _activeSessionId = null;
      await _store!.close();
      _store = null;
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
    if (_groupToken != null &&
        timestamp.difference(_groupRenewed!) > const Duration(seconds: 10)) {
      final expired = _groupToken;
      _groupToken = null;
      FlutterForegroundTask.sendDataToMain({'groupGpsError': expired});
    }
    if (!_recordingRequested && _groupToken == null) {
      // A recreated engine never restores a group demand from preferences.
      if (!_starting &&
          timestamp.difference(_groupRenewed ?? timestamp) >
              const Duration(seconds: 10)) {
        _commands = _commands.then((_) async {
          if (_destroyed || _recordingRequested || _groupToken != null) return;
          await _gps?.close();
          _gps = null;
          await FlutterForegroundTask.stopService();
        });
      }
      _groupRenewed ??= timestamp;
      return;
    }
    if (_recordingRequested && _writer == null && _starter != null) {
      unawaited(onStart(timestamp, _starter!));
    }
    if (_gps != null && !_draining) {
      unawaited(_gps!.poll().catchError((Object _) {}));
    }
    if (_writeFailed && _recordingRequested) {
      _recordingError(true);
      return;
    }
    seconds++;
    FlutterForegroundTask.updateService(
      notificationTitle: _groupToken == null
          ? 'DriveIt - Sürüş devam ediyor'
          : 'DriveIt • Grup konumu paylaşılıyor',
      notificationText: _groupToken == null
          ? 'Arka planda kayıt: ${seconds}s'
          : (_recordingRequested
                ? 'Sürüş kaydı ve grup paylaşımı etkin. Kontroller için dokun.'
                : 'Grup paylaşımı etkin. Durdurmak için dokun.'),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (_destroyed) return;
    _destroyed = true;
    final token = _groupToken;
    _groupToken = null;
    if (token != null) {
      FlutterForegroundTask.sendDataToMain({'groupGpsError': token});
    }
    await _commands;
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
    FlutterForegroundTask.sendDataToMain({
      if (_groupToken != null) 'openGroup': true else 'openDrive': true,
    });
    FlutterForegroundTask.launchApp();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map || _destroyed) return;
    _commands = _commands
        .then((_) async {
          if (_destroyed) return;
          if (data['queryRecording'] is String) {
            FlutterForegroundTask.sendDataToMain({
              'recordingState': data['queryRecording'],
              'requested': _recordingRequested,
              'sessionId': _activeSessionId,
            });
            return;
          }
          if (data['drainSession'] is String) {
            await _drain(data['drainSession'] as String);
            return;
          }
          if (data['attachRecording'] == true) {
            _recordingRequested = true;
            await onStart(DateTime.now(), _starter ?? TaskStarter.developer);
            FlutterForegroundTask.sendDataToMain({
              'recordingAttached': _activeSessionId,
            });
          }
          final token = data['groupGpsToken'];
          if (token is! String || token.isEmpty) return;
          switch (data['groupGpsCommand']) {
            case 'attach':
              if (_groupToken != null && _groupToken != token) return;
              _groupToken = token;
              _groupRenewed = DateTime.now();
              await _ensureGps();
              if (_groupToken == token) {
                FlutterForegroundTask.sendDataToMain({
                  'groupGpsAttached': token,
                });
              }
            case 'renew':
              if (_groupToken == token) {
                _groupRenewed = DateTime.now();
                FlutterForegroundTask.sendDataToMain({'groupGpsAlive': token});
              }
            case 'detach':
              if (_groupToken == token) {
                _groupToken = null;
                if (!_recordingRequested) {
                  await _gps?.close();
                  _gps = null;
                }
              }
              FlutterForegroundTask.sendDataToMain({
                'groupGpsDetached': token,
                'recording': _recordingRequested,
              });
          }
        })
        .catchError((Object _) {
          if (data['groupGpsCommand'] != null && _groupToken != null) {
            FlutterForegroundTask.sendDataToMain({
              'groupGpsError': _groupToken,
            });
            _groupToken = null;
          } else if (data['attachRecording'] == true) {
            _recordingError(true, failure: GpsFailure(GpsErrorCode.recovery));
          }
        });
  }
}
