import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_calculator.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_submission_service.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uidA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _uidB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _project = 'https://arwnbogcswisfesayosy.supabase.co';
const _publicKey = 'sb_publishable_synthetic';
const _driveId = 'drive-schema2-a';
const _publishId = '11111111-1111-4111-8111-111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'owner scoped schema2 full publish requires consent and reaches server-confirmed terminal state',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      try {
        final denied = await fixture.service.submitDriveForPlanet(
          fixture.drive,
        );
        expect(denied.status, WorldPublishSubmissionStatus.consentRequired);
        expect(fixture.events, ['lookup']);

        final result = await fixture.service.submitDriveForPlanet(
          _alteredCallerDrive(fixture.drive.id),
          confirmedFullDriveShare: true,
        );
        expect(fixture.events, contains('storage'));
        expect(fixture.requestAuth, everyElement('Bearer token-a'));
        expect(fixture.events, [
          'lookup',
          'lookup',
          'insert',
          'storage',
          'attach',
          'process',
          'lookup',
        ]);
        expect(result.status, WorldPublishSubmissionStatus.success);
        expect(result.publish?.status.name, 'published');
        expect(result.publish?.distanceMeters, 7160);
        expect(fixture.events, [
          'lookup',
          'lookup',
          'insert',
          'storage',
          'attach',
          'process',
          'lookup',
        ]);
        expect(fixture.attachParams?['p_source_schema_version'], 2);
        expect(
          fixture.requestAuth.every((value) => value == 'Bearer token-a'),
          isTrue,
        );
        expect(
          fixture.requestPaths.where((path) => path.contains('/storage/')),
          hasLength(1),
        );
        expect(
          fixture.requestPaths.where((path) => path.contains('/functions/')),
          hasLength(1),
        );
        expect(
          fixture.requestPaths.where(
            (path) => path.contains('/rpc/attach_world_publish_source'),
          ),
          hasLength(1),
        );
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'A to B transition during immutable upload never continues with B credentials',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      final enteredUpload = Completer<void>();
      final releaseUpload = Completer<void>();
      fixture.holdUpload = true;
      fixture.uploadEntered = enteredUpload;
      fixture.releaseUpload = releaseUpload;
      try {
        final pending = fixture.service.submitDriveForPlanet(
          fixture.drive,
          confirmedFullDriveShare: true,
        );
        await enteredUpload.future;
        fixture.authUid = _uidB;
        fixture.authToken = 'token-b';
        await fixture.sdk.auth.signInWithPassword(
          email: 'b@example.invalid',
          password: 'synthetic',
        );
        await Future<void>.delayed(Duration.zero);
        await fixture.runtime.settled;
        expect(fixture.lease.isCurrent, isFalse);
        releaseUpload.complete();
        final result = await pending;
        expect(result.status, isNot(WorldPublishSubmissionStatus.success));
        expect(fixture.requestAuth, isNot(contains('Bearer token-b')));
        expect(fixture.events, isNot(contains('attach')));
        expect(fixture.events, isNot(contains('process')));
        // The owned local drive remains in A's retained store, never re-bound to B.
        expect(fixture.lease.isCurrent, isFalse);
      } finally {
        if (!releaseUpload.isCompleted) releaseUpload.complete();
        await fixture.close();
      }
    },
  );

  test(
    'lost insert/process ACK and Storage 409 reconcile one owner row',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      fixture.loseInsertAck = true;
      fixture.storageAlreadyExists = true;
      fixture.loseProcessAck = true;
      try {
        final result = await fixture.service.submitDriveForPlanet(
          fixture.drive,
          confirmedFullDriveShare: true,
        );
        expect(result.status, WorldPublishSubmissionStatus.success);
        expect(result.publish?.status.name, 'published');
        expect(
          fixture.events.where((event) => event == 'insert'),
          hasLength(1),
        );
        expect(
          fixture.events.where((event) => event == 'storage'),
          hasLength(1),
        );
        expect(
          fixture.events.where((event) => event == 'attach'),
          hasLength(1),
        );
        expect(
          fixture.events.where((event) => event == 'process'),
          hasLength(1),
        );
        expect(fixture.attachParams?['p_source_schema_version'], 2);
        expect(fixture.requestAuth, everyElement('Bearer token-a'));

        final retry = await fixture.service.submitDriveForPlanet(fixture.drive);
        expect(retry.status, WorldPublishSubmissionStatus.published);
        expect(
          fixture.events.where((event) => event == 'insert'),
          hasLength(1),
        );
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'existing schema1 publication is recovered without creating a new row',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      fixture.seedLegacyPublishedRow();
      try {
        final result = await fixture.service.submitDriveForPlanet(
          fixture.drive,
        );
        expect(result.status, WorldPublishSubmissionStatus.published);
        expect(result.publish?.sourceSchemaVersion, 1);
        expect(fixture.events, ['lookup']);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'invalid reliable evidence is rejected before pending row or source upload',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      final telemetry = _reliableTelemetry();
      await fixture.lease.put(
        'drive_telemetry',
        fixture.drive.id,
        DriveTelemetryRecord(
          driveSessionId: telemetry.driveSessionId,
          dataVersion: telemetry.dataVersion,
          createdAt: telemetry.createdAt,
          acquisitionMetadata: telemetry.acquisitionMetadata,
          points: [
            for (final point in telemetry.points)
              CanonicalTelemetryPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: point.timestamp,
                speedMps: point.speedMps,
                headingDegrees: point.headingDegrees,
                altitudeMeters: point.altitudeMeters,
                accuracyMeters: point.accuracyMeters,
                distanceFromPreviousMeters: point.distanceFromPreviousMeters,
                accelerationMps2: point.accelerationMps2,
                breakBefore: point.breakBefore,
                gapDurationMicros: point.gapDurationMicros,
                speedSource: 'legacy',
              ),
          ],
        ),
      );
      try {
        final result = await fixture.service.submitDriveForPlanet(
          fixture.drive,
          confirmedFullDriveShare: true,
        );
        expect(result.status, WorldPublishSubmissionStatus.notEligible);
        expect(fixture.events, ['lookup']);
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'same UID token refresh fences in-flight request, retry uses refreshed token',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      final enteredUpload = Completer<void>();
      final releaseUpload = Completer<void>();
      fixture.holdUpload = true;
      fixture.uploadEntered = enteredUpload;
      fixture.releaseUpload = releaseUpload;
      try {
        final pending = fixture.service.submitDriveForPlanet(
          fixture.drive,
          confirmedFullDriveShare: true,
        );
        await enteredUpload.future;
        fixture.authToken = 'token-a-refreshed';
        await fixture.sdk.auth.refreshSession();
        expect(fixture.lease.isCurrent, isTrue);
        fixture.holdUpload = false;
        releaseUpload.complete();
        final result = await pending;
        expect(result.status, WorldPublishSubmissionStatus.uploadFailure);
        expect(fixture.events, isNot(contains('attach')));

        fixture.storageAlreadyExists = true;
        final retry = await fixture.service.submitDriveForPlanet(
          fixture.drive,
          confirmedFullDriveShare: true,
        );
        expect(retry.status, WorldPublishSubmissionStatus.success);
        expect(fixture.requestAuth, contains('Bearer token-a'));
        expect(fixture.requestAuth, contains('Bearer token-a-refreshed'));
        expect(fixture.requestAuth, isNot(contains('Bearer token-b')));
      } finally {
        if (!releaseUpload.isCompleted) releaseUpload.complete();
        await fixture.close();
      }
    },
  );

  test(
    'logout revokes lease and a DEV project gateway cannot be constructed for Play',
    () async {
      final fixture = await _OwnerPublishFixture.create();
      final wrongProject = OwnerProfileGateway(
        authClient: fixture.sdk,
        url: 'https://viqngnjfgknpxtoapzcg.supabase.co',
        publicKey: _publicKey,
        applicationId: 'com.osaracx.driveit',
        approvedOwner: () => fixture.lease.owner.userId,
        approvedEpoch: () => fixture.lease.epoch,
        isLeaseCurrent: (epoch) =>
            epoch == fixture.lease.epoch && fixture.lease.isCurrent,
        transport: fixture.transport.client,
      );
      try {
        expect(wrongProject.isAuthorized, isFalse);
        expect(
          () => WorldPublishSubmissionService.ownerScoped(
            lease: fixture.lease,
            ownerGateway: wrongProject,
          ),
          throwsStateError,
        );
        await fixture.sdk.auth.signOut();
        await Future<void>.delayed(Duration.zero);
        await fixture.runtime.settled;
        expect(fixture.lease.isCurrent, isFalse);
        final result = await fixture.service.submitDriveForPlanet(
          fixture.drive,
          confirmedFullDriveShare: true,
        );
        expect(result.status, WorldPublishSubmissionStatus.invalidDrive);
        expect(fixture.events, isEmpty);
      } finally {
        await fixture.close();
      }
    },
  );
}

