import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/models/world_processing.dart';
import 'package:driveit_project/features/my_world/providers/mapbox/mapbox_http_transport.dart';
import 'package:driveit_project/features/my_world/providers/mapbox/mapbox_road_matching_provider.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
import 'package:driveit_project/features/my_world/repositories/my_world_repository.dart';
import 'package:driveit_project/features/my_world/services/gps_route_preprocessor.dart';
import 'package:driveit_project/features/my_world/services/map_matching_chunker.dart';
import 'package:driveit_project/features/my_world/services/my_world_validation_service.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('GPS preprocessing', () {
    const preprocessor = GpsRoutePreprocessor();

    test('removes duplicate and excessively close points', () {
      final result = preprocessor.clean([
        _point(41, 29),
        _point(41, 29),
        _point(41.000001, 29),
        _point(41.0001, 29),
      ]);

      expect(result.traces, hasLength(1));
      expect(result.traces.single.points, hasLength(2));
      expect(result.tooClosePointCount, 2);
    });

    test('rejects invalid coordinates and preserves valid sections', () {
      final result = preprocessor.clean([
        _point(41, 29),
        _point(41.0001, 29),
        _point(double.nan, 29),
        _point(91, 29),
        _point(41.01, 29),
        _point(41.0101, 29),
      ]);

      expect(result.invalidPointCount, 2);
      expect(result.traces, hasLength(2));
      expect(result.traces.expand((trace) => trace.points), hasLength(4));
    });

    test('splits large jumps instead of connecting them', () {
      final result = preprocessor.clean([
        _point(41, 29),
        _point(41.0001, 29),
        _point(41.02, 29),
        _point(41.0201, 29),
      ]);

      expect(result.jumpSplitCount, 1);
      expect(result.traces, hasLength(2));
      expect(result.traces.every((trace) => trace.points.length == 2), isTrue);
    });
  });

  test('chunker respects 100 points and carries deterministic overlap', () {
    final cleaned = const GpsRoutePreprocessor().clean(
      List.generate(150, (index) => _point(41 + index * 0.00005, 29)),
    );
    final chunks = const MapMatchingChunker().build(cleaned.traces);

    expect(chunks, hasLength(2));
    expect(chunks.first.points, hasLength(100));
    expect(chunks.last.points, hasLength(53));
    expect(
      chunks.first.points.skip(97).map((point) => point.latitude),
      chunks.last.points.take(3).map((point) => point.latitude),
    );
  });

  group('Mapbox provider', () {
    test('missing token fails safely without an HTTP request', () async {
      final transport = _FakeTransport([]);
      final provider = MapboxRoadMatchingProvider(
        transport: transport,
        accessToken: '',
        endpoint: Uri.parse('https://example.test/matching/v5/mapbox/driving'),
      );

      final result = await provider.match(_request(_shortRoute()));

      expect(result.failureKind, RoadMatchingFailureKind.missingAccessToken);
      expect(result.hasRetryableFailure, isTrue);
      expect(transport.uris, isEmpty);
    });

    test(
      'uses POST and parses geometry, confidence and direction order',
      () async {
        final transport = _FakeTransport([
          _response(
            200,
            _ok([
              [29.0, 41.0],
              [29.001, 41.0],
              [29.002, 41.0],
            ], confidence: 0.84),
          ),
        ]);
        final provider = _provider(transport);
        final result = await provider.match(_request(_shortRoute()));

        expect(result.status, RoadValidationStatus.validated);
        expect(result.geometry, hasLength(3));
        expect(result.geometry.first.longitude, 29);
        expect(result.geometry.last.longitude, 29.002);
        expect(result.directionKey, contains('>'));
        expect(result.confidence, closeTo(0.84, 0.0001));
        expect(result.validDistanceMeters, greaterThan(160));
        expect(
          transport.uris.single.queryParameters['access_token'],
          'test-token',
        );
        expect(
          Uri.splitQueryString(transport.bodies.single)['geometries'],
          'geojson',
        );
        expect(transport.bodies.single, isNot(contains('test-token')));
      },
    );

    test('empty matching response is a safe API failure', () async {
      final provider = _provider(
        _FakeTransport([
          _response(200, jsonEncode({'code': 'Ok', 'matchings': []})),
        ]),
      );
      final result = await provider.match(_request(_shortRoute()));

      expect(result.hasUsableGeometry, isFalse);
      expect(result.failureKind, RoadMatchingFailureKind.apiError);
    });

    test('timeout and network failures are retryable', () async {
      for (final error in <Object>[
        TimeoutException('slow'),
        const SocketException('offline'),
      ]) {
        final provider = _provider(_FakeTransport([error]));
        final result = await provider.match(_request(_shortRoute()));
        expect(result.hasRetryableFailure, isTrue);
      }
    });

    test('authentication and Mapbox API failures are classified', () async {
      final auth = await _provider(
        _FakeTransport([_response(401, '{}')]),
      ).match(_request(_shortRoute()));
      final api = await _provider(
        _FakeTransport([
          _response(200, jsonEncode({'code': 'NoMatch', 'message': 'none'})),
        ]),
      ).match(_request(_shortRoute()));

      expect(auth.failureKind, RoadMatchingFailureKind.authentication);
      expect(api.failureKind, RoadMatchingFailureKind.apiError);
    });

    test('rate-limit and server failures remain retryable', () async {
      for (final status in <int>[429, 503]) {
        final result = await _provider(
          _FakeTransport([_response(status, '{}')]),
        ).match(_request(_shortRoute()));

        expect(result.hasRetryableFailure, isTrue);
      }
    });

    test('malformed response shape does not escape as an exception', () async {
      final result = await _provider(
        _FakeTransport([
          _response(
            200,
            jsonEncode({
              'code': 'Ok',
              'matchings': [
                {
                  'confidence': 0.8,
                  'geometry': {
                    'coordinates': [
                      ['not-a-number', 41],
                    ],
                  },
                },
              ],
            }),
          ),
        ]),
      ).match(_request(_shortRoute()));

      expect(result.failureKind, RoadMatchingFailureKind.malformedResponse);
      expect(result.hasUsableGeometry, isFalse);
    });

    test(
      'partial chunk success keeps only disconnected validated sections',
      () async {
        final transport = _FakeTransport([
          _response(
            200,
            _ok([
              [29.0, 41.0],
              [29.01, 41.0],
            ]),
          ),
          _response(200, jsonEncode({'code': 'NoMatch', 'matchings': []})),
        ]);
        final provider = _provider(transport);
        final route = List.generate(
          150,
          (index) => _point(41 + index * 0.00005, 29),
        );
        final result = await provider.match(_request(route));

        expect(result.status, RoadValidationStatus.partiallyValidated);
        expect(result.sections, hasLength(1));
        expect(result.failureKind, RoadMatchingFailureKind.apiError);
      },
    );

    test(
      'overlapping chunk geometry is merged without duplicate distance',
      () async {
        final firstGeometry = List.generate(
          6,
          (index) => <double>[29 + index * 0.001, 41],
        );
        final secondGeometry = <List<double>>[
          ...firstGeometry.skip(3),
          [29.006, 41],
          [29.007, 41],
        ];
        final provider = _provider(
          _FakeTransport([
            _response(200, _ok(firstGeometry)),
            _response(200, _ok(secondGeometry)),
          ]),
        );
        final result = await provider.match(
          _request(
            List.generate(150, (index) => _point(41 + index * 0.00005, 29)),
          ),
        );

        expect(result.sections, hasLength(1));
        expect(result.geometry, hasLength(8));
        expect(result.validDistanceMeters, inInclusiveRange(580, 600));
      },
    );

    test(
      'reversed geometry preserves a distinct travel direction key',
      () async {
        final forward = <List<double>>[
          [29, 41],
          [29.001, 41],
        ];
        final reverse = forward.reversed.toList();
        final forwardResult = await _provider(
          _FakeTransport([_response(200, _ok(forward))]),
        ).match(_request(_shortRoute()));
        final reverseResult = await _provider(
          _FakeTransport([_response(200, _ok(reverse))]),
        ).match(_request(_shortRoute().reversed.toList()));

        expect(forwardResult.directionKey, isNot(reverseResult.directionKey));
        expect(reverseResult.geometry.first.longitude, 29.001);
      },
    );
  });

  group('validation orchestration', () {
    test('2999 metres is rejected and 3000 metres is ready', () async {
      final rejected = await _validationForDistance(2999);
      final accepted = await _validationForDistance(3000);

      expect(
        rejected.result.state,
        WorldProcessingState.rejectedInsufficientValidDistance,
      );
      expect(
        accepted.result.state,
        WorldProcessingState.readyForWorldProcessing,
      );
      expect(accepted.result.state, isNot(WorldProcessingState.processed));
    });

    test('retryable failure keeps an idempotent pending job', () async {
      final repository = _MemoryRepository();
      final provider = _FakeRoadProvider(
        RoadMatchingResult.failure(
          kind: RoadMatchingFailureKind.network,
          message: 'offline',
        ),
      );
      final service = _validationService(repository, provider);
      final drive = _drive('retry');

      await service.validateDrive(drive);
      await service.retryValidation(drive);

      expect(repository.jobs, hasLength(1));
      expect(repository.jobs.values.single.retryCount, 2);
      expect(
        repository.jobs.values.single.status,
        WorldJobStatus.retryScheduled,
      );
      expect(repository.roads, isEmpty);
      expect(
        repository.processing['retry']?.state,
        WorldProcessingState.pendingValidation,
      );
    });

    test('current validated drive avoids a second provider call', () async {
      final repository = _MemoryRepository();
      final provider = _FakeRoadProvider(_roadResult(3200));
      final service = _validationService(repository, provider);
      final drive = _drive('cached');

      final first = await service.validateDrive(drive);
      final second = await service.validateDrive(drive);

      expect(first.providerCalled, isTrue);
      expect(second.providerCalled, isFalse);
      expect(provider.callCount, 1);
      expect(repository.roads, hasLength(1));
    });
  });

  test('World queue failure never rolls back a saved DriveSession', () async {
    final directory = await Directory.systemTemp.createTemp(
      'driveit_world_save_',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DriveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RoutePointAdapter());
    }
    try {
      await Hive.openBox<DriveSession>('drives');
      await Hive.openBox<dynamic>('career_totals');
      await Hive.openBox<dynamic>('symbolic_routes');
      await Hive.openBox<dynamic>('drive_names');

      final drive = _drive('save-survives-world-failure');
      await DriveStorageService.saveDrive(drive);

      expect(Hive.box<DriveSession>('drives').get(drive.id)?.id, drive.id);
    } finally {
      await Hive.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  });
}

