import 'dart:async';
import 'local_source_writer_fence.dart';
import 'owned_drive_transfer_route.dart';

import 'package:hive/hive.dart';

import '../models/drive_session.dart';
import '../models/route_point.dart';
import '../models/canonical_telemetry_point.dart';
import '../models/drive_score_record.dart';
import '../features/my_world/services/my_world_runtime.dart';
import '../features/drive_score/services/drive_score_persistence_coordinator.dart';
import 'drive_score_storage_service.dart';
import 'drive_telemetry_storage_service.dart';
import 'gps_session_runtime.dart';
import 'gps_session_transfer.dart';
import 'gps_hive_transfer_sink.dart';
import 'local_source_bundle.dart';
import 'career_contribution_repository.dart';
import 'local_data_preparation_service.dart';
import 'local_lifecycle_journal.dart';
import 'independent_deletion_service.dart';
import '../features/my_world/repositories/world_source_snapshot_repository.dart';

class DriveStorageService {
  static Box<DriveSession> get _box =>
      SourceWriterBoundary.box('history', Hive.box<DriveSession>('drives'));
  static Box<dynamic> get _careerBox =>
      SourceWriterBoundary.box('career', Hive.box<dynamic>('career_totals'));
  static Box<dynamic> get _symbolicBox =>
      SourceWriterBoundary.box('history', Hive.box<dynamic>('symbolic_routes'));
  static Box<dynamic> get _namesBox =>
      SourceWriterBoundary.box('history', Hive.box<dynamic>('drive_names'));

  /// Yeni sürüş kaydet
  static Future<void> saveDrive(
    DriveSession drive, {
    List<CanonicalTelemetryPoint>? telemetry,
    Map<String, dynamic> acquisitionMetadata = const {},
  }) => SourceWriterBoundary.run(
    'history',
    () => _saveDrive(
      drive,
      telemetry: telemetry,
      acquisitionMetadata: acquisitionMetadata,
    ),
  );

  static Future<void> _saveDrive(
    DriveSession drive, {
    List<CanonicalTelemetryPoint>? telemetry,
    Map<String, dynamic> acquisitionMetadata = const {},
  }) async {
    final owned = OwnedDriveTransferRoute.transfer;
    if (owned != null) {
      final sessionId = acquisitionMetadata['sessionId'];
      if (sessionId is! String || sessionId != drive.id) {
        throw StateError(
          'Controlled GPS save requires durable session identity',
        );
      }
      await owned(sessionId, driveTransferManifest(drive));
      return; // Never touch shared Hive/Career/World from the controlled path.
    }
    if (LocalLifecycleJournal.historyDeleted(drive.id)) {
      throw StateError('Silinmiş sürüş tekrar kaydedilemez.');
    }
    if (Hive.isBoxOpen(CareerContributionRepository.boxName)) {
      await LocalDataPreparationService.prepareLegacyCareer();
    }
    final sessionId = acquisitionMetadata['sessionId'];
    if (sessionId is String) {
      final store = await openGpsJournal();
      try {
        final manifest = await GpsSessionTransfer(
          store,
          GpsHiveTransferSink(),
        ).save(sessionId, driveTransferManifest(drive));
        drive = driveFromTransferManifest(manifest);
      } finally {
        await store.close();
      }
    }
    try {
      if (sessionId == null && telemetry != null && telemetry.isNotEmpty) {
        await DriveTelemetryStorageService.save(
          driveSessionId: drive.id,
          points: telemetry,
          acquisitionMetadata: acquisitionMetadata,
        );
      }
      await _ensureCareerTotals();
      final counted = List<String>.from(
        (_careerBox.get('atomicTotals') as Map?)?['countedIds'] ??
            _careerBox.get('countedIds', defaultValue: <String>[]),
      );
      if (!counted.contains(drive.id)) {
        final distance = getCareerDistance() + drive.distance;
        final duration = getCareerDurationSeconds() + drive.durationSeconds;
        counted.add(drive.id);
        await _careerBox.put('atomicTotals', {
          'totalDistance': distance,
          'totalDuration': duration,
          'countedIds': counted,
        });
      }
      if (sessionId == null) await _box.put(drive.id, drive);
    } catch (_) {
      // Independent boxes may have partially committed. Never delete a durable
      // telemetry prefix on failure; the SQLite transfer intent can retry it.
      rethrow;
    }
    try {
      await const DriveScorePersistenceCoordinator()
          .calculateAndPersistForDrive(drive.id);
    } catch (_) {
      // Score v1 is a secondary, recoverable analysis. The persisted drive and
      // canonical telemetry must survive an analysis or score-box failure.
    }
    // Prepare only this explicitly saved drive, not the historic database.
    // Failure propagates as retryable save preparation; durable source data
    // and the existing transfer receipt are never removed on this path.
    final source = LocalSourceBundle(
      drive: drive,
      telemetry: DriveTelemetryStorageService.get(drive.id),
      score: DriveScoreStorageService.get(driveId: drive.id),
    );
    if (Hive.isBoxOpen(WorldSourceSnapshotRepository.boxName)) {
      await WorldSourceSnapshotRepository(
        Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
      ).prepare(source);
    }
    if (Hive.isBoxOpen(CareerContributionRepository.boxName)) {
      await CareerContributionRepository(
        Hive.box<dynamic>(CareerContributionRepository.boxName),
      ).add(source);
    }
    try {
      await MyWorldRuntime.enqueueSavedDrive(drive);
      // World validation is best-effort and secondary to the successful drive
      // save. The durable job remains available for startup recovery.
      unawaited(MyWorldRuntime.drainPendingJobs());
    } catch (_) {
      // World validation is secondary. A local queue failure must never turn a
      // successfully persisted drive into a failed save.
    }
  }