class _OwnerPublishFixture {
  _OwnerPublishFixture._({
    required this.root,
    required this.sdk,
    required this.runtime,
    required this.lease,
    required this.service,
    required this.drive,
    required this.transport,
  });

  final Directory root;
  final SupabaseClient sdk;
  final LocalOwnerLifecycle runtime;
  final LocalOwnerLease lease;
  final WorldPublishSubmissionService service;
  final DriveSession drive;
  final _PublishTransport transport;
  List<String> get events => transport.events;
  List<String?> get requestAuth => transport.requestAuth;
  List<String> get requestPaths => transport.requestPaths;
  Map<String, dynamic>? get attachParams => transport.attachParams;
  set holdUpload(bool value) => transport.holdUpload = value;
  set uploadEntered(Completer<void> value) => transport.uploadEntered = value;
  set releaseUpload(Completer<void> value) => transport.releaseUpload = value;
  set authUid(String value) => transport.authUid = value;
  set authToken(String value) => transport.authToken = value;
  set loseInsertAck(bool value) => transport.loseInsertAck = value;
  set storageAlreadyExists(bool value) =>
      transport.storageAlreadyExists = value;
  set loseProcessAck(bool value) => transport.loseProcessAck = value;

  void seedLegacyPublishedRow() => transport.row = {
    'id': _publishId,
    'user_id': _uidA,
    'local_drive_id': _driveId,
    'started_at': '2026-01-01T00:00:00Z',
    'ended_at': '2026-01-01T00:03:00Z',
    'distance_meters': 7160,
    'world_rules_version': MyWorldRules.worldRulesVersion,
    'status': 'published',
    'error_code': null,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:03:00Z',
    'processed_at': '2026-01-01T00:03:00Z',
    'source_path': '$_uidA/$_publishId.json',
    'source_schema_version': 1,
    'telemetry_version': 1,
    'drive_score_algorithm_version': 1,
    'raw_route_point_count': 2,
    'telemetry_point_count': 180,
    'source_ready_at': '2026-01-01T00:02:00Z',
  };

