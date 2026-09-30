import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_bootstrap.dart';
import '../models/world_publish.dart';

const processWorldPublishFunction = 'process-world-publish';

enum WorldPublishProcessingStatus {
  success,
  notAuthenticated,
  retryableFailure,
  permanentFailure,
}

class WorldPublishValidationResult {
  const WorldPublishValidationResult({
    required this.validatedRoadId,
    required this.validDistanceMeters,
    required this.eligibleForWorld,
    required this.sectionCount,
  });

  final String validatedRoadId;
  final double validDistanceMeters;
  final bool eligibleForWorld;
  final int sectionCount;
}

class WorldPublishProcessingResult {
  const WorldPublishProcessingResult(
    this.status, {
    this.errorCode,
    this.validation,
    this.wasInvoked = false,
  });

  final WorldPublishProcessingStatus status;
  final String? errorCode;
  final WorldPublishValidationResult? validation;
  final bool wasInvoked;
}

/// Authenticated-client boundary; it never accepts or constructs a JWT/key.
abstract interface class WorldPublishProcessingGateway {
  bool get isAvailable;
  bool get hasSession;
  Future<Object?> invoke(String functionName, Map<String, dynamic> body);
}

class SupabaseWorldPublishProcessingGateway
    implements WorldPublishProcessingGateway {
  SupabaseClient? get _client =>
      SupabaseBootstrap.isInitialized ? Supabase.instance.client : null;

  @override
  bool get isAvailable => _client != null;

  @override
  bool get hasSession => _client?.auth.currentSession != null;

  @override
  Future<Object?> invoke(String functionName, Map<String, dynamic> body) async {
    final response = await _client!.functions.invoke(functionName, body: body);
    return response.data;
  }
}

/// Invokes the server validator with the existing authenticated Supabase
/// client. Duplicate in-flight calls for a publish share a single request.
class WorldPublishProcessingService {
  WorldPublishProcessingService({WorldPublishProcessingGateway? gateway})
    : _gateway = gateway ?? SupabaseWorldPublishProcessingGateway();

  final WorldPublishProcessingGateway _gateway;
  final Map<String, Future<WorldPublishProcessingResult>> _inFlight = {};

  bool get isAvailable => _gateway.isAvailable;
  bool get hasSession => _gateway.hasSession;

  Future<WorldPublishProcessingResult> process(WorldPublish publish) {
    if (!publish.sourceReady) {
      return Future.value(
        const WorldPublishProcessingResult(
          WorldPublishProcessingStatus.permanentFailure,
          errorCode: 'source_not_ready',
        ),
      );
    }
    switch (publish.status) {
      case WorldPublishStatus.processing:
        // A processing row can represent an interrupted server invocation.
        // The server owns idempotency and can resume from its persisted road.
        break;
      case WorldPublishStatus.published:
        return Future.value(
          const WorldPublishProcessingResult(
            WorldPublishProcessingStatus.permanentFailure,
            errorCode: 'already_processed',
          ),
        );
      case WorldPublishStatus.failed:
        return Future.value(
          const WorldPublishProcessingResult(
            WorldPublishProcessingStatus.permanentFailure,
            errorCode: 'publish_failed',
          ),
        );
      case WorldPublishStatus.pending:
        break;
    }
    final existing = _inFlight[publish.id];
    if (existing != null) return existing;
    final future = _processReadyPublish(publish);
    _inFlight[publish.id] = future;
    return future.whenComplete(() => _inFlight.remove(publish.id));
  }

  Future<WorldPublishProcessingResult> _processReadyPublish(
    WorldPublish publish,
  ) async {
    if (!_gateway.isAvailable) {
      return const WorldPublishProcessingResult(
        WorldPublishProcessingStatus.retryableFailure,
        errorCode: 'supabase_unavailable',
      );
    }
    if (!_gateway.hasSession) {
      return const WorldPublishProcessingResult(
        WorldPublishProcessingStatus.notAuthenticated,
        errorCode: 'unauthorized',
      );
    }
    try {
      final response = await _gateway.invoke(processWorldPublishFunction, {
        'publish_id': publish.id,
      });
      return _parseResponse(response);
    } on FunctionException catch (error) {
      _logFunctionException(publish.id, error);
      return _mapFunctionException(error);
    } catch (_) {
      // Do not propagate/log transport details, which may contain headers.
      return const WorldPublishProcessingResult(
        WorldPublishProcessingStatus.retryableFailure,
        errorCode: 'network_error',
        wasInvoked: true,
      );
    }
  }