  static Future<void> _ensureCareerTotals() async {
    if (_careerBox.get('initialized') == true) return;
    final drives = _box.values.toList();
    await _careerBox.put(
      'totalDistance',
      drives.fold<double>(0, (sum, d) => sum + d.distance),
    );
    await _careerBox.put(
      'totalDuration',
      drives.fold<int>(0, (sum, d) => sum + d.durationSeconds),
    );
    await _careerBox.put('countedIds', drives.map((d) => d.id).toList());
    await _careerBox.put('initialized', true);
  }

  static double getCareerDistance() {
    if (!Hive.isBoxOpen('career_totals')) {
      if (!Hive.isBoxOpen('drives')) return 0;
      return _box.values.fold<double>(0, (sum, d) => sum + d.distance);
    }
    if (_careerBox.get('initialized') != true) {
      final drives = _box.values.toList();
      return drives.fold<double>(0, (sum, d) => sum + d.distance);
    }
    return ((_careerBox.get('atomicTotals') as Map?)?['totalDistance'] ??
            _careerBox.get('totalDistance', defaultValue: 0.0) as num)
        .toDouble();
  }

  static int getCareerDurationSeconds() {
    if (!Hive.isBoxOpen('career_totals')) {
      if (!Hive.isBoxOpen('drives')) return 0;
      return _box.values.fold<int>(0, (sum, d) => sum + d.durationSeconds);
    }
    if (_careerBox.get('initialized') != true) {
      final drives = _box.values.toList();
      return drives.fold<int>(0, (sum, d) => sum + d.durationSeconds);
    }
    return ((_careerBox.get('atomicTotals') as Map?)?['totalDuration'] ??
            _careerBox.get('totalDuration', defaultValue: 0) as num)
        .toInt();
  }

  static List<RoutePoint> getSymbolicRoute(List<DriveSession> drives) {
    if (!Hive.isBoxOpen('symbolic_routes')) {
      return drives.isEmpty ? const <RoutePoint>[] : drives.last.route;
    }
    final stored = _symbolicBox.get('driveit_symbolic_route');
    if (stored is List && stored.isNotEmpty) {
      return stored
          .whereType<Map>()
          .map(
            (p) => RoutePoint(
              latitude: (p['lat'] as num).toDouble(),
              longitude: (p['lng'] as num).toDouble(),
            ),
          )
          .toList();
    }
    if (drives.isEmpty) return const <RoutePoint>[];
    final first = drives.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
    final encoded = first.route
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();
    _symbolicBox.put('driveit_symbolic_route', encoded);
    return first.route;
  }

  /// Tüm sürüşler
  static List<DriveSession> getAllDrives() {
    if (!Hive.isBoxOpen('drives')) return [];
    return _box.values.toList().reversed.toList();
  }

  /// Sürüş sil
  static Future<void> deleteDrive(String id) async {
    await IndependentDeletionService.deleteHistory(
      id,
      removeHistory: () => _deleteDriveStorageOnly(id),
    );
  }

  static Future<void> _deleteDriveStorageOnly(String id) async {
    await _box.delete(id);
    await _box.flush();
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    final cleanupTasks = <Future<void>>[
      DriveTelemetryStorageService.delete(id),
      DriveScoreStorageService.deleteForDrive(id),
    ];
    if (Hive.isBoxOpen('drive_names')) {
      cleanupTasks.add(_namesBox.delete(id));
    }
    try {
      // These boxes are independent; wait for all cleanups together instead
      // of serialising their disk writes behind three awaits.
      await Future.wait(cleanupTasks);
      await Future.wait([
        if (Hive.isBoxOpen(DriveTelemetryHive.boxName))
          Hive.box<DriveTelemetryRecord>(DriveTelemetryHive.boxName).flush(),
        if (Hive.isBoxOpen(DriveScoreHive.boxName))
          Hive.box<DriveScoreRecord>(DriveScoreHive.boxName).flush(),
        if (Hive.isBoxOpen('drive_names')) _namesBox.flush(),
      ]);
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }

  /// Tek sürüş getir
  static DriveSession? getDrive(String id) {
    if (!Hive.isBoxOpen('drives')) return null;
    return _box.get(id);
  }

  /// Returns the user-defined title for a drive, or an empty string when the
  /// drive has not been named yet.
  static String getDriveName(String id) {
    if (!Hive.isBoxOpen('drive_names')) return '';
    final value = _namesBox.get(id);
    final name = value is String ? value.trim() : '';
    return name;
  }

  /// Persists only the display name. DriveSession itself is intentionally not
  /// changed so old Hive data remains fully compatible.
  static Future<void> saveDriveName(String id, String name) async {
    if (!Hive.isBoxOpen('drive_names')) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _namesBox.delete(id);
    } else {
      await _namesBox.put(id, trimmed);
    }
  }
}
