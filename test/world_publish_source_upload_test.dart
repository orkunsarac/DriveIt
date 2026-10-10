import 'dart:convert';
import 'dart:typed_data';

import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/published_drive_source_builder.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_service.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_processing_service.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_source_upload_service.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_submission_service.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _row({bool ready = false, String status = 'pending'}) => {
  'id': 'publish-uuid',
  'user_id': 'user-uuid',
  'local_drive_id': 'drive-id',
  'started_at': '2026-09-23T11:58:00Z',
  'ended_at': '2026-09-23T12:00:00Z',
  'distance_meters': 5000,
  'world_rules_version': MyWorldRules.worldRulesVersion,
  'status': status,
  'error_code': null,
  'created_at': '2026-09-23T12:01:00Z',
  'updated_at': '2026-09-23T12:01:00Z',
  'processed_at': null,
  'source_path': ready ? 'user-uuid/publish-uuid.json' : null,
  'source_schema_version': ready ? 1 : null,
  'telemetry_version': ready ? 1 : null,
  'drive_score_algorithm_version': ready ? 1 : null,
  'raw_route_point_count': ready ? 3 : null,
  'telemetry_point_count': ready ? 3 : null,
  'source_ready_at': ready ? '2026-09-23T12:02:00Z' : null,
};

DriveSession _drive() => DriveSession(
  id: 'drive-id',
  date: DateTime.utc(2026, 9, 23, 12),
  distance: 5000,
  durationSeconds: 120,
  averageSpeed: 10,
  maxSpeed: 20,
  mapImagePath: '',
  route: [
    RoutePoint(latitude: 40.123456789, longitude: 29.123456789),
    RoutePoint(latitude: 40.123456790, longitude: 29.123456790),
    RoutePoint(latitude: 40.123456791, longitude: 29.123456791),
  ],
);

DriveTelemetryRecord _telemetry() => DriveTelemetryRecord(
  driveSessionId: 'drive-id',
  dataVersion: 1,
  createdAt: DateTime.utc(2026, 9, 23, 12),
  acquisitionMetadata: const {'reliabilityPolicyVersion': 1},
  points: List.generate(
    201,
    (index) => CanonicalTelemetryPoint(
      latitude: 40.123456789 + index * 0.000000001,
      longitude: 29.123456789 + index * 0.000000001,
      timestamp: DateTime.utc(2026, 9, 23, 12).add(Duration(seconds: index)),
      speedMps: 8.123456789 + index,
      headingDegrees: 90,
      altitudeMeters: 50,
      accuracyMeters: 3,
      distanceFromPreviousMeters: index == 0 ? 0 : 25,
      accelerationMps2: -0.123456789,
    ),
  ),
);

class _SourceGateway implements WorldPublishSourceGateway {
  bool available = true;
  String? userId = 'user-uuid';
  String? path;
  Uint8List? bytes;
  String? contentType;
  bool? upsert;
  Object? uploadError;
  Object? attachError;
  bool readyAfterAttach = true;
  int uploadCalls = 0;
  int attachCalls = 0;
  Map<String, dynamic>? attachParams;
  final events = <String>[];

  @override
  bool get isAvailable => available;
  @override
  String? get currentUserId => userId;

  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  }) async {
    uploadCalls++;
    events.add('upload');
    this.path = path;
    this.bytes = bytes;
    this.contentType = contentType;
    this.upsert = upsert;
    if (uploadError case final error?) throw error;
  }

  @override
  Future<Map<String, dynamic>> attach(Map<String, dynamic> params) async {
    attachCalls++;
    events.add('attach');
    attachParams = params;
    if (attachError case final error?) throw error;
    return _row(ready: readyAfterAttach);
  }
}

class _PublishGateway implements WorldPublishGateway {
  _PublishGateway(this.events);
  final List<String> events;
  bool available = true;
  String? userId = 'user-uuid';
  Map<String, dynamic>? existing;
  int insertCalls = 0;
  int lookupCalls = 0;
  @override
  bool get isAvailable => available;
  @override
  String? get currentUserId => userId;
  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload) async {
    insertCalls++;
    events.add('create');
    return _row();
  }

  @override
  Future<Map<String, dynamic>?> findForLocalDrive({
    required String userId,
    required String localDriveId,
  }) async {
    lookupCalls++;
    events.add('lookup');
    return existing;
  }
}

