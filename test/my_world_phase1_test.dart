import 'dart:io';

import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_pending_job.dart';
import 'package:driveit_project/features/my_world/models/world_processing.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/repositories/hive_my_world_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';

void main() {
  group('Benim Dunyam Phase 1', () {
    late Directory directory;
    late HiveInterface hive;
    late HiveMyWorldRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('driveit_my_world_');
      hive = HiveImpl()..init(directory.path);
      MyWorldHive.registerAdapters(hive);
      await MyWorldHive.openBoxes(hive);
      repository = HiveMyWorldRepository(
        hive.box<ValidatedRoad>(MyWorldHive.validatedRoadsBoxName),
        hive.box<WorldDriveProcessingRecord>(MyWorldHive.processingBoxName),
        hive.box<WorldPendingJob>(MyWorldHive.pendingJobsBoxName),
      );
    });

    tearDown(() async {
      await hive.close();
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });

    test('minimum valid World distance is exactly 5 km', () {
      expect(MyWorldRules.minimumValidDistanceMeters, 5000);
    });

    test(
      'validated road round-trip preserves DriveSession reference',
      () async {
        final now = DateTime.utc(2026, 8, 11, 9, 30);
        final road = ValidatedRoad(
          id: 'drive-42:provider:v1',
          driveSessionId: 'drive-42',
          geometry: const [
            MatchedRoadPoint(
              latitude: 41.012,
              longitude: 28.976,
              headingDegrees: 92,
              providerRoadReference: 'road-a',
              confidence: 0.96,
            ),
            MatchedRoadPoint(
              latitude: 41.013,
              longitude: 28.978,
              headingDegrees: 94,
              providerRoadReference: 'road-a',
              confidence: 0.95,
            ),
          ],
          sections: const [
            MatchedRoadSection(
              id: 'section-0',
              geometry: [
                MatchedRoadPoint(
                  latitude: 41.012,
                  longitude: 28.976,
                  headingDegrees: 92,
                  providerRoadReference: 'road-a',
                  confidence: 0.96,
                ),
                MatchedRoadPoint(
                  latitude: 41.013,
                  longitude: 28.978,
                  headingDegrees: 94,
                  providerRoadReference: 'road-a',
                  confidence: 0.95,
                ),
              ],
              distanceMeters: 3210,
              confidence: 0.95,
              sourceTraceIndex: 0,
              sourceChunkIndex: 0,
            ),
          ],
          validDistanceMeters: 3210,
          status: RoadValidationStatus.validated,
          validatedAt: now,
          providerId: 'provider',
          confidence: 0.95,
          processingVersion: 1,
          directionKey: 'road-a:eastbound',
          averageHeadingDegrees: 93,
          createdAt: now,
          updatedAt: now,
        );

        await repository.saveValidatedRoad(road);
        final stored = await repository.getValidatedRoad(road.id);

        expect(stored, isNotNull);
        expect(stored!.driveSessionId, 'drive-42');
        expect(stored.status, RoadValidationStatus.validated);
        expect(stored.directionKey, 'road-a:eastbound');
        expect(stored.geometry, hasLength(2));
        expect(stored.sections, hasLength(1));
        expect(stored.sections.single.sourceChunkIndex, 0);
        expect(stored.geometry.last.headingDegrees, 94);
      },
    );

    test('processing state serializes and deserializes', () async {
      final record = WorldDriveProcessingRecord(
        driveSessionId: 'drive-state',
        state: WorldProcessingState.readyForWorldProcessing,
        validatedRoadId: 'validated-road',
        lastError: null,
        updatedAt: DateTime.utc(2026, 8, 11),
      );

      await repository.saveProcessingRecord(record);
      final stored = await repository.getProcessingRecord('drive-state');

      expect(stored?.state, WorldProcessingState.readyForWorldProcessing);
      expect(stored?.validatedRoadId, 'validated-road');
      expect(stored?.driveSessionId, 'drive-state');
    });

    test('pending job round-trip preserves retry metadata', () async {
      final now = DateTime.utc(2026, 8, 11);
      final job = WorldPendingJob(
        id: WorldPendingJob.idempotencyKey(
          'drive-retry',
          WorldJobType.validateRoad,
        ),
        driveSessionId: 'drive-retry',
        type: WorldJobType.validateRoad,
        status: WorldJobStatus.retryScheduled,
        retryCount: 2,
        lastError: 'offline',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 2)),
      );

      expect(await repository.enqueueIfAbsent(job), isTrue);
      final jobs = await repository.getPendingJobs();

      expect(jobs, hasLength(1));
      expect(jobs.single.driveSessionId, 'drive-retry');
      expect(jobs.single.retryCount, 2);
      expect(jobs.single.lastError, 'offline');
    });

    test('same drive and job type cannot be enqueued twice', () async {
      final now = DateTime.utc(2026, 8, 11);
      final first = WorldPendingJob.pending(
        driveSessionId: 'drive-idempotent',
        type: WorldJobType.validateRoad,
        now: now,
      );
      final duplicate = WorldPendingJob(
        id: 'caller-provided-id-is-not-used-as-the-storage-key',
        driveSessionId: 'drive-idempotent',
        type: WorldJobType.validateRoad,
        status: WorldJobStatus.pending,
        retryCount: 0,
        lastError: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(await repository.enqueueIfAbsent(first), isTrue);
      expect(await repository.enqueueIfAbsent(duplicate), isFalse);
      expect(await repository.getPendingJobs(), hasLength(1));
    });
  });
}