RoutePoint _point(double latitude, double longitude) =>
    RoutePoint(latitude: latitude, longitude: longitude);

List<RoutePoint> _shortRoute() => [_point(41, 29), _point(41.001, 29.001)];

RoadMatchingRequest _request(List<RoutePoint> route) => RoadMatchingRequest(
  driveSessionId: 'drive-mapbox',
  rawRoute: route,
  processingVersion: MyWorldRules.validatedRoadProcessingVersion,
);

MapboxRoadMatchingProvider _provider(_FakeTransport transport) =>
    MapboxRoadMatchingProvider(
      transport: transport,
      accessToken: 'test-token',
      endpoint: Uri.parse('https://example.test/matching/v5/mapbox/driving'),
    );

String _ok(List<List<double>> geometry, {double confidence = 0.9}) =>
    jsonEncode({
      'code': 'Ok',
      'matchings': [
        {
          'confidence': confidence,
          'geometry': {'type': 'LineString', 'coordinates': geometry},
        },
      ],
    });

MapboxHttpResponse _response(int statusCode, String body) =>
    MapboxHttpResponse(statusCode: statusCode, body: body);

class _FakeTransport implements MapboxHttpTransport {
  final List<Object> responses;
  final List<Uri> uris = [];
  final List<String> bodies = [];

