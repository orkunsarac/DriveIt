import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/local_data_preparation_service.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/services/career_statistics_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';
import 'package:driveit_project/features/my_world/services/world_trace_detail_service.dart';

final date = DateTime.utc(2026, 1, 1);
LocalSourceBundle fixture(String id, {bool telemetry = true}) {
  final drive = DriveSession(
    id: id,
    date: date,
    distance: 6000,
    durationSeconds: 180,
    averageSpeed: 120,
    maxSpeed: 130,
    mapImagePath: 'old-unavailable.png',
    route: [
      RoutePoint(latitude: 40, longitude: 29),
      RoutePoint(latitude: 40.01, longitude: 29, breakBefore: true),
    ],
    stopCount: 2,
    stoppedSeconds: 10,
    hardBrakeCount: 3,
    hardAccelerationCount: 4,
    sharpTurnCount: 1,
    maxAccelerationG: .2,
    maxBrakingG: .3,
    cornerCount: 2,
    maxCorneringSpeed: 30,
    maxAltitude: 50,
    altitudeGain: 10,
    altitudeLoss: 5,
    bestZeroToHundredSeconds: 12,
    bestSixtyToHundredSeconds: 6,
  );
  final road = ValidatedRoad(
    id: '$id:road',
    driveSessionId: id,
    geometry: const [
      MatchedRoadPoint(latitude: 40, longitude: 29),
      MatchedRoadPoint(latitude: 40.01, longitude: 29),
    ],
    sections: [
      MatchedRoadSection(
        id: '$id:section',
        geometry: const [
          MatchedRoadPoint(latitude: 40, longitude: 29),
          MatchedRoadPoint(latitude: 40.01, longitude: 29),
        ],
        distanceMeters: 6000,
        confidence: .9,
        sourceTraceIndex: 1,
        sourceChunkIndex: 0,
      ),
    ],
    validDistanceMeters: 6000,
    status: RoadValidationStatus.partiallyValidated,
    validatedAt: date,
    providerId: 'synthetic',
    confidence: .9,
    processingVersion: 2,
    directionKey: 'forward',
    averageHeadingDegrees: 0,
    createdAt: date,
    updatedAt: date,
  );
  return LocalSourceBundle(
    drive: drive,
    roads: [road],
    score: DriveScoreRecord(
      driveId: id,
      algorithmVersion: 1,
      telemetryDataVersion: 1,
      calculatedAt: date,
      totalScore: 700,
      overallConfidence: .9,
      categories: const [],
    ),
    telemetry: !telemetry
        ? null
        : DriveTelemetryRecord(
            driveSessionId: id,
            dataVersion: 1,
            createdAt: date,
            points: [
              for (var i = 0; i <= 36; i++)
                CanonicalTelemetryPoint(
                  latitude: 40 + i * .0001,
                  longitude: 29,
                  timestamp: date.add(
                    Duration(seconds: i * 5, microseconds: 123),
                  ),
                  speedMps: 10,
                  headingDegrees: 0,
                  altitudeMeters: 10,
                  accuracyMeters: 4,
                  distanceFromPreviousMeters: i == 0 ? 0 : 50,
                  accelerationMps2: 0,
                  speedSource: 'native',
                  accelerationReliable: true,
                ),
            ],
            acquisitionMetadata: {
              'startedAtMicros': date.microsecondsSinceEpoch + 123,
              'stopRequestedAtMicros': date.microsecondsSinceEpoch + 180000123,
            },
          ),
  );
}