  void _logFunctionException(String publishId, FunctionException error) {
    if (!kDebugMode) return;
    Object? details = error.details;
    if (details is String) {
      try {
        details = jsonDecode(details);
      } on FormatException {
        details = null;
      }
    }
    final code = details is Map ? _safeErrorCode(details['error_code']) : null;
    debugPrint(
      'DriveItWorldPublish function=$processWorldPublishFunction '
      'publish_id=$publishId http_status=${error.status} '
      'error_code=${code ?? 'unavailable'}',
    );
  }

  WorldPublishProcessingResult _parseResponse(Object? response) {
    if (response is! Map) return _invalidResponse();
    final body = response.cast<Object?, Object?>();
    if (body['ok'] == true) {
      final validation = body['validation'];
      if (validation is! Map) return _invalidResponse();
      final roadId = validation['validated_road_id'];
      final distance = validation['valid_distance_meters'];
      final eligible = validation['eligible_for_world'];
      final sectionCount = validation['section_count'];
      if (roadId is! String ||
          distance is! num ||
          eligible is! bool ||
          sectionCount is! num) {
        return _invalidResponse();
      }
      return WorldPublishProcessingResult(
        WorldPublishProcessingStatus.success,
        validation: WorldPublishValidationResult(
          validatedRoadId: roadId,
          validDistanceMeters: distance.toDouble(),
          eligibleForWorld: eligible,
          sectionCount: sectionCount.toInt(),
        ),
        wasInvoked: true,
      );
    }
    final code = _safeErrorCode(body['error_code']) ?? 'unknown_server_error';
    final status = _classifyErrorCode(code);
    return WorldPublishProcessingResult(
      status,
      errorCode: code,
      wasInvoked: true,
    );
  }

  WorldPublishProcessingResult _mapFunctionException(FunctionException error) {
    final status = error.status;
    final details = error.details;
    final code = details is Map ? _safeErrorCode(details['error_code']) : null;
    if (status == 401 || status == 403 || code == 'unauthorized') {
      return const WorldPublishProcessingResult(
        WorldPublishProcessingStatus.notAuthenticated,
        errorCode: 'unauthorized',
        wasInvoked: true,
      );
    }
    if (status == 0 || status == 429 || status >= 500) {
      return WorldPublishProcessingResult(
        WorldPublishProcessingStatus.retryableFailure,
        errorCode: code ?? (status == 429 ? 'rate_limited' : 'server_error'),
        wasInvoked: true,
      );
    }
    final safeCode = code ?? 'validation_failed';
    return WorldPublishProcessingResult(
      _classifyErrorCode(safeCode),
      errorCode: safeCode,
      wasInvoked: true,
    );
  }

  static WorldPublishProcessingStatus _classifyErrorCode(String code) =>
      switch (code) {
        'processing' ||
        'publish_lookup_failed' ||
        'validation_lookup_failed' ||
        'claim_failed' ||
        'source_download_failed' ||
        'validation_persist_failed' ||
        'state_update_failed' ||
        'validation_retryable' ||
        'mapbox_missingaccesstoken' ||
        'mapbox_network' ||
        'mapbox_timeout' ||
        'mapbox_ratelimited' ||
        'mapbox_server' ||
        'network_error' ||
        'server_error' ||
        'rate_limited' ||
        'supabase_unavailable' => WorldPublishProcessingStatus.retryableFailure,
        'unauthorized' => WorldPublishProcessingStatus.notAuthenticated,
        _ => WorldPublishProcessingStatus.permanentFailure,
      };

  static String? _safeErrorCode(Object? value) {
    if (value is! String || !RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static WorldPublishProcessingResult _invalidResponse() =>
      const WorldPublishProcessingResult(
        WorldPublishProcessingStatus.retryableFailure,
        errorCode: 'invalid_function_response',
        wasInvoked: true,
      );
}