  _FakeTransport(this.responses);

  @override
  Future<MapboxHttpResponse> post({
    required Uri uri,
    required String formBody,
    required Duration timeout,
  }) async {
    uris.add(uri);
    bodies.add(formBody);
    final response = responses.removeAt(0);
    if (response is MapboxHttpResponse) return response;
    throw response;
  }
}

DriveSession _drive(String id) => DriveSession(
  id: id,
  date: DateTime.utc(2026, 8, 11),
  distance: 5000,
  durationSeconds: 600,
  averageSpeed: 30,
  maxSpeed: 60,
  mapImagePath: '',
  route: _shortRoute(),
);

RoadMatchingResult _roadResult(double distance) {
  const geometry = [
    MatchedRoadPoint(latitude: 41, longitude: 29, headingDegrees: 90),
    MatchedRoadPoint(latitude: 41, longitude: 29.01, headingDegrees: 90),
  ];
  final section = MatchedRoadSection(
    id: 'section',
    geometry: geometry,
    distanceMeters: distance,
    confidence: 0.9,
    sourceTraceIndex: 0,
    sourceChunkIndex: 0,
  );
  return RoadMatchingResult(
    sections: [section],
    geometry: geometry,
    validDistanceMeters: distance,
    status: RoadValidationStatus.validated,
    confidence: 0.9,
    directionKey: 'east',
    averageHeadingDegrees: 90,
    errorMessage: null,
  );
}