  static Future<_OwnerPublishFixture> create() async {
    final root = await Directory.systemTemp.createTemp('driveit_planet_owner_');
    final transport = _PublishTransport();
    final sdk = SupabaseClient(
      _project,
      _publicKey,
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': transport.authToken,
            'refresh_token': 'refresh-a',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': transport.authUid,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await sdk.auth.signInWithPassword(
      email: 'a@example.invalid',
      password: 'synthetic',
    );
    final runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    await runtime.start();
    final lease = runtime.lease;
    final drive = _reliableDrive();
    final telemetry = _reliableTelemetry();
    final score = DriveScoreRecord.fromResult(
      driveId: drive.id,
      telemetryDataVersion: telemetry.dataVersion,
      calculatedAt: telemetry.points.last.timestamp,
      result: const DriveScoreCalculator().calculateReliable(
        telemetry: telemetry.points,
      ),
    );
    await lease.put('drives', drive.id, drive);
    await lease.put('drive_telemetry', drive.id, telemetry);
    await lease.put(
      'drive_scores',
      DriveScoreStorageService.keyFor(drive.id, score.algorithmVersion),
      score,
    );
    final ownerGateway = OwnerProfileGateway(
      authClient: sdk,
      url: _project,
      publicKey: _publicKey,
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => lease.owner.userId,
      approvedEpoch: () => lease.epoch,
      isLeaseCurrent: (epoch) => epoch == lease.epoch && lease.isCurrent,
      transport: transport.client,
    );
    final service = WorldPublishSubmissionService.ownerScoped(
      lease: lease,
      ownerGateway: ownerGateway,
    );
    return _OwnerPublishFixture._(
      root: root,
      sdk: sdk,
      runtime: runtime,
      lease: lease,
      service: service,
      drive: drive,
      transport: transport,
    );
  }

