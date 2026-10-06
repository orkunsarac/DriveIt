import 'dart:async';

import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_processing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Gateway implements WorldPublishProcessingGateway {
  bool available = true;
  bool session = true;
  Object? response = {
    'ok': true,
    'publish_id': 'publish-1',
    'validation': {
      'validated_road_id': 'road-1',
      'valid_distance_meters': 6123,
      'eligible_for_world': true,
      'section_count': 4,
    },
  };
  final calls = <(String, Map<String, dynamic>)>[];
  Completer<Object?>? completer;
  Object? failure;

  @override
  bool get isAvailable => available;

  @override
  bool get hasSession => session;

  @override
  Future<Object?> invoke(String functionName, Map<String, dynamic> body) {
    calls.add((functionName, Map.of(body)));
    if (failure != null) return Future.error(failure!);
    return completer?.future ?? Future.value(response);
  }
}

Map<String, dynamic> _row({String status = 'pending', bool ready = true}) => {
  'id': 'publish-1',
  'user_id': 'user-1',
  'local_drive_id': 'drive-1',
  'started_at': '2026-09-23T11:58:00Z',
  'ended_at': '2026-09-23T12:00:00Z',
  'distance_meters': 5000,
  'world_rules_version': MyWorldRules.worldRulesVersion,
  'status': status,
  'error_code': null,
  'created_at': '2026-09-23T12:01:00Z',
  'updated_at': '2026-09-23T12:01:00Z',
  'processed_at': null,
  'source_path': ready ? 'user-1/publish-1.json' : null,
  'source_ready_at': ready ? '2026-09-23T12:02:00Z' : null,
};