Future<_FakeValidation> _validationForDistance(double distance) async {
  final repository = _MemoryRepository();
  final provider = _FakeRoadProvider(_roadResult(distance));
  final result = await _validationService(
    repository,
    provider,
  ).validateDrive(_drive('distance-$distance'));
  return _FakeValidation(result);
}

MyWorldValidationService _validationService(
  _MemoryRepository repository,
  _FakeRoadProvider provider,
) => MyWorldValidationService(
  repository: repository,
  roadMatching: RoadMatchingService(
    provider: provider,
    clock: () => DateTime.utc(2026, 8, 11, 12),
  ),
  clock: () => DateTime.utc(2026, 8, 11, 12),
);

class _FakeValidation {
  final MyWorldValidationResult result;
  const _FakeValidation(this.result);
}

class _FakeRoadProvider implements RoadMatchingProvider {
  final RoadMatchingResult result;
  int callCount = 0;

  _FakeRoadProvider(this.result);

  @override
  String get providerId => 'test-provider';

  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    callCount++;
    return result;
  }
}

class _MemoryRepository implements MyWorldRepository {
  final Map<String, ValidatedRoad> roads = {};
  final Map<String, WorldDriveProcessingRecord> processing = {};
  final Map<String, WorldPendingJob> jobs = {};

  @override
  Future<bool> enqueueIfAbsent(WorldPendingJob job) async {
    final key = WorldPendingJob.idempotencyKey(job.driveSessionId, job.type);
    if (jobs.containsKey(key)) return false;
    jobs[key] = job;
    return true;
  }

  @override
  Future<WorldPendingJob?> getPendingJob(
    String driveSessionId,
    WorldJobType type,
  ) async => jobs[WorldPendingJob.idempotencyKey(driveSessionId, type)];

  @override
  Future<List<WorldPendingJob>> getPendingJobs() async => jobs.values.toList();

  @override
  Future<WorldDriveProcessingRecord?> getProcessingRecord(
    String driveSessionId,
  ) async => processing[driveSessionId];

  @override
  Future<ValidatedRoad?> getValidatedRoad(String id) async => roads[id];

  @override
  Future<List<ValidatedRoad>> getValidatedRoadsForDrive(
    String driveSessionId,
  ) async => roads.values
      .where((road) => road.driveSessionId == driveSessionId)
      .toList();

  @override
  Future<void> savePendingJob(WorldPendingJob job) async {
    jobs[WorldPendingJob.idempotencyKey(job.driveSessionId, job.type)] = job;
  }

  @override
  Future<void> saveProcessingRecord(WorldDriveProcessingRecord record) async {
    processing[record.driveSessionId] = record;
  }

  @override
  Future<void> saveValidatedRoad(ValidatedRoad road) async {
    roads[road.id] = road;
  }

  @override
  Future<void> saveValidationBundle({
    ValidatedRoad? road,
    required WorldDriveProcessingRecord processing,
    required WorldPendingJob job,
  }) async {
    if (road != null) roads[road.id] = road;
    this.processing[processing.driveSessionId] = processing;
    jobs[WorldPendingJob.idempotencyKey(job.driveSessionId, job.type)] = job;
  }
}
