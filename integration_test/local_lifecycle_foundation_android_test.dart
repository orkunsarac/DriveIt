import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android additive stores reopen and interrupted preparation recovers',
    (_) async {
      final root = await Directory(
        '${await getDatabasesPath()}/foundation_${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      Hive.init(root.path);
      final source = LocalSourceBundle(
        drive: DriveSession(
          id: 'synthetic-native',
          date: DateTime.utc(2026),
          distance: 6000,
          durationSeconds: 100,
          averageSpeed: 30,
          maxSpeed: 40,
          mapImagePath: '',
          route: const [],
        ),
      );
      await WorldSourceSnapshotRepository.open(Hive);
      await CareerContributionRepository.open(Hive);
      var world = WorldSourceSnapshotRepository(
        Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
      );
      var career = CareerContributionRepository(
        Hive.box<dynamic>(CareerContributionRepository.boxName),
      );
      try {
        await expectLater(
          world.prepare(
            source,
            afterStage: () async => throw StateError('synthetic interruption'),
          ),
          throwsStateError,
        );
        expect(world.get(source.drive.id), isNull);
        await career.prepareLegacy(
          sources: const [],
          totals: {'countedIds': [], 'totalDistance': 0.0, 'totalDuration': 0},
        );
        await career.add(source);
        await Hive.close();
        await WorldSourceSnapshotRepository.open(Hive);
        await CareerContributionRepository.open(Hive);
        world = WorldSourceSnapshotRepository(
          Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
        );
        career = CareerContributionRepository(
          Hive.box<dynamic>(CareerContributionRepository.boxName),
        );
        await world.prepare(source);
        await career.add(source);
        expect(world.get(source.drive.id)!.drive.distance, 6000);
        expect(career.statistics()!.drives, hasLength(1));
        expect(career.statistics()!.totalDistanceMeters, 6000);
      } finally {
        await Hive.close();
        await root.delete(
          recursive: true,
        ); // uniquely named synthetic test directory only
      }
    },
  );
}
