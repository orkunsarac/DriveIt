import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/services/my_world_rebuild_service.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';

const _ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _sourceIdentity = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'proven source projects once per device; History, World and Career stay independent',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'phase8_owner_projection_',
      );
      final ownerA = GpsOwner.account(_ownerA);
      final ownerB = GpsOwner.account(_ownerB);
      final deviceA = await OwnerScopedLocalStore.open(
        root: '${root.path}${Platform.pathSeparator}device-a',
        owner: ownerA,
      );
      final deviceA2 = await OwnerScopedLocalStore.open(
        root: '${root.path}${Platform.pathSeparator}device-a2',
        owner: ownerA,
      );
      final deviceB = await OwnerScopedLocalStore.open(
        root: '${root.path}${Platform.pathSeparator}device-b',
        owner: ownerB,
      );
      try {
        final bundleA = _bundle(ownerA, 'device-a-drive');
        final bundleA2 = _bundle(ownerA, 'device-a2-drive');

        await _project(deviceA, ownerA, bundleA);
        await _project(deviceA2, ownerA, bundleA2);

        for (final entry in [
          (deviceA, ownerA, bundleA),
          (deviceA2, ownerA, bundleA2),
        ]) {
          final (store, owner, bundle) = entry;
          final career = store.repositories(owner).careerStatistics()!;
          expect(career.totalDistanceMeters, 6000);
          expect(
            store
                .keys(owner, 'career_contributions_v1')
                .where((key) => key.toString().startsWith('source:'))
                .toList(),
            ['source:$_sourceIdentity'],
          );
          final world = await store.worldIndex(owner).getActiveSnapshot();
          expect(world.validatedRoadProcessingVersion, MyWorldRules.worldRulesVersion);
          expect(world.validatedRoadProcessingVersion, 6);
          expect(world.traces, hasLength(1));
          expect(world.traces.single.sourceDriveSessionId, bundle.drive.id);
        }

        // A device-local ID may differ; contribution identity remains the
        // immutable source UUID, so repeating the projection is exactly once.
        await _project(deviceA2, ownerA, bundleA2);
        expect(
          deviceA2.repositories(ownerA).careerStatistics()!.totalDistanceMeters,
          6000,
        );
        expect(
          deviceA2
              .keys(ownerA, 'career_contributions_v1')
              .where((key) => key.toString().startsWith('source:'))
              .toList(),
          ['source:$_sourceIdentity'],
        );

        // History deletion keeps the independently prepared World source and
        // Career contribution. This is a synthetic projection test only; it
        // does not claim cross-device server projection acceptance.
        await deviceA.repositories(ownerA).deleteHistory(bundleA.drive.id);
        expect(deviceA.read<DriveSession>(ownerA, 'drives', bundleA.drive.id), isNull);
        expect(
          deviceA.repositories(ownerA).careerStatistics()!.totalDistanceMeters,
          6000,
        );
        expect(
          (await deviceA.worldIndex(ownerA).getActiveSnapshot()).traces,
          hasLength(1),
        );

        // Removing this drive from the World projection does not remove its
        // local History or Career basis on the second device.
        final excluded = await _rebuild(
          deviceA2,
          ownerA,
          bundleA2,
          excluded: {bundleA2.drive.id},
        );
        expect(excluded.success, isTrue);
        expect(
          (await deviceA2.worldIndex(ownerA).getActiveSnapshot()).traces,
          isEmpty,
        );
        expect(deviceA2.read<DriveSession>(ownerA, 'drives', bundleA2.drive.id), isNotNull);
        expect(
          deviceA2.repositories(ownerA).careerStatistics()!.totalDistanceMeters,
          6000,
        );

        // Owner B's separate namespace has no source, legacy contribution, or
        // World projection. No legacy `drive:<id>` contribution was imported.
        expect(deviceB.repositories(ownerB).source(bundleA.drive.id), isNull);
        expect(deviceB.keys(ownerB, 'career_contributions_v1'), isEmpty);
        expect(
          (await deviceB.worldIndex(ownerB).getActiveSnapshot()).traces,
          isEmpty,
        );
      } finally {
        await deviceB.close();
        await deviceA2.close();
        await deviceA.close();
        await root.delete(recursive: true);
      }
    },
  );
}