class _ProcessingGateway implements WorldPublishProcessingGateway {
  _ProcessingGateway(this.events);
  final List<String> events;
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  bool get isAvailable => true;
  @override
  bool get hasSession => true;
  @override
  Future<Object?> invoke(String functionName, Map<String, dynamic> body) async {
    events.add('process');
    calls.add((functionName, Map.of(body)));
    return {
      'ok': true,
      'validation': {
        'validated_road_id': 'road-1',
        'valid_distance_meters': 5000,
        'eligible_for_world': true,
        'section_count': 2,
      },
    };
  }
}

void main() {
  late _SourceGateway sourceGateway;
  late WorldPublishSourceUploadService uploadService;
  setUp(() {
    sourceGateway = _SourceGateway();
    uploadService = WorldPublishSourceUploadService(
      gateway: sourceGateway,
      builder: PublishedDriveSourceBuilder(
        telemetryLoader: (_) => _telemetry(),
      ),
    );
  });

  test(
    'private deterministic path, full JSON, options and attach parameters',
    () async {
      final result = await uploadService.uploadSource(
        drive: _drive(),
        publish: WorldPublish.fromRow(_row()),
      );
      expect(result.status, WorldPublishSourceUploadStatus.success);
      expect(result.publish!.sourceReady, isTrue);
      expect(result.publish!.rawRoutePointCount, 3);
      expect(sourceGateway.path, 'user-uuid/publish-uuid.json');
      expect(sourceGateway.contentType, 'application/json');
      expect(sourceGateway.upsert, isFalse);
      expect(sourceGateway.events, ['upload', 'attach']);
      final json = jsonDecode(utf8.decode(sourceGateway.bytes!)) as Map;
      expect((json['raw_route'] as List).length, 3);
      expect((json['canonical_telemetry'] as List).length, 201);
      expect((json['raw_route'] as List).first['latitude'], 40.123456789);
      expect(
        (json['canonical_telemetry'] as List).first['speed_mps'],
        8.123456789,
      );
      expect(sourceGateway.attachParams, {
        'p_publish_id': 'publish-uuid',
        'p_source_schema_version': 1,
        'p_telemetry_version': 1,
        'p_drive_score_algorithm_version': 1,
        'p_raw_route_point_count': 3,
        'p_telemetry_point_count': 201,
      });
    },
  );

  test(
    'upload failure stops before RPC; only object-exists 409 proceeds',
    () async {
      sourceGateway.uploadError = const StorageException(
        'network failed',
        statusCode: '500',
      );
      final failed = await uploadService.uploadSource(
        drive: _drive(),
        publish: WorldPublish.fromRow(_row()),
      );
      expect(failed.status, WorldPublishSourceUploadStatus.uploadFailure);
      expect(sourceGateway.attachCalls, 0);
      sourceGateway.uploadError = const StorageException(
        'The resource already exists',
        error: 'Duplicate',
        statusCode: '409',
      );
      final resumed = await uploadService.uploadSource(
        drive: _drive(),
        publish: WorldPublish.fromRow(_row()),
      );
      expect(resumed.status, WorldPublishSourceUploadStatus.success);
      expect(sourceGateway.attachCalls, 1);
    },
  );

  test('missing telemetry and publish mismatch never upload', () async {
    final missing = WorldPublishSourceUploadService(
      gateway: sourceGateway,
      builder: PublishedDriveSourceBuilder(telemetryLoader: (_) => null),
    );
    expect(
      (await missing.uploadSource(
        drive: _drive(),
        publish: WorldPublish.fromRow(_row()),
      )).status,
      WorldPublishSourceUploadStatus.missingCanonicalTelemetry,
    );
    expect(
      (await uploadService.uploadSource(
        drive: _drive(),
        publish: WorldPublish.fromRow({..._row(), 'local_drive_id': 'other'}),
      )).status,
      WorldPublishSourceUploadStatus.publishDriveMismatch,
    );
    expect(sourceGateway.uploadCalls, 0);
  });

  test('RPC failure accepts only a matching server-ready refetch', () async {
    sourceGateway.attachError = const PostgrestException(
      message: 'already attached',
    );
    final result = await uploadService.uploadSource(
      drive: _drive(),
      publish: WorldPublish.fromRow(_row()),
      reloadPublish: (_) async => WorldPublish.fromRow(_row(ready: true)),
    );
    expect(result.status, WorldPublishSourceUploadStatus.success);
    expect(result.publish!.sourceReady, isTrue);
    final failed = await uploadService.uploadSource(
      drive: _drive(),
      publish: WorldPublish.fromRow(_row()),
      reloadPublish: (_) async => WorldPublish.fromRow(_row()),
    );
    expect(failed.status, WorldPublishSourceUploadStatus.attachFailure);
  });

  test('RPC response without source-ready fields is not success', () async {
    sourceGateway.readyAfterAttach = false;
    final result = await uploadService.uploadSource(
      drive: _drive(),
      publish: WorldPublish.fromRow(_row()),
    );
    expect(result.status, WorldPublishSourceUploadStatus.attachFailure);
    expect(result.publish, isNull);
  });

  test('new publish calls create then upload then attach', () async {
    final publishGateway = _PublishGateway(sourceGateway.events);
    final processingGateway = _ProcessingGateway(sourceGateway.events);
    final submit = WorldPublishSubmissionService(
      publishService: WorldPublishService(
        telemetryLoader: (_) => _telemetry(),
        gateway: publishGateway,
        savedDriveLookup: (_) => _drive(),
      ),
      uploadService: uploadService,
      processingService: WorldPublishProcessingService(
        gateway: processingGateway,
      ),
    );
    final result = await submit.submitDriveForPlanet(_drive());
    expect(result.status, WorldPublishSubmissionStatus.success);
    expect(sourceGateway.events, [
      'lookup',
      'create',
      'upload',
      'attach',
      'process',
      'lookup',
    ]);
    expect(processingGateway.calls, hasLength(1));
    expect(processingGateway.calls.single.$1, 'process-world-publish');
    expect(processingGateway.calls.single.$2, {'publish_id': 'publish-uuid'});
    expect(publishGateway.insertCalls, 1);
  });

  test(
    'old pending row reuses row; ready and processing rows never upload',
    () async {
      final publishGateway = _PublishGateway(sourceGateway.events)
        ..existing = _row();
      final processingGateway = _ProcessingGateway(sourceGateway.events);
      final submit = WorldPublishSubmissionService(
        publishService: WorldPublishService(
          gateway: publishGateway,
          savedDriveLookup: (_) => _drive(),
        ),
        uploadService: uploadService,
        processingService: WorldPublishProcessingService(
          gateway: processingGateway,
        ),
      );
      expect(
        (await submit.submitDriveForPlanet(_drive())).status,
        WorldPublishSubmissionStatus.success,
      );
      expect(publishGateway.insertCalls, 0);
      expect(sourceGateway.uploadCalls, 1);
      processingGateway.calls.clear();
      publishGateway.existing = _row(ready: true);
      expect(
        (await submit.submitDriveForPlanet(_drive())).status,
        WorldPublishSubmissionStatus.success,
      );
      expect(publishGateway.insertCalls, 0);
      expect(sourceGateway.uploadCalls, 1);
      expect(processingGateway.calls, hasLength(1));
      expect(sourceGateway.events, contains('process'));
      publishGateway.existing = _row(status: 'processing');
      expect(
        (await submit.submitDriveForPlanet(_drive())).status,
        WorldPublishSubmissionStatus.processing,
      );
      publishGateway.existing = _row(status: 'published');
      expect(
        (await submit.submitDriveForPlanet(_drive())).status,
        WorldPublishSubmissionStatus.published,
      );
      expect(sourceGateway.uploadCalls, 1);
      expect(processingGateway.calls, hasLength(1));
      publishGateway.existing = _row(status: 'failed');
      expect(
        (await submit.submitDriveForPlanet(_drive())).status,
        WorldPublishSubmissionStatus.serverFailed,
      );
      expect(sourceGateway.uploadCalls, 1);
      expect(processingGateway.calls, hasLength(1));
    },
  );
}