void main() {
  test('stale generation conflict is retryable without changing publish/source', () async {
    final gateway = _Gateway()..failure = FunctionException(status: 409,
      details: {'ok': false, 'error_code': 'stale_generation'}, reasonPhrase: 'Conflict');
    final result = await WorldPublishProcessingService(gateway: gateway)
      .process(WorldPublish.fromRow(_row(status: 'processing')));
    expect(result.status, WorldPublishProcessingStatus.retryableFailure);
    expect(result.errorCode, 'stale_generation');
    expect(gateway.calls.single.$2, {'publish_id': 'publish-1'});
  });
  test('uses authenticated function invoke with only publish id', () async {
    final gateway = _Gateway();
    final result = await WorldPublishProcessingService(
      gateway: gateway,
    ).process(WorldPublish.fromRow(_row()));

    expect(result.status, WorldPublishProcessingStatus.success);
    expect(result.validation?.validatedRoadId, 'road-1');
    expect(result.validation?.validDistanceMeters, 6123);
    expect(result.validation?.eligibleForWorld, isTrue);
    expect(result.validation?.sectionCount, 4);
    expect(gateway.calls, hasLength(1));
    expect(gateway.calls.single.$1, 'process-world-publish');
    expect(gateway.calls.single.$2, {'publish_id': 'publish-1'});
  });

  test('does not invoke until source is ready', () async {
    final gateway = _Gateway();
    final result = await WorldPublishProcessingService(
      gateway: gateway,
    ).process(WorldPublish.fromRow(_row(ready: false)));
    expect(result.status, WorldPublishProcessingStatus.permanentFailure);
    expect(result.wasInvoked, isFalse);
    expect(gateway.calls, isEmpty);
  });

  test('processing source-ready recovery invokes; published never invokes', () async {
    final gateway = _Gateway();
    final service = WorldPublishProcessingService(gateway: gateway);
    expect(
      (await service.process(
        WorldPublish.fromRow(_row(status: 'processing')),
      )).status,
      WorldPublishProcessingStatus.success,
    );
    expect(gateway.calls, hasLength(1));
    expect(gateway.calls.single.$2, {'publish_id': 'publish-1'});
    expect(
      (await service.process(
        WorldPublish.fromRow(_row(status: 'published')),
      )).status,
      WorldPublishProcessingStatus.permanentFailure,
    );
    expect(gateway.calls, hasLength(1));
  });

  test('missing session and config are typed without invoking', () async {
    final gateway = _Gateway()..session = false;
    final service = WorldPublishProcessingService(gateway: gateway);
    expect(
      (await service.process(WorldPublish.fromRow(_row()))).status,
      WorldPublishProcessingStatus.notAuthenticated,
    );
    gateway
      ..session = true
      ..available = false;
    expect(
      (await service.process(WorldPublish.fromRow(_row()))).status,
      WorldPublishProcessingStatus.retryableFailure,
    );
    expect(gateway.calls, isEmpty);
  });

  test('safe error codes map retryable and permanent failures', () async {
    final gateway = _Gateway()
      ..response = {'ok': false, 'error_code': 'publish_lookup_failed'};
    final service = WorldPublishProcessingService(gateway: gateway);
    expect(
      (await service.process(WorldPublish.fromRow(_row()))).status,
      WorldPublishProcessingStatus.retryableFailure,
    );
    gateway.response = {
      'ok': false,
      'error_code': 'route_validation_failed',
      'secret': 'must-not-escape',
    };
    final permanent = await service.process(WorldPublish.fromRow(_row()));
    expect(permanent.status, WorldPublishProcessingStatus.permanentFailure);
    expect(permanent.errorCode, 'route_validation_failed');
    expect(permanent.errorCode, isNot(contains('must-not-escape')));
  });

  test('debug diagnostic logs only allowlisted FunctionException fields', () async {
    final logLines = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logLines.add(message ?? '');
    try {
      final gateway = _Gateway();
      final service = WorldPublishProcessingService(gateway: gateway);
      for (final code in [
        'validated_sections_invalid',
        'active_world_commit_failed',
      ]) {
        gateway.failure = FunctionException(
          status: 503,
          details: {
            'ok': false,
            'error_code': code,
            'authorization': 'Bearer secret-token',
            'headers': {'apikey': 'secret-key'},
          },
        );
        final result = await service.process(WorldPublish.fromRow(_row()));
        expect(result.errorCode, code);
        expect(result.status, WorldPublishProcessingStatus.retryableFailure);
      }
      gateway.failure = const FunctionException(
        status: 503,
        details: '{"ok":false,"error_code":"validated_sections_lookup_failed","authorization":"Bearer secret-token"}',
      );
      final stringBody = await service.process(WorldPublish.fromRow(_row()));
      expect(stringBody.errorCode, 'server_error');
      gateway.failure = const FunctionException(
        status: 503,
        details: '{invalid json Bearer secret-token',
      );
      final malformed = await service.process(WorldPublish.fromRow(_row()));
      expect(malformed.errorCode, 'server_error');
      expect(malformed.status, WorldPublishProcessingStatus.retryableFailure);

      if (kDebugMode) {
        expect(logLines, hasLength(4));
        expect(logLines[0], contains('http_status=503 error_code=validated_sections_invalid'));
        expect(logLines[1], contains('http_status=503 error_code=active_world_commit_failed'));
        expect(logLines[2], contains('http_status=503 error_code=validated_sections_lookup_failed'));
        expect(logLines[3], contains('http_status=503 error_code=unavailable'));
        for (final line in logLines) {
          expect(line, contains('DriveItWorldPublish function=process-world-publish'));
          expect(line, contains('publish_id=publish-1'));
          expect(line, isNot(contains('secret-token')));
          expect(line, isNot(contains('secret-key')));
          expect(line, isNot(contains('authorization')));
          expect(line, isNot(contains('headers')));
        }
      } else {
        expect(logLines, isEmpty);
      }
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  test('parallel duplicate taps share one invocation', () async {
    final gateway = _Gateway()..completer = Completer<Object?>();
    final service = WorldPublishProcessingService(gateway: gateway);
    final first = service.process(WorldPublish.fromRow(_row()));
    final second = service.process(WorldPublish.fromRow(_row()));
    expect(gateway.calls, hasLength(1));
    gateway.completer!.complete(gateway.response);
    final results = await Future.wait([first, second]);
    expect(
      results,
      everyElement(
        isA<WorldPublishProcessingResult>().having(
          (result) => result.status,
          'status',
          WorldPublishProcessingStatus.success,
        ),
      ),
    );
    expect(gateway.calls, hasLength(1));
  });

  test('parallel processing recovery shares one invocation', () async {
    final gateway = _Gateway()..completer = Completer<Object?>();
    final service = WorldPublishProcessingService(gateway: gateway);
    final publish = WorldPublish.fromRow(_row(status: 'processing'));
    final first = service.process(publish);
    final second = service.process(publish);
    expect(gateway.calls, hasLength(1));
    gateway.completer!.complete(gateway.response);
    final results = await Future.wait([first, second]);
    expect(
      results,
      everyElement(
        isA<WorldPublishProcessingResult>().having(
          (result) => result.status,
          'status',
          WorldPublishProcessingStatus.success,
        ),
      ),
    );
    expect(gateway.calls, hasLength(1));
  });
}