  Future<void> close() async {
    await runtime.close();
    runtime.dispose();
    await sdk.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

class _PublishTransport {
  String authUid = _uidA;
  String authToken = 'token-a';
  bool holdUpload = false;
  bool loseInsertAck = false;
  bool storageAlreadyExists = false;
  bool loseProcessAck = false;
  Completer<void>? uploadEntered;
  Completer<void>? releaseUpload;
  Map<String, dynamic>? row;
  Map<String, dynamic>? attachParams;
  final events = <String>[];
  final requestAuth = <String?>[];
  final requestPaths = <String>[];

  late final client = MockClient(_handle);

  Future<http.Response> _handle(http.BaseRequest request) async {
    requestAuth.add(request.headers['authorization']);
    requestPaths.add(request.url.path);
    if (request.url.path.endsWith('/rest/v1/world_publishes') &&
        request.method == 'GET') {
      events.add('lookup');
      if (row == null) return _json([], request);
      if (row!['user_id'] != _uidForToken(request.headers['authorization'])) {
        return _json([], request);
      }
      return _json(row!, request);
    }
    if (request.url.path.endsWith('/rest/v1/world_publishes') &&
        request.method == 'POST') {
      events.add('insert');
      if (_uidForToken(request.headers['authorization']) != _uidA) {
        return _json({'message': 'owner mismatch'}, request, status: 403);
      }
      final payload = _jsonBody(request);
      row = {
        'id': _publishId,
        'user_id': _uidA,
        'local_drive_id': payload['local_drive_id'],
        'started_at': payload['started_at'],
        'ended_at': payload['ended_at'],
        'distance_meters': payload['distance_meters'],
        'world_rules_version': MyWorldRules.worldRulesVersion,
        'status': 'pending',
        'error_code': null,
        'created_at': payload['started_at'],
        'updated_at': payload['ended_at'],
        'processed_at': null,
        'source_path': null,
        'source_schema_version': null,
        'telemetry_version': null,
        'drive_score_algorithm_version': null,
        'raw_route_point_count': null,
        'telemetry_point_count': null,
        'source_ready_at': null,
      };
      if (loseInsertAck) {
        loseInsertAck = false;
        return _json({'message': 'ack lost'}, request, status: 503);
      }
      return _json(row!, request);
    }
    if (request.url.path.contains('/storage/v1/object/world-drive-sources/')) {
      events.add('storage');
      if (_uidForToken(request.headers['authorization']) != _uidA) {
        return _json({'message': 'owner mismatch'}, request, status: 403);
      }
      if (holdUpload) {
        uploadEntered?.complete();
        await releaseUpload!.future;
      }
      if (storageAlreadyExists) {
        return _json(
          {
            'statusCode': '409',
            'error': 'Duplicate',
            'message': 'The resource already exists',
          },
          request,
          status: 409,
        );
      }
      return _json({'Key': request.url.path}, request);
    }
    if (request.url.path.endsWith('/rest/v1/rpc/attach_world_publish_source')) {
      events.add('attach');
      if (_uidForToken(request.headers['authorization']) != _uidA ||
          row == null) {
        return _json({'message': 'owner mismatch'}, request, status: 403);
      }
      final params = _jsonBody(request);
      attachParams = params;
      row = {
        ...row!,
        'source_path': '$_uidA/$_publishId.json',
        'source_schema_version': params['p_source_schema_version'],
        'telemetry_version': params['p_telemetry_version'],
        'drive_score_algorithm_version':
            params['p_drive_score_algorithm_version'],
        'raw_route_point_count': params['p_raw_route_point_count'],
        'telemetry_point_count': params['p_telemetry_point_count'],
        'source_ready_at': '2026-01-01T00:03:00Z',
      };
      return _json(row!, request);
    }
    if (request.url.path.endsWith('/functions/v1/process-world-publish')) {
      events.add('process');
      if (_uidForToken(request.headers['authorization']) != _uidA) {
        return _json({'message': 'owner mismatch'}, request, status: 403);
      }
      row = {
        ...row!,
        'status': 'published',
        'processed_at': '2026-01-01T00:04:00Z',
      };
      if (loseProcessAck) {
        loseProcessAck = false;
        return _json({'message': 'ack lost'}, request, status: 503);
      }
      return _json({
        'ok': true,
        'validation': {
          'validated_road_id': 'synthetic-road',
          'valid_distance_meters': 7000,
          'eligible_for_world': true,
          'section_count': 1,
        },
      }, request);
    }
    return _json({'message': 'unexpected request'}, request, status: 404);
  }

  static String? _uidForToken(String? auth) =>
      auth == 'Bearer token-a' || auth == 'Bearer token-a-refreshed'
      ? _uidA
      : auth == 'Bearer token-b'
      ? _uidB
      : null;

  static Map<String, dynamic> _jsonBody(http.BaseRequest request) =>
      jsonDecode((request as http.Request).body) as Map<String, dynamic>;

  static http.Response _json(
    Object body,
    http.BaseRequest request, {
    int status = 200,
  }) => http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

DriveSession _reliableDrive() => DriveSession(
  id: _driveId,
  date: DateTime.utc(2026, 1, 1, 0, 3),
  distance: 7160,
  durationSeconds: 179,
  averageSpeed: 36,
  maxSpeed: 36,
  mapImagePath: '',
  route: [
    RoutePoint(latitude: 40, longitude: 29),
    RoutePoint(latitude: 40, longitude: 29.01),
  ],
);

DriveSession _alteredCallerDrive(String id) => DriveSession(
  id: id,
  date: DateTime.utc(2035, 1, 1),
  distance: 99999,
  durationSeconds: 1,
  averageSpeed: 1,
  maxSpeed: 1,
  mapImagePath: '',
  route: [],
);

DriveTelemetryRecord _reliableTelemetry() {
  final start = DateTime.utc(2026, 1, 1);
  final points = List.generate(
    180,
    (index) => CanonicalTelemetryPoint(
      latitude: 40,
      longitude: 29 + index * .00001,
      timestamp: start.add(Duration(seconds: index)),
      speedMps: 10,
      headingDegrees: 90,
      altitudeMeters: 10,
      accuracyMeters: 3,
      distanceFromPreviousMeters: index == 0 ? 0 : 40,
      accelerationMps2: 0,
      speedSource: 'native',
      breakBefore: index == 90,
      accelerationReliable: index != 90,
    ),
  );
  return DriveTelemetryRecord(
    driveSessionId: _driveId,
    dataVersion: 1,
    createdAt: start,
    points: points,
    acquisitionMetadata: {
      'reliabilityPolicyVersion': 1,
      'startedAtMicros': start.microsecondsSinceEpoch,
      'stopRequestedAtMicros': points.last.timestamp.microsecondsSinceEpoch,
    },
  );
}
