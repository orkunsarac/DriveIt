import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_bootstrap.dart';
import '../../../features/my_world/config/my_world_rules.dart';
import '../../../models/drive_session.dart';
import '../../../services/drive_storage_service.dart';
import '../models/world_publish.dart';
import '../../../models/canonical_telemetry_point.dart';
import '../../../services/drive_telemetry_storage_service.dart';
import 'legacy_whole_drive_safety.dart';

const worldPublishColumns =
    'id,user_id,local_drive_id,started_at,ended_at,distance_meters,'
    'world_rules_version,status,error_code,created_at,updated_at,processed_at,'
    'source_path,source_schema_version,telemetry_version,'
    'drive_score_algorithm_version,raw_route_point_count,'
    'telemetry_point_count,source_ready_at';

enum WorldPublishCreateStatus {
  success,
  notSignedIn,
  supabaseUnavailable,
  invalidDrive,
  notEligible,
  alreadyPublished,
  networkOrServerFailure,
}

class WorldPublishCreateResult {
  const WorldPublishCreateResult(this.status, {this.publish});

  final WorldPublishCreateStatus status;
  final WorldPublish? publish;
}

enum WorldPublishLookupFailure {
  notSignedIn,
  supabaseUnavailable,
  invalidDrive,
  networkOrServerFailure,
}

class WorldPublishLookupException implements Exception {
  const WorldPublishLookupException(this.failure);

  final WorldPublishLookupFailure failure;
}

/// A narrow boundary so publish behavior can be tested without a live project.
abstract interface class WorldPublishGateway {
  bool get isAvailable;
  String? get currentUserId;
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload);
  Future<Map<String, dynamic>?> findForLocalDrive({
    required String userId,
    required String localDriveId,
  });
}

class SupabaseWorldPublishGateway implements WorldPublishGateway {
  SupabaseClient? get _client =>
      SupabaseBootstrap.isInitialized ? Supabase.instance.client : null;

  @override
  bool get isAvailable => _client != null;

  @override
  String? get currentUserId => _client?.auth.currentSession?.user.id;

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload) async =>
      await _client!
          .from('world_publishes')
          .insert(payload)
          .select(worldPublishColumns)
          .single();

  @override
  Future<Map<String, dynamic>?> findForLocalDrive({
    required String userId,
    required String localDriveId,
  }) async => await _client!
      .from('world_publishes')
      .select(worldPublishColumns)
      .eq('user_id', userId)
      .eq('local_drive_id', localDriveId)
      .maybeSingle();
}

class WorldPublishService {
  WorldPublishService({
    WorldPublishGateway? gateway,
    DriveSession? Function(String)? savedDriveLookup,
    DriveTelemetryRecord? Function(String)? telemetryLoader,
  }) : _gateway = gateway ?? SupabaseWorldPublishGateway(),
       _savedDriveLookup = savedDriveLookup ?? DriveStorageService.getDrive,
       _telemetryLoader = telemetryLoader ?? DriveTelemetryStorageService.get;

  final WorldPublishGateway _gateway;
  final DriveSession? Function(String) _savedDriveLookup;
  final DriveTelemetryRecord? Function(String) _telemetryLoader;

  bool get isAvailable => _gateway.isAvailable;
  bool get hasSession => isAvailable && _gateway.currentUserId != null;

  Future<WorldPublishCreateResult> createPendingPublish(
    DriveSession drive,
  ) async {
    if (!_gateway.isAvailable) {
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.supabaseUnavailable,
      );
    }
    if (_gateway.currentUserId == null) {
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.notSignedIn,
      );
    }

    final saved = drive.id.trim().isEmpty ? null : _savedDriveLookup(drive.id);
    if (saved == null ||
        saved.id != drive.id ||
        saved.durationSeconds <= 0 ||
        !saved.distance.isFinite ||
        saved.distance < 0) {
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.invalidDrive,
      );
    }
    if (saved.distance < MyWorldRules.minimumValidDistanceMeters) {
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.notEligible,
      );
    }
    if (!LegacyWholeDriveSafety.canBuild(saved, _telemetryLoader(saved.id))) {
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.notEligible,
      );
    }

    // DriveSession.date is assigned when the completed drive is saved.
    final endedAt = saved.date;
    final startedAt = endedAt.subtract(
      Duration(seconds: saved.durationSeconds),
    );
    final payload = <String, dynamic>{
      'local_drive_id': saved.id,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'distance_meters': saved.distance,
      'world_rules_version': MyWorldRules.worldRulesVersion,
    };

    try {
      final row = await _gateway.insert(payload);
      return WorldPublishCreateResult(
        WorldPublishCreateStatus.success,
        publish: WorldPublish.fromRow(row),
      );
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return const WorldPublishCreateResult(
          WorldPublishCreateStatus.alreadyPublished,
        );
      }
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.networkOrServerFailure,
      );
    } catch (_) {
      return const WorldPublishCreateResult(
        WorldPublishCreateStatus.networkOrServerFailure,
      );
    }
  }

  Future<WorldPublish?> getPublishForLocalDrive(String localDriveId) async {
    if (!_gateway.isAvailable) {
      throw const WorldPublishLookupException(
        WorldPublishLookupFailure.supabaseUnavailable,
      );
    }
    final userId = _gateway.currentUserId;
    if (userId == null) {
      throw const WorldPublishLookupException(
        WorldPublishLookupFailure.notSignedIn,
      );
    }
    if (localDriveId.trim().isEmpty) {
      throw const WorldPublishLookupException(
        WorldPublishLookupFailure.invalidDrive,
      );
    }
    try {
      final row = await _gateway.findForLocalDrive(
        userId: userId,
        localDriveId: localDriveId,
      );
      return row == null ? null : WorldPublish.fromRow(row);
    } catch (_) {
      throw const WorldPublishLookupException(
        WorldPublishLookupFailure.networkOrServerFailure,
      );
    }
  }
}