Future<void> _project(
  OwnerScopedLocalStore store,
  GpsOwner owner,
  LocalSourceBundle bundle,
) async {
  await store.repositories(owner).prepareSource(bundle);
  await store.repositories(owner).contribute(bundle);
  await store.repositories(owner).contribute(bundle);
  await store.put(owner, 'drives', bundle.drive.id, bundle.drive);
  await store.put(owner, 'drive_telemetry', bundle.drive.id, bundle.telemetry);
  await store.put(
    owner,
    'drive_source_provenance_v1',
    bundle.drive.id,
    bundle.sourceProvenance!.toMap(),
  );
  await store.put(
    owner,
    'drive_scores',
    'drive_score:${bundle.drive.id}:v1',
    bundle.score,
  );
  final repository = store.worldSources(owner);
  await repository.saveValidatedRoad(bundle.roads.single);
  final result = await _rebuild(store, owner, bundle);
  expect(result.success, isTrue);
}

Future<dynamic> _rebuild(
  OwnerScopedLocalStore store,
  GpsOwner owner,
  LocalSourceBundle bundle, {
  Set<String> excluded = const {},
}) {
  final repositories = store.repositories(owner);
  final world = store.worldSources(owner);
  final index = store.worldIndex(owner);
  return MyWorldRebuildService(
    repository: world,
    indexRepository: index,
    driveLoader: () async => repositories
        .rebuildSources()
        .map((source) => source.drive)
        .toList(growable: false),
    telemetryLoader: (id) async => id == bundle.drive.id
        ? bundle.telemetry!.points
        : const <CanonicalTelemetryPoint>[],
    driveEligibility: (_) => true,
    worldDeleted: (_) => false,
    traceFilter: (traces) => traces,
    clock: () => DateTime.utc(2026, 10, 13),
  ).rebuild(
    targetVersion: DriveScoreAlgorithmVersion.v1,
    excludedDriveIds: excluded,
  );
}

LocalSourceBundle _bundle(GpsOwner owner, String driveId) {
  final now = DateTime.utc(2026, 10, 12, 9);
  final provenance = DriveSourceProvenance.proven(
    sourceIdentity: _sourceIdentity,
    ownerScope: owner.targetStore,
  );
  final points = [
    CanonicalTelemetryPoint(
      latitude: 41,
      longitude: 29,
      timestamp: now,
      speedMps: 10,
      headingDegrees: 90,
      altitudeMeters: 0,
      accuracyMeters: 5,
      distanceFromPreviousMeters: 0,
      accelerationMps2: 0,
    ),
    CanonicalTelemetryPoint(
      latitude: 41,
      longitude: 29.06,
      timestamp: now.add(const Duration(minutes: 10)),
      speedMps: 10,
      headingDegrees: 90,
      altitudeMeters: 0,
      accuracyMeters: 5,
      distanceFromPreviousMeters: 6000,
      accelerationMps2: 0,
    ),
  ];
  final drive = DriveSession(
    id: driveId,
    date: now,
    distance: 6000,
    durationSeconds: 600,
    averageSpeed: 36,
    maxSpeed: 36,
    mapImagePath: '',
    route: [
      RoutePoint(latitude: 41, longitude: 29),
      RoutePoint(latitude: 41, longitude: 29.06),
    ],
  );
  const geometry = [
    MatchedRoadPoint(latitude: 41, longitude: 29, headingDegrees: 90),
    MatchedRoadPoint(latitude: 41, longitude: 29.06, headingDegrees: 90),
  ];
  final road = ValidatedRoad(
    id: '$driveId-road',
    driveSessionId: driveId,
    geometry: geometry,
    sections: const [
      MatchedRoadSection(
        id: 'section',
        geometry: geometry,
        distanceMeters: 6000,
        confidence: 1,
        sourceTraceIndex: 0,
        sourceChunkIndex: 0,
      ),
    ],
    validDistanceMeters: 6000,
    status: RoadValidationStatus.validated,
    validatedAt: now,
    providerId: 'synthetic-projection-test',
    confidence: 1,
    processingVersion: MyWorldRules.validatedRoadProcessingVersion,
    directionKey: 'eastbound',
    averageHeadingDegrees: 90,
    createdAt: now,
    updatedAt: now,
  );
  return LocalSourceBundle(
    drive: drive,
    telemetry: DriveTelemetryRecord(
      driveSessionId: driveId,
      dataVersion: DriveTelemetryRecord.currentDataVersion,
      createdAt: now,
      acquisitionMetadata: {
        'provenanceStatus': 'proven',
        'sourceIdentity': _sourceIdentity,
        'sourceIdentityVersion': 1,
        'sourceNamespace': 'drive_source_v1',
      },
      points: points,
    ),
    score: DriveScoreRecord(
      driveId: driveId,
      algorithmVersion: DriveScoreRecord.currentAlgorithmVersion,
      telemetryDataVersion: DriveTelemetryRecord.currentDataVersion,
      calculatedAt: now,
      totalScore: 80,
      overallConfidence: 1,
      categories: const [],
    ),
    roads: [road],
    ownerScope: owner.targetStore,
    sourceProvenance: provenance,
  );
}
