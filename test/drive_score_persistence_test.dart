import 'dart:io';

import 'package:driveit_project/features/drive_score/models/drive_score_result.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_calculator.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_persistence_coordinator.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/drive_storage_service.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('driveit_score_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DriveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RoutePointAdapter());
    }
    DriveTelemetryHive.registerAdapters(Hive);
    DriveScoreHive.registerAdapters(Hive);
    await Hive.openBox<DriveSession>('drives');
    await Hive.openBox<dynamic>('career_totals');
    await Hive.openBox<dynamic>('symbolic_routes');
    await Hive.openBox<dynamic>('drive_names');
    await DriveTelemetryHive.openBox(Hive);
    await DriveScoreHive.openBox(Hive);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  DriveScoreRecord record({double total = 750}) {
    final categories = <DriveScoreCategoryRecord>[
      const DriveScoreCategoryRecord(
        categoryKey: 'brakingAnticipation',
        rawScore: 300,
        maximum: 350,
        applicable: true,
        sampleSufficient: true,
        contributionUsed: 300,
        contributionSource: DriveScoreContributionSource.actual,
      ),
      const DriveScoreCategoryRecord(
        categoryKey: 'tempoPerformance',
        rawScore: 0,
        maximum: 150,
        applicable: false,
        sampleSufficient: false,
        contributionUsed: 112.5,
        contributionSource:
            DriveScoreContributionSource.neutralNotApplicable,
      ),
      const DriveScoreCategoryRecord(
        categoryKey: 'corneringPerformance',
        rawScore: 0,
        maximum: 150,
        applicable: true,
        sampleSufficient: false,
        contributionUsed: 112.5,
        contributionSource:
            DriveScoreContributionSource.neutralInsufficient,
      ),
    ];
    return DriveScoreRecord(
      driveId: 'drive-1',
      algorithmVersion: 1,
      telemetryDataVersion: 1,
      calculatedAt: DateTime(2026, 8, 12),
      totalScore: total,
      overallConfidence: 1 / 3,
      categories: categories,
    );
  }

  List<CanonicalTelemetryPoint> telemetry() {
    final startedAt = DateTime(2026, 8, 12, 12);
    return List.generate(
      5,
      (index) => CanonicalTelemetryPoint(
        latitude: 41 + index * .0001,
        longitude: 29,
        timestamp: startedAt.add(Duration(seconds: index * 5)),
        speedMps: 12,
        headingDegrees: 90,
        altitudeMeters: 0,
        accuracyMeters: 4,
        distanceFromPreviousMeters: index == 0 ? 0 : 11,
        accelerationMps2: 0,
      ),
    );
  }

  DriveSession drive(String id) => DriveSession(
    id: id,
    date: DateTime(2026, 8, 12),
    distance: 44,
    durationSeconds: 20,
    averageSpeed: 43,
    maxSpeed: 43,
    mapImagePath: '',
    route: [
      RoutePoint(latitude: 41, longitude: 29),
      RoutePoint(latitude: 41.0004, longitude: 29),
    ],
  );

  test('score record preserves actual and neutral contribution sources', () async {
    final value = record(total: 525);
    await DriveScoreStorageService.save(value);

    final restored = DriveScoreStorageService.get(driveId: 'drive-1');
    expect(restored?.algorithmVersion, 1);
    expect(restored?.telemetryDataVersion, 1);
    expect(restored?.calculatedAt, DateTime(2026, 8, 12));
    expect(restored?.totalScore, 525);
    expect(restored?.categories, hasLength(3));
    expect(
      restored?.categories[0].contributionSource,
      DriveScoreContributionSource.actual,
    );
    expect(
      restored?.categories[1].contributionSource,
      DriveScoreContributionSource.neutralNotApplicable,
    );
    expect(
      restored?.categories[2].contributionSource,
      DriveScoreContributionSource.neutralInsufficient,
    );
  });

  test('deterministic key overwrites instead of creating a duplicate v1 score',
      () async {
    await DriveScoreStorageService.save(record(total: 525));
    await DriveScoreStorageService.save(record(total: 525));

    final box = Hive.box<DriveScoreRecord>(DriveScoreHive.boxName);
    expect(box.length, 1);
    expect(box.get('drive-1:v1')?.totalScore, 525);
  });

  test('missing canonical telemetry does not create a score record', () async {
    final result = await const DriveScorePersistenceCoordinator()
        .calculateAndPersistForDrive('legacy-drive');

    expect(result, isNull);
    expect(DriveScoreStorageService.exists(driveId: 'legacy-drive'), isFalse);
  });

  test('in-memory calculator scores local telemetry without Hive persistence',
      () {
    const calculator = DriveScoreCalculator();
    final box = Hive.box<DriveScoreRecord>(DriveScoreHive.boxName);
    final result = calculator.calculate(
      telemetry: telemetry(),
      algorithmVersion: DriveScoreAlgorithmVersion.v1,
    );

    expect(result.algorithmVersion, 1);
    expect(result.totalScore, inInclusiveRange(0, 1000));
    expect(box.length, 0);
  });

  test('calculator is deterministic for a local telemetry subset', () {
    const calculator = DriveScoreCalculator();
    final subset = telemetry().sublist(1);

    final first = calculator.calculate(telemetry: subset);
    final second = calculator.calculate(telemetry: subset);

    expect(first.totalScore, second.totalScore);
    expect(first.overallConfidence, second.overallConfidence);
    expect(first.categories.keys, orderedEquals(second.categories.keys));
  });

  test('unsupported algorithm version is rejected explicitly', () {
    const calculator = DriveScoreCalculator();

    expect(
      () => calculator.calculateForVersion(
        telemetry: telemetry(),
        algorithmVersion: 2,
      ),
      throwsA(isA<UnsupportedDriveScoreAlgorithmVersion>()),
    );
  });

  test('calculator rejects insufficient telemetry without a fabricated score',
      () {
    const calculator = DriveScoreCalculator();

    expect(
      () => calculator.calculate(telemetry: telemetry().take(1)),
      throwsA(isA<InsufficientDriveScoreTelemetryException>()),
    );
  });

  test('invalid non-finite score record is rejected before persistence', () async {
    final invalid = DriveScoreRecord(
      driveId: 'invalid',
      algorithmVersion: 1,
      telemetryDataVersion: 1,
      calculatedAt: DateTime.now(),
      totalScore: double.nan,
      overallConfidence: 1,
      categories: const [],
    );

    await expectLater(
      DriveScoreStorageService.save(invalid),
      throwsArgumentError,
    );
    expect(DriveScoreStorageService.exists(driveId: 'invalid'), isFalse);
  });

  test('score persistence failure does not remove a saved DriveSession',
      () async {
    await Hive.box<DriveScoreRecord>(DriveScoreHive.boxName).close();
    final savedDrive = drive('saved-despite-score-failure');

    await DriveStorageService.saveDrive(savedDrive);

    expect(
      Hive.box<DriveSession>('drives').get(savedDrive.id)?.id,
      savedDrive.id,
    );
  });

  test('new saved drive persists telemetry then a v1 score record', () async {
    final savedDrive = drive('new-drive');
    await DriveStorageService.saveDrive(
      savedDrive,
      telemetry: telemetry(),
    );

    expect(Hive.box<DriveSession>('drives').get(savedDrive.id), isNotNull);
    expect(DriveTelemetryStorageService.get(savedDrive.id), isNotNull);
    expect(DriveScoreStorageService.get(driveId: savedDrive.id), isNotNull);
  });

  test('coordinator persists the same v1 result as the calculator', () async {
    const id = 'coordinator-calculator-parity';
    final points = telemetry();
    await DriveTelemetryStorageService.save(
      driveSessionId: id,
      points: points,
    );

    const calculator = DriveScoreCalculator();
    final expected = calculator.calculate(telemetry: points);
    final persisted = await const DriveScorePersistenceCoordinator()
        .calculateAndPersistForDrive(id);

    expect(persisted?.totalScore, expected.totalScore);
    expect(persisted?.algorithmVersion, expected.algorithmVersion);
  });

  test('missing score with telemetry recovers once without duplicates', () async {
    const id = 'recoverable-drive';
    await DriveTelemetryStorageService.save(
      driveSessionId: id,
      points: telemetry(),
    );

    final coordinator = const DriveScorePersistenceCoordinator();
    final first = await coordinator.calculateAndPersistForDrive(id);
    final second = await coordinator.calculateAndPersistForDrive(id);

    expect(first, isNotNull);
    expect(second?.totalScore, first?.totalScore);
    expect(Hive.box<DriveScoreRecord>(DriveScoreHive.boxName).length, 1);
  });

  test('persisted score survives box reopen and drive deletion cleans it up',
      () async {
    const id = 'restart-and-delete';
    await DriveScoreStorageService.save(
      DriveScoreRecord(
        driveId: id,
        algorithmVersion: 1,
        telemetryDataVersion: 1,
        calculatedAt: DateTime(2026, 8, 12),
        totalScore: 525,
        overallConfidence: 1 / 3,
        categories: record(total: 525).categories,
      ),
    );
    await DriveTelemetryStorageService.save(
      driveSessionId: id,
      points: telemetry(),
    );
    await Hive.box<DriveSession>('drives').put(id, drive(id));

    await Hive.box<DriveScoreRecord>(DriveScoreHive.boxName).close();
    await DriveScoreHive.openBox(Hive);
    expect(DriveScoreStorageService.get(driveId: id)?.totalScore, 525);

    await DriveStorageService.deleteDrive(id);
    expect(Hive.box<DriveSession>('drives').get(id), isNull);
    expect(DriveTelemetryStorageService.get(id), isNull);
    expect(DriveScoreStorageService.get(driveId: id), isNull);
  });
}
