import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:convert';
import 'task_handler.dart';
import 'gps_session_store.dart';
import 'gps_session_runtime.dart';
import 'drive_recovery_status.dart';
import 'gps_failure.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DriveTaskHandler());
}

class ForegroundService {
  static Future<GpsSessionStore>? _journal;
  static Future<GpsSessionStore> get journal =>
      _journal ??= openGpsJournal().catchError((Object error) {
        _journal = null;
        throw error;
      });
  static Future<GpsSession?> activeSession() async => (await journal).active();
  static Future<void> init() async {
    FlutterForegroundTask.initCommunicationPort();
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

  static Future<GpsSession> start() async {
    final recovery = await inspectRecovery();
    if (!recovery.canStartNewDrive) {
      throw recovery.failure ?? GpsFailure(GpsErrorCode.recovery);
    }
    final session = await (await journal).create();
    await FlutterForegroundTask.saveData(key: 'driveit_stop_count', value: 0);
    await FlutterForegroundTask.saveData(
      key: 'driveit_stopped_seconds',
      value: 0,
    );
    await _startNative();
    return session;
  }

  static Future<void> _startNative() async {
    final result = await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: 'DriveIt - Sürüş devam ediyor',
      notificationText: 'Konum ve rota arka planda kaydediliyor',
      notificationInitialRoute: '/',
      serviceTypes: const [ForegroundServiceTypes.location],
      callback: startCallback,
    );
    if (result is ServiceRequestFailure) {
      final session = await activeSession();
      if (session != null) {
        await (await journal).setError(
          session.id,
          GpsFailure(GpsErrorCode.serviceStart).id,
        );
      }
      throw GpsFailure(GpsErrorCode.serviceStart);
    }
  }

  static Future<void> resumeRecording() async {
    final session = await activeSession();
    if (session?.state == 'recording' &&
        !await FlutterForegroundTask.isRunningService) {
      await _startNative();
    }
  }

  static Future<void>? _stopInFlight;

  /// Called only after the platform has confirmed the producer is absent.
  /// This path has no native GPS or service-start side effects.
  static Future<void> finishCommittedJournal(
    GpsSessionStore store,
    String sessionId,
  ) async {
    await store.stop(
      sessionId,
      expectedSequence: (await store.last(sessionId))?.sequence ?? 0,
    );
  }

  static Future<void> stop() => _stopInFlight ??= _stopRecording().whenComplete(
    () => _stopInFlight = null,
  );

  static Future<void> _stopRecording() async {
    final requestedAt = DateTime.now();
    final session = await activeSession();
    if (session != null && session.state == 'recording') {
      await (await journal).requestStop(session.id, at: requestedAt);
      // Explicit durable-drain acknowledgement, not a fixed 250ms sleep.
      if (!await FlutterForegroundTask.isRunningService) {
        // No producer exists: preserve and finalize only the committed journal.
        // Never start live GPS merely to save a recovered drive.
        final store = await journal;
        await finishCommittedJournal(store, session.id);
      }
      FlutterForegroundTask.sendDataToTask({'drainSession': session.id});
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while ((await (await journal).session(session.id))?.state ==
          'recording') {
        if (DateTime.now().isAfter(deadline)) {
          throw GpsFailure(GpsErrorCode.sqliteWrite);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        FlutterForegroundTask.sendDataToTask({'drainSession': session.id});
      }
    }
    if (session != null) {
      final store = await journal;
      if (session.state == 'stopped') {
        await store.stop(
          session.id,
          expectedSequence: (await store.last(session.id))?.sequence ?? 0,
        );
      }
      final finalSession = await store.session(session.id);
      final events = await store.events(session.id);
      final drained = events.where((e) => e['kind'] == 'drained').toList();
      if (finalSession?.state != 'stopped' ||
          drained.length != 1 ||
          drained.single['sequence'] !=
              ((await store.last(session.id))?.sequence ?? 0)) {
        throw GpsFailure(GpsErrorCode.serviceStop);
      }
    }
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestFailure) {
        throw GpsFailure(GpsErrorCode.serviceStop);
      }
    }
    // Legacy flags are never reset by the new SQLite recording path.
  }

  static Future<DriveRecoveryStatus> inspectRecovery() => inspectDriveRecovery(
    producerRunning: () => FlutterForegroundTask.isRunningService,
    loadActive: () async {
      final store = await journal;
      var session = await store.active();
      if (session == null) {
        final unfinished = await store.recoverableSessions();
        if (unfinished.isNotEmpty) throw GpsFailure(GpsErrorCode.recovery);
      }
      if (session != null) await store.last(session.id);
      return session;
    },
    legacyActive: () async =>
        await FlutterForegroundTask.getData(key: 'driveit_is_driving') ==
            true ||
        await FlutterForegroundTask.getData(key: 'driveit_stop_requested') ==
            true ||
        await FlutterForegroundTask.isRunningService,
    loadLegacy: readBackgroundRoute,
  );

  // A boolean cannot represent "unknown" safely. This API now returns all
  // four decisions explicitly; an exception can never become active=true.
  static Future<DriveRecoveryStatus> isDriveActive() => inspectRecovery();

  static Future<DateTime?> readDriveStartTime() async {
    final session = await activeSession();
    if (session != null) return session.startedAt;
    final value = await FlutterForegroundTask.getData(
      key: 'driveit_start_time',
    );
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static Future<List<Map<String, dynamic>>> readPoints(
    String sessionId,
    int afterSequence,
  ) async => (await (await journal).read(
    sessionId,
    after: afterSequence,
    includeCheckpoints: false,
  )).map((p) => p.toMap()).toList();

  static Future<void> acknowledgeSaved(String sessionId, String driveId) async {
    final receipt = await (await journal).transferFor(sessionId);
    if (receipt?['drive_id'] != driveId || receipt?['verified_us'] == null) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
  }

  static Future<int> readStopCount() async =>
      (await FlutterForegroundTask.getData(key: 'driveit_stop_count')
          as int?) ??
      0;

  static Future<int> readStoppedSeconds() async =>
      (await FlutterForegroundTask.getData(key: 'driveit_stopped_seconds')
          as int?) ??
      0;

  static Future<bool> consumeStopRequest() async {
    final requested =
        await FlutterForegroundTask.getData(key: 'driveit_stop_requested') ==
        true;
    // Compatibility read only; startup no longer consumes/clears this flag.
    return requested;
  }

  static Future<List<Map<String, dynamic>>> readBackgroundRoute() async {
    final value = await FlutterForegroundTask.getData(
      key: 'driveit_background_route',
    );
    if (value is! String || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
