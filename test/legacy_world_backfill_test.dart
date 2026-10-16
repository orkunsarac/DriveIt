import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/services/legacy_world_backfill.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';

const _a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  late Directory root;
  late OwnerScopedLocalStore storeA;
  late OwnerScopedLocalStore storeB;
  final ownerA = GpsOwner.account(_a);
  final ownerB = GpsOwner.account(_b);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('legacy_world_backfill_');
    storeA = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
    storeB = await OwnerScopedLocalStore.open(root: root.path, owner: ownerB);
  });

  tearDown(() async {
    await storeA.close();
    await storeB.close();
    await root.delete(recursive: true);
  });

  DriveSession drive(String id, double endLatitude) => DriveSession(
    id: id,
    date: DateTime.utc(2026, 1, 1),
    distance: 6500,
    durationSeconds: 300,
    averageSpeed: 70,
    maxSpeed: 100,
    mapImagePath: '',
    route: List.generate(
      81,
      (index) => RoutePoint(latitude: endLatitude * index / 80, longitude: 29),
    ),
  );

  Future<void> putLegacy(DriveSession drive) async {
    await storeA.put(ownerA, 'drives', drive.id, drive);
    await storeA.put(ownerA, 'drive_details_v1', drive.id, {
      'accountTransfer': 'legacy',
      'localOnly': true,
    });
    await storeA.put(ownerA, 'drive_source_provenance_v1', drive.id, {
      'version': 1,
      'status': 'unproven',
      'ownerScope': storeA.scope,
      'archiveNamespace': 'legacy',
      'archiveFingerprint': 'a' * 64,
    });
    await storeA.put(ownerA, 'owned_drive_finalization_v1', drive.id, {
      'version': 1,
      'state': 'completed',
      'localOnlyImport': true,
      'transferClaim': 'account_transfer_v1:legacy-claim',
    });
  }

  test(
    'only proven account transfer metadata and >=5km route are candidates',
    () async {
      final eligible = drive('transfer_eligible', .06);
      final short = drive('transfer_short', .02);
      final ordinary = drive('ordinary_account_drive', .08);
      await putLegacy(eligible);
      await putLegacy(short);
      await storeA.put(ownerA, 'drives', ordinary.id, ordinary);

      final preview = LegacyWorldBackfill.inspect(
        store: storeA,
        owner: ownerA,
        drives: [eligible, short, ordinary],
        snapshot: WorldIndexSnapshot.empty(
          driveScoreAlgorithmVersion: 1,
          validatedRoadProcessingVersion: 6,
        ),
      );

      expect(preview.inspected, 2);
      expect(preview.eligibleCount, 1);
      expect(preview.candidates.single.driveId, eligible.id);
      expect(preview.ineligible, 1);
      expect(preview.alreadyProcessed, 0);
      expect(preview.candidates.single.routeFingerprint, isNotEmpty);
      expect(
        LegacyWorldBackfill.inspect(
          store: storeB,
          owner: ownerB,
          drives: [eligible, short],
          snapshot: WorldIndexSnapshot.empty(
            driveScoreAlgorithmVersion: 1,
            validatedRoadProcessingVersion: 6,
          ),
        ).inspected,
        0,
      );
    },
  );

  test(
    'processed import is idempotently reported and invalid coordinates fail closed',
    () async {
      final processed = drive('transfer_processed', .07);
      final malformed = drive('transfer_bad', .08)..route.last.latitude = 91;
      await putLegacy(processed);
      await putLegacy(malformed);
      await storeA.put(ownerA, LegacyWorldBackfill.markerBox, processed.id, {
        'version': 1,
        'status': 'processed',
        'ownerScope': storeA.scope,
        'routeFingerprint': LegacyWorldBackfill.routeFingerprint(processed),
      });

      final preview = LegacyWorldBackfill.inspect(
        store: storeA,
        owner: ownerA,
        drives: [processed, malformed],
        snapshot: WorldIndexSnapshot.empty(
          driveScoreAlgorithmVersion: 1,
          validatedRoadProcessingVersion: 6,
        ),
      );
      expect(preview.inspected, 2);
      expect(preview.alreadyProcessed, 1);
      expect(preview.eligibleCount, 0);
      expect(preview.ineligible, 1);
    },
  );
}
