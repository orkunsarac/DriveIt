import 'dart:io';

import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/world_index_mutation_plan.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/repositories/hive_my_world_index_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';

void main() {
  group('Phase 6 World index repository', () {
    late Directory directory;
    late HiveInterface hive;
    late HiveMyWorldIndexRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('driveit_world_index_');
      hive = HiveImpl()..init(directory.path);
      MyWorldHive.registerAdapters(hive);
      await MyWorldHive.openBoxes(hive);
      repository = HiveMyWorldIndexRepository(
        hive.box<WorldIndexSnapshot>(MyWorldHive.indexSnapshotsBoxName),
        hive.box<WorldIndexPointer>(MyWorldHive.indexMetadataBoxName),
      );
    });

    tearDown(() async {
      await hive.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    test('complete snapshot activates once and supports World queries', () async {
      final initial = await repository.getActiveSnapshot();
      final trace = _trace('drive-one', 0, 1200);
      await repository.commit(_plan(initial, [trace], ['drive-one']));

      final active = await repository.getActiveSnapshot();
      expect(active.generation, 1);
      expect(await repository.hasActiveTraceForDrive('drive-one'), isTrue);
      expect(await repository.activeDistanceForDrive('drive-one'), 1200);
      expect(await repository.totalWorldDistance(), 1200);
      expect(
        await repository.getActiveTracesInBounds(
          minLatitude: 40,
          maxLatitude: 42,
          minLongitude: 28,
          maxLongitude: 30,
        ),
        hasLength(1),
      );
    });

    test('a stale or invalid generation cannot replace the active snapshot', () async {
      final initial = await repository.getActiveSnapshot();
      await repository.commit(_plan(initial, [_trace('drive-one', 0, 1000)], ['drive-one']));
      final stale = _plan(initial, [_trace('drive-two', 0, 1000)], ['drive-two']);

      await expectLater(repository.commit(stale), throwsStateError);
      final active = await repository.getActiveSnapshot();
      expect(active.generation, 1);
      expect(active.traces.single.sourceDriveSessionId, 'drive-one');
    });
  });
}

WorldIndexMutationPlan _plan(
  WorldIndexSnapshot base,
  List<ActiveWorldTrace> traces,
  List<String> processed,
) {
  final snapshot = WorldIndexSnapshot(
    generation: base.generation + 1,
    operationId: 'op-${base.generation + 1}',
    traces: traces,
    processedDriveSessionIds: processed,
    driveScoreAlgorithmVersion: 1,
    validatedRoadProcessingVersion: 2,
    createdAt: DateTime.utc(2026, 8, 12),
  );
  return WorldIndexMutationPlan(
    operationId: snapshot.operationId,
    sourceDriveSessionId: processed.single,
    baseGeneration: base.generation,
    tracesToRemove: const [],
    tracesToCreate: traces,
    resultingSnapshot: snapshot,
  );
}

ActiveWorldTrace _trace(String driveId, double start, double end) => ActiveWorldTrace(
  id: '$driveId:$start:$end',
  sourceDriveSessionId: driveId,
  validatedRoadId: '$driveId:road',
  matchedSectionId: '$driveId:section',
  startOffsetMeters: start,
  endOffsetMeters: end,
  directionKey: 'eastbound',
  minLatitude: 41,
  maxLatitude: 41.1,
  minLongitude: 29,
  maxLongitude: 29.1,
  createdAt: DateTime.utc(2026, 8, 12),
  updatedAt: DateTime.utc(2026, 8, 12),
  processingVersion: 2,
);
