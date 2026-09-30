import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_bootstrap.dart';
import '../../../models/drive_session.dart';
import '../models/world_publish.dart';
import 'published_drive_source_builder.dart';

const worldDriveSourcesBucket = 'world-drive-sources';

abstract interface class WorldPublishSourceGateway {
  bool get isAvailable;
  String? get currentUserId;
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  });
  Future<Map<String, dynamic>> attach(Map<String, dynamic> params);
}

class SupabaseWorldPublishSourceGateway implements WorldPublishSourceGateway {
  SupabaseClient? get _client =>
      SupabaseBootstrap.isInitialized ? Supabase.instance.client : null;

  @override
  bool get isAvailable => _client != null;

  @override
  String? get currentUserId => _client?.auth.currentSession?.user.id;

  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  }) async {
    await _client!.storage
        .from(worldDriveSourcesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: upsert),
        );
  }

  @override
  Future<Map<String, dynamic>> attach(Map<String, dynamic> params) async {
    final response = await _client!.rpc(
      'attach_world_publish_source',
      params: params,
    );
    if (response is Map) return response.cast<String, dynamic>();
    if (response is List && response.length == 1 && response.first is Map) {
      return (response.first as Map).cast<String, dynamic>();
    }
    throw const FormatException('Unexpected attach RPC response');
  }
}

enum WorldPublishSourceUploadStatus {
  success,
  notSignedIn,
  supabaseUnavailable,
  missingCanonicalTelemetry,
  invalidCanonicalTelemetry,
  invalidDrive,
  publishDriveMismatch,
  uploadFailure,
  attachFailure,
}

class WorldPublishSourceUploadResult {
  const WorldPublishSourceUploadResult(this.status, {this.publish});

  final WorldPublishSourceUploadStatus status;
  final WorldPublish? publish;
}

/// Uploads the immutable source snapshot, then attaches it to the server row.
/// A deterministic path makes an upload-before-attach crash recoverable.
class WorldPublishSourceUploadService {
  WorldPublishSourceUploadService({
    WorldPublishSourceGateway? gateway,
    PublishedDriveSourceBuilder? builder,
  }) : _gateway = gateway ?? SupabaseWorldPublishSourceGateway(),
       _builder = builder ?? const PublishedDriveSourceBuilder();

  final WorldPublishSourceGateway _gateway;
  final PublishedDriveSourceBuilder _builder;

  Future<WorldPublishSourceUploadResult> uploadSource({
    required DriveSession drive,
    required WorldPublish publish,
    Future<WorldPublish?> Function(String localDriveId)? reloadPublish,
  }) async {
    if (!_gateway.isAvailable) {
      return const WorldPublishSourceUploadResult(
        WorldPublishSourceUploadStatus.supabaseUnavailable,
      );
    }
    final userId = _gateway.currentUserId;
    if (userId == null) {
      return const WorldPublishSourceUploadResult(
        WorldPublishSourceUploadStatus.notSignedIn,
      );
    }
    if (publish.localDriveId != drive.id || publish.userId != userId) {
      return const WorldPublishSourceUploadResult(
        WorldPublishSourceUploadStatus.publishDriveMismatch,
      );
    }
    if (publish.sourceReady) {
      return WorldPublishSourceUploadResult(
        WorldPublishSourceUploadStatus.success,
        publish: publish,
      );
    }
    final built = _builder.build(drive: drive, publish: publish);
    if (built.source == null) {
      return WorldPublishSourceUploadResult(switch (built.status) {
        PublishedDriveSourceBuildStatus.missingCanonicalTelemetry =>
          WorldPublishSourceUploadStatus.missingCanonicalTelemetry,
        PublishedDriveSourceBuildStatus.invalidCanonicalTelemetry =>
          WorldPublishSourceUploadStatus.invalidCanonicalTelemetry,
        PublishedDriveSourceBuildStatus.invalidDrive =>
          WorldPublishSourceUploadStatus.invalidDrive,
        PublishedDriveSourceBuildStatus.publishDriveMismatch =>
          WorldPublishSourceUploadStatus.publishDriveMismatch,
        PublishedDriveSourceBuildStatus.success =>
          WorldPublishSourceUploadStatus.invalidDrive,
      });
    }
    final source = built.source!;
    final path = '$userId/${publish.id}.json';
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(source.toJson())));
    try {
      await _gateway.upload(
        path: path,
        bytes: bytes,
        contentType: 'application/json',
        upsert: false,
      );
    } on StorageException catch (error) {
      if (!_isExistingObject(error)) {
        return const WorldPublishSourceUploadResult(
          WorldPublishSourceUploadStatus.uploadFailure,
        );
      }
      // An earlier attempt may have uploaded this deterministic object before
      // the attach RPC completed. Never overwrite it.
    } catch (_) {
      return const WorldPublishSourceUploadResult(
        WorldPublishSourceUploadStatus.uploadFailure,
      );
    }

    final params = <String, dynamic>{
      'p_publish_id': publish.id,
      'p_source_schema_version': source.schemaVersion,
      'p_telemetry_version': source.telemetryVersion,
      'p_drive_score_algorithm_version': source.driveScoreAlgorithmVersion,
      'p_raw_route_point_count': source.rawRoute.length,
      'p_telemetry_point_count': source.canonicalTelemetry.length,
    };
    try {
      final attached = WorldPublish.fromRow(await _gateway.attach(params));
      if (attached.sourceReady &&
          attached.localDriveId == drive.id &&
          attached.userId == userId) {
        return WorldPublishSourceUploadResult(
          WorldPublishSourceUploadStatus.success,
          publish: attached,
        );
      }
    } catch (_) {
      // A previous attempt can already have attached the source. Re-read the
      // server row, accepting success only when server-owned fields confirm it.
      if (reloadPublish != null) {
        try {
          final current = await reloadPublish(drive.id);
          if (current != null &&
              current.sourceReady &&
              current.id == publish.id &&
              current.userId == userId) {
            return WorldPublishSourceUploadResult(
              WorldPublishSourceUploadStatus.success,
              publish: current,
            );
          }
        } catch (_) {
          // Keep the original attach failure as the domain outcome.
        }
      }
    }
    return const WorldPublishSourceUploadResult(
      WorldPublishSourceUploadStatus.attachFailure,
    );
  }

  bool _isExistingObject(StorageException error) {
    if (error.statusCode != '409') return false;
    final code = error.error?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    return code == 'duplicate' ||
        code == 'resourcealreadyexists' ||
        message.contains('already exists');
  }
}