Map<String, dynamic> totals(List<LocalSourceBundle> sources) => {
  'totalDistance': sources.fold<double>(0, (s, b) => s + b.drive.distance),
  'totalDuration': sources.fold<int>(0, (s, b) => s + b.drive.durationSeconds),
  'countedIds': sources.map((s) => s.drive.id).toList(),
};
Map<String, dynamic> metrics(CareerStatistics s) => {
  'ids': s.drives.map((d) => d.id).toList(),
  'distance': s.totalDistanceMeters,
  'duration': s.totalDurationSeconds,
  'moving': s.totalMovingSeconds,
  'count': s.scoredDriveCount,
  'avgDistance': s.averageDistanceMeters,
  'avgDuration': s.averageDurationSeconds,
  'max': s.maxSpeedDrive?.maxSpeed,
  'longest': s.longestDrive?.distance,
  'longestDuration': s.longestDurationDrive?.durationSeconds,
  'best': s.bestScore?.totalScore,
  'average': s.averageScore,
  'recent': s.recentAverageScore,
  'g': s.maxAccelerationDrive?.maxAccelerationG,
  'brake': s.strongestBrakingDrive?.maxBrakingG,
  'zero100': s.bestZeroToHundredDrive?.bestZeroToHundredSeconds,
  'stops': s.totalStops,
  'brakes': s.totalBrakingEvents,
  'corners': s.totalCorners,
  'speed': s.lifetimeAverageSpeedKmh,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WorldSourceSnapshotRepository world;
  late CareerContributionRepository career;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('driveit_foundation_');
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DriveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RoutePointAdapter());
    DriveTelemetryHive.registerAdapters(Hive);
    DriveScoreHive.registerAdapters(Hive);
    MyWorldHive.registerAdapters(Hive);
    await Hive.openBox<DriveSession>('drives');
    await Hive.openBox<dynamic>('career_totals');
    await Hive.openBox<dynamic>('symbolic_routes');
    await Hive.openBox<dynamic>('drive_names');
    await DriveTelemetryHive.openBox(Hive);
    await DriveScoreHive.openBox(Hive);
    await WorldSourceSnapshotRepository.open(Hive);
    await CareerContributionRepository.open(Hive);
    world = WorldSourceSnapshotRepository(
      Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
    );
    career = CareerContributionRepository(
      Hive.box<dynamic>(CareerContributionRepository.boxName),
    );
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'legacy source exact roundtrip; independent detail/geometry; source and index unchanged',
    () async {
      final b = fixture('old');
      await Hive.box<DriveSession>('drives').put(b.drive.id, b.drive);
      await MyWorldHive.openBoxes(Hive);
      final index = WorldIndexSnapshot.empty(
        driveScoreAlgorithmVersion: 1,
        validatedRoadProcessingVersion: 6,
      );
      await Hive.box<WorldIndexSnapshot>(
        MyWorldHive.indexSnapshotsBoxName,
      ).put('0', index);
      final before = jsonEncode(driveTransferManifest(b.drive));
      await world.prepare(b);
      await Hive.close();
      await WorldSourceSnapshotRepository.open(Hive);
      world = WorldSourceSnapshotRepository(
        Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
      );
      final restored = world.get('old')!;
      expect(jsonEncode(restored.toMap()), jsonEncode(b.toMap()));
      expect(restored.telemetry!.points.last.timestamp.microsecond, 123);
      await Hive.openBox<DriveSession>('drives');
      expect(
        jsonEncode(
          driveTransferManifest(Hive.box<DriveSession>('drives').get('old')!),
        ),
        before,
      );
      await Hive.box<DriveSession>(
        'drives',
      ).delete('old'); // isolated synthetic fixture only
      final detail = await WorldTraceDetailService(
        driveLoader: (id) => world.get(id)?.drive,
        scoreLoader: (id) => world.get(id)?.score,
        activeDistanceLoader: (_) async => 6000,
      ).load('old');
      expect(detail!.drive.id, 'old');
      expect(detail.score!.totalScore, 700);
      expect(restored.drive.route.last.breakBefore, true);
      expect(restored.roads.single.sections.single.sourceTraceIndex, 1);
      await Hive.openBox<WorldIndexSnapshot>(MyWorldHive.indexSnapshotsBoxName);
      expect(
        Hive.box<WorldIndexSnapshot>(
          MyWorldHive.indexSnapshotsBoxName,
        ).get('0')!.generation,
        0,
      );
    },
  );
  test(
    'interrupted staging resumes; concurrent duplicate has one ready snapshot',
    () async {
      final b = fixture('resume');
      await expectLater(
        world.prepare(
          b,
          afterStage: () async => throw StateError('synthetic interruption'),
        ),
        throwsStateError,
      );
      expect(world.get('resume'), isNull);
      await Future.wait([world.prepare(b), world.prepare(b)]);
      expect(world.getAll(), hasLength(1));
    },
  );
  test(
    'real process exits after flushed staging; reopen promotes exact source once',
    () async {
      final b = fixture('crash');
      final input = File('${root.path}/source.json');
      await input.writeAsString(jsonEncode(b.toMap()));
      await Hive.close();
      var folder = File(Platform.resolvedExecutable).parent;
      String? dart;
      for (var i = 0; i < 8; i++) {
        final candidate =
            '${folder.path}/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
        if (File(candidate).existsSync()) {
          dart = candidate;
          break;
        }
        folder = folder.parent;
      }
      expect(dart, isNotNull);
      final result = await Process.run(dart!, [
        'run',
        'test/support/world_snapshot_crash_probe.dart',
        root.path,
        input.path,
      ]);
      expect(result.exitCode, 73, reason: '${result.stderr}');
      await WorldSourceSnapshotRepository.open(Hive);
      world = WorldSourceSnapshotRepository(
        Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
      );
      expect(world.get('crash'), isNull);
      await world.prepare(b);
      expect(jsonEncode(world.get('crash')!.toMap()), jsonEncode(b.toMap()));
      expect(world.getAll(), hasLength(1));
    },
  );
  test('unknown legacy telemetry is absent, not fabricated', () async {
    final b = fixture('no-telemetry', telemetry: false);
    await world.prepare(b);
    expect(world.get(b.drive.id)!.telemetry, isNull);
    expect(world.get(b.drive.id)!.drive.date, date);
  });
  test(
    'explicit old preparation reads real source and never invents missing drives',
    () async {
      final b = fixture('explicit', telemetry: false);
      await Hive.box<DriveSession>('drives').put(b.drive.id, b.drive);
      final oldTotals = Hive.box<dynamic>('career_totals');
      await oldTotals.putAll({
        'initialized': true,
        ...totals([b]),
      });
      final original = jsonEncode(oldTotals.toMap());
      expect(
        await LocalDataPreparationService.prepareWorldSource('missing'),
        false,
      );
      expect(world.getAll(), isEmpty);
      expect(
        await LocalDataPreparationService.prepareWorldSource('explicit'),
        true,
      );
      expect(await LocalDataPreparationService.prepareLegacyCareer(), true);
      expect(jsonEncode(oldTotals.toMap()), original);
      expect(world.get('explicit')!.telemetry, isNull);
      expect(career.statistics()!.totalDistanceMeters, 6000);
    },
  );
  test(
    'invalid identity/geometry cannot promote; old ready payload retained',
    () async {
      final b = fixture('valid');
      await world.prepare(b);
      final wrong = LocalSourceBundle(
        drive: fixture('wrong').drive,
        roads: b.roads,
      );
      await expectLater(world.prepare(wrong), throwsStateError);
      expect(world.get('valid')!.drive.id, 'valid');
      expect(world.get('wrong'), isNull);
      final changed = fixture('valid');
      changed.drive.distance = 1;
      await expectLater(world.prepare(changed), throwsStateError);
      expect(world.get('valid')!.drive.distance, 6000);
    },
  );
  test(
    'validation attaches only existing source and survives repeated save preparation',
    () async {
      final b = fixture('new');
      final source = LocalSourceBundle(
        drive: b.drive,
        telemetry: b.telemetry,
        score: b.score,
      );
      await world.prepare(source);
      await world.attachRoad(b.roads.single);
      await world.attachRoad(b.roads.single);
      await world.prepare(source);
      expect(world.get('new')!.roads, hasLength(1));
      await world.attachRoad(fixture('absent').roads.single);
      expect(world.get('absent'), isNull);
    },
  );
  test(
    'provider retry keeps previous validation revision and canonical source',
    () async {
      final b = fixture('revision');
      await world.prepare(b);
      final original = b.roads.single;
      final updated = ValidatedRoad(
        id: original.id,
        driveSessionId: original.driveSessionId,
        geometry: original.geometry,
        sections: original.sections,
        validDistanceMeters: 6100,
        status: RoadValidationStatus.validated,
        validatedAt: date,
        providerId: original.providerId,
        confidence: 1,
        processingVersion: original.processingVersion,
        directionKey: original.directionKey,
        averageHeadingDegrees: original.averageHeadingDegrees,
        createdAt: date,
        updatedAt: date,
      );
      await world.attachRoad(updated);
      await world.attachRoad(updated);
      expect(world.get('revision')!.roads.single.validDistanceMeters, 6100);
      expect(world.get('revision')!.drive.distance, 6000);
      expect(
        (world.box.get('revision') as Map)['validationHistory'],
        hasLength(1),
      );
    },
  );
  test(
    'career all existing metrics preserved after isolated source deletion and reopen',
    () async {
      final sources = [
        fixture('a', telemetry: false),
        fixture('b', telemetry: false),
      ];
      final prior = const CareerStatisticsService().calculate(
        drives: sources.map((b) => b.drive).toList(),
        scoreLoader: (id) => sources.firstWhere((b) => b.drive.id == id).score,
      );
      expect(
        await career.prepareLegacy(sources: sources, totals: totals(sources)),
        true,
      );
      final first = metrics(career.statistics()!);
      expect(first, metrics(prior));
      await Future.wait([career.add(sources.first), career.add(sources.first)]);
      await Hive.box<DriveSession>(
        'drives',
      ).clear(); // synthetic, empty fixture
      await Hive.close();
      await CareerContributionRepository.open(Hive);
      career = CareerContributionRepository(
        Hive.box<dynamic>(CareerContributionRepository.boxName),
      );
      expect(metrics(career.statistics()!), first);
      expect(
        career.box.keys.where((k) => k.toString().startsWith('drive:')),
        hasLength(2),
      );
    },
  );
  test(
    'measured time/motion/distance used; original metrics preserved in receipt',
    () async {
      expect(
        await career.prepareLegacy(sources: const [], totals: totals([])),
        true,
      );
      final b = fixture('timed');
      await career.add(b);
      final stats = career.statistics()!;
      expect(stats.totalDistanceMeters, 1800);
      expect(stats.totalDurationSeconds, 180);
      expect(stats.totalMovingSeconds, 180);
      expect(b.drive.distance, 6000);
      expect(
        (jsonDecode(career.box.get('drive:timed'))
            as Map)['bundle']['drive']['distance'],
        6000,
      );
    },
  );
  test(
    'legacy reliable metadata does not lower already counted totals',
    () async {
      final b = fixture('historical-timed');
      expect(
        await career.prepareLegacy(sources: [b], totals: totals([b])),
        true,
      );
      expect(career.statistics()!.totalDistanceMeters, 6000);
      await career.add(b);
      expect(career.statistics()!.totalDistanceMeters, 6000);
    },
  );
  test(
    'mixed accounting baseline stays inactive rather than lowering Career',
    () async {
      final b = fixture('previously-captured');
      await career.add(b);
      expect(
        await career.prepareLegacy(sources: [b], totals: totals([b])),
        false,
      );
      expect(career.statistics(), isNull);
    },
  );
  test(
    'missing counted legacy source preserves baseline and blocks activation',
    () async {
      final legacy = {
        'countedIds': ['deleted'],
        'totalDistance': 9000.0,
        'totalDuration': 300,
      };
      expect(
        await career.prepareLegacy(sources: const [], totals: legacy),
        false,
      );
      expect(career.statistics(), isNull);
      expect(
        jsonDecode((career.box.get('baseline') as Map)['payload']),
        legacy,
      );
    },
  );
  test(
    'ambiguous old totals do not switch; contribution conflict never overwrites',
    () async {
      final b = fixture('x', telemetry: false);
      expect(
        await career.prepareLegacy(
          sources: [b],
          totals: {
            ...totals([b]),
            'totalDistance': 1,
          },
        ),
        false,
      );
      await career.add(b);
      final changed = fixture('x', telemetry: false);
      changed.drive.maxSpeed = 999;
      await expectLater(career.add(changed), throwsStateError);
      expect(career.statistics(), isNull);
    },
  );
  test(
    'career partial preparation retries without double contribution',
    () async {
      final b = fixture('retry', telemetry: false);
      await expectLater(
        career.prepareLegacy(
          sources: [b],
          totals: totals([b]),
          afterContributions: () async =>
              throw StateError('synthetic interruption'),
        ),
        throwsStateError,
      );
      expect(career.statistics(), isNull);
      expect(
        await career.prepareLegacy(sources: [b], totals: totals([b])),
        true,
      );
      expect(career.statistics()!.drives, hasLength(1));
    },
  );
  test(
    'late score attaches once without replacing source or career metrics',
    () async {
      final b = fixture('late-score', telemetry: false);
      final pending = LocalSourceBundle(drive: b.drive, roads: b.roads);
      expect(
        await career.prepareLegacy(
          sources: [pending],
          totals: totals([pending]),
        ),
        true,
      );
      await world.prepare(pending);
      await career.add(b);
      await career.add(b);
      await world.prepare(b);
      await world.prepare(b);
      expect(world.get('late-score')!.score!.totalScore, 700);
      expect(career.statistics()!.drives, hasLength(1));
      expect(career.statistics()!.bestScore!.totalScore, 700);
      expect(career.statistics()!.totalDistanceMeters, 6000);
    },
  );
  test(
    'new save replay captures one independent source and one career contribution',
    () async {
      final b = fixture('save', telemetry: false);
      await DriveStorageService.saveDrive(b.drive);
      await DriveStorageService.saveDrive(b.drive);
      expect(world.getAll(), hasLength(1));
      expect(
        career.box.keys.where((k) => k.toString().startsWith('drive:')),
        hasLength(1),
      );
      expect(DriveStorageService.getCareerDistance(), 6000);
      expect(
        career.legacyReady,
        true,
      ); // Phase 3B: a genuinely empty baseline activates on explicit save.
    },
  );
}
