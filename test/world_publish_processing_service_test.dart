import 'dart:async';

import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_processing_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

  @override
  bool get isAvailable => available;

  @override
  bool get hasSession => session;

  @override
  Future<Object?> invoke(String functionName, Map<String, dynamic> body) {
    calls.add((functionName, Map.of(body)));
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

  test('processing and published rows are never invoked again', () async {
    final gateway = _Gateway();
    final service = WorldPublishProcessingService(gateway: gateway);
    expect(
      (await service.process(
        WorldPublish.fromRow(_row(status: 'processing')),
      )).status,
      WorldPublishProcessingStatus.retryableFailure,
    );
    expect(
      (await service.process(
        WorldPublish.fromRow(_row(status: 'published')),
      )).status,
      WorldPublishProcessingStatus.permanentFailure,
    );
    expect(gateway.calls, isEmpty);
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
}
