import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/legacy_owner_preparation.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';
import 'local_lifecycle_foundation_test.dart' as synthetic;

void main() {
  late Directory root;
  late HiveImpl old;
  late OwnerScopedLocalStore target;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('legacy_full_synthetic_');
    final dir = await Directory('${root.path}/old').create();
    old = HiveImpl()..init(dir.path);
    OwnerScopedLocalStore.register(old);
    await old.openBox<DriveSession>('drives');
    await DriveTelemetryHive.openBox(old);
    await DriveScoreHive.openBox(old);
    await MyWorldHive.openBoxes(old);
    for (final group in OwnerScopedLocalStore.groups) {
      if (!old.isBoxOpen(group)) {
        await old.openBox<dynamic>(group);
      }
    }
    target = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: const GpsOwner.legacy(),
    );
    final source = synthetic.fixture('old');
    // Real legacy reserved field data must survive cloning, not just new flags.
    source.drive.route.add(
      RoutePoint(
        latitude: 40.02,
        longitude: 29,
        legacyHiveFields: {
          2: DateTime.utc(2025, 9, 28),
          7: 'unknown legacy metadata',
        },
      ),
    );
    await old.box<DriveSession>('drives').put('old', source.drive);
    await old
        .box<DriveTelemetryRecord>('drive_telemetry')
        .put('old', source.telemetry!);
    await old
        .box<DriveScoreRecord>('drive_scores')
        .put('old:v1', source.score!);
    await old
        .box<ValidatedRoad>('my_world_validated_roads')
        .put(source.roads.single.id, source.roads.single);
    await CareerContributionRepository(
      old.box<dynamic>('career_contributions_v1'),
    ).prepareLegacy(sources: [source], totals: synthetic.totals([source]));
    await WorldSourceSnapshotRepository(
      old.box<dynamic>('my_world_source_snapshots_v1'),
    ).prepare(source);
    final trace = ActiveWorldTrace(
      id: 'synthetic-trace',
      sourceDriveSessionId: 'old',
      validatedRoadId: source.roads.single.id,
      matchedSectionId: source.roads.single.sections.single.id,
      startOffsetMeters: 0,
      endOffsetMeters: 6000,
      directionKey: 'forward',
      minLatitude: 40,
      maxLatitude: 40.02,
      minLongitude: 29,
      maxLongitude: 29,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      processingVersion: 2,
    );
    await old
        .box<WorldIndexSnapshot>('my_world_index_snapshots')
        .put(
          1,
          WorldIndexSnapshot(
            generation: 1,
            operationId: 'synthetic',
            traces: [trace],
            processedDriveSessionIds: ['old'],
            driveScoreAlgorithmVersion: 1,
            validatedRoadProcessingVersion: 2,
            createdAt: DateTime.utc(2026),
          ),
        );
    await old
        .box<WorldIndexPointer>('my_world_index_metadata')
        .put(
          'active_generation',
          WorldIndexPointer(activeGeneration: 1, updatedAt: DateTime.utc(2026)),
        );
    await old.box<dynamic>('local_lifecycle_v1').put('history:earlier', {
      'version': 1,
      'state': 'prepared',
    });
    await old.box<dynamic>('profile').put('displayName', 'synthetic profile');
    for (final group in OwnerScopedLocalStore.groups) {
      await OwnerScopedLocalStore.registeredBox(old, group).flush();
    }
  });
  tearDown(() async {
    await old.close();
    await target.close();
    await root.delete(recursive: true);
  });
  Future<LegacyLocalInventory> read() async =>
      LegacyLocalInventory.capture(old, OwnerScopedLocalStore.groups);
  test(
    'all groups payloads scores legacy fields career World links survive copy and reopen',
    () async {
      final before = (await read()).fingerprint;
      await LegacyOwnerPreparation(
        target,
      ).prepare(sourceId: 'synthetic-full', readSource: read);
      await target.close();
      target = await OwnerScopedLocalStore.open(
        root: root.path,
        owner: const GpsOwner.legacy(),
      );
      await LegacyOwnerPreparation(
        target,
      ).prepare(sourceId: 'synthetic-full', readSource: read);
      expect((await read()).fingerprint, before);
      final drive = target.read<DriveSession>(target.owner, 'drives', 'old')!;
      expect(drive.route.last.legacyHiveFields[2], DateTime.utc(2025, 9, 28));
      expect(drive.route.last.legacyHiveFields[7], 'unknown legacy metadata');
      expect(
        target
            .read<DriveScoreRecord>(target.owner, 'drive_scores', 'old:v1')!
            .totalScore,
        700,
      );
      expect(
        target
            .read<DriveTelemetryRecord>(target.owner, 'drive_telemetry', 'old')!
            .points
            .length,
        37,
      );
      expect(
        target
            .read<WorldIndexPointer>(
              target.owner,
              'my_world_index_metadata',
              'active_generation',
            )!
            .activeGeneration,
        1,
      );
      expect(
        target.read<Map>(
          target.owner,
          'local_lifecycle_v1',
          'history:earlier',
        )!['state'],
        'prepared',
      );
      // Unknown old bundles cannot become live known-owner sources by copying.
      expect(
        () => target.repositories(target.owner).rebuildSources(),
        throwsStateError,
      );
    },
  );
  test(
    'missing pointer snapshot prevents preparation completion without deleting source',
    () async {
      await old
          .box<WorldIndexPointer>('my_world_index_metadata')
          .put(
            'active_generation',
            WorldIndexPointer(
              activeGeneration: 99,
              updatedAt: DateTime.utc(2026),
            ),
          );
      final before = (await read()).fingerprint;
      await expectLater(
        LegacyOwnerPreparation(
          target,
        ).prepare(sourceId: 'synthetic-full', readSource: read),
        throwsStateError,
      );
      expect((await read()).fingerprint, before);
    },
  );
  test(
    'active trace missing road or section cannot be marked verified',
    () async {
      await old
          .box<ValidatedRoad>('my_world_validated_roads')
          .clear(); // Synthetic only.
      await old.box<dynamic>('my_world_source_snapshots_v1').clear();
      final before = (await read()).fingerprint;
      await expectLater(
        LegacyOwnerPreparation(
          target,
        ).prepare(sourceId: 'synthetic-full', readSource: read),
        throwsStateError,
      );
      expect((await read()).fingerprint, before);
    },
  );
}
