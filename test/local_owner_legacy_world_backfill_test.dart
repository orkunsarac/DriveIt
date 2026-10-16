import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/providers/road_matching_provider.dart';
import 'package:driveit_project/features/my_world/services/road_matching_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';

const _a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class _Auth implements LocalOwnerAuth {
  String? _id = _a;
  final events = StreamController<String?>.broadcast(sync: true);
  @override
  String? get userId => _id;
  @override
  Stream<String?> get changes => events.stream;
  void setUser(String? id) {
    _id = id;
    events.add(id);
  }
}

class _RoadProvider implements RoadMatchingProvider {
  int calls = 0;
  bool receivedTelemetry = false;
  @override
  String get providerId => 'legacy-world-test-provider';

  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    calls++;
    receivedTelemetry = request.canonicalTelemetry.isNotEmpty;
    final points = request.rawRoute
        .map(
          (point) => MatchedRoadPoint(
            latitude: point.latitude,
            longitude: point.longitude,
            headingDegrees: 0,
            confidence: .95,
          ),
        )
        .toList(growable: false);
    final section = MatchedRoadSection(
      id: 'legacy-section',
      geometry: points,
      distanceMeters: 6200,
      confidence: .95,
      sourceTraceIndex: 0,
      sourceChunkIndex: 0,
    );
    return RoadMatchingResult(
      sections: [section],
      geometry: points,
      validDistanceMeters: 6200,
      status: RoadValidationStatus.validated,
      confidence: .95,
      directionKey: 'legacy-direction',
      averageHeadingDegrees: 0,
      errorMessage: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _Auth auth;
  late _RoadProvider provider;
  late LocalOwnerLifecycle runtime;

  LocalOwnerLifecycle createRuntime() => LocalOwnerLifecycle(
    gate: LocalOwnershipGate.synthetic(),
    auth: auth,
    openStore: (owner) =>
        OwnerScopedLocalStore.open(root: root.path, owner: owner),
    driveInProgress: () async => false,
    worldRoadMatching: RoadMatchingService(provider: provider),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('owner_legacy_world_');
    auth = _Auth();
    provider = _RoadProvider();
    runtime = createRuntime();
    await runtime.start();
  });

  tearDown(() async {
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await root.delete(recursive: true);
  });

  DriveSession legacyDrive(String id) => DriveSession(
    id: id,
    date: DateTime.utc(2020, 1, 1),
    distance: 6200,
    durationSeconds: 360,
    averageSpeed: 60,
    maxSpeed: 90,
    mapImagePath: '',
    route: List.generate(
      81,
      (index) => RoutePoint(latitude: .06 * index / 80, longitude: 29),
    ),
  );

  Future<void> seedImported(DriveSession drive) async {
    await runtime.close();
    runtime.dispose();
    final owner = GpsOwner.account(_a);
    final store = await OwnerScopedLocalStore.open(
      root: root.path,
      owner: owner,
    );
    await store.put(owner, 'drives', drive.id, drive);
    await store.put(owner, 'drive_details_v1', drive.id, {
      'accountTransfer': 'legacy',
      'localOnly': true,
    });
    await store.put(owner, 'drive_source_provenance_v1', drive.id, {
      'version': 1,
      'status': 'unproven',
      'ownerScope': owner.targetStore,
      'archiveNamespace': 'legacy',
      'archiveFingerprint': 'b' * 64,
    });
    await store.put(owner, 'owned_drive_finalization_v1', drive.id, {
      'version': 1,
      'state': 'completed',
      'localOnlyImport': true,
      'transferClaim': 'account_transfer_v1:legacy-claim',
    });
    await store
        .repositories(owner)
        .prepareSource(
          LocalSourceBundle(
            drive: drive,
            ownerScope: owner.targetStore,
            sourceProvenance: DriveSourceProvenance.unproven(
              ownerScope: owner.targetStore,
              archiveNamespace: 'legacy',
              archiveFingerprint: 'b' * 64,
            ),
          ),
        );
    await store.close();
    runtime = createRuntime();
    await runtime.start();
  }

  test(
    'confirmed backfill validates real route once, stays local and owner scoped',
    () async {
      final drive = legacyDrive('transfer_legacy_1');
      final duplicateRoute = legacyDrive('transfer_legacy_2');
      await seedImported(drive);
      await seedImported(duplicateRoute);
      final leaseA = runtime.lease;
      final preview = await leaseA.previewLegacyWorldBackfill();
      expect(preview.inspected, 2);
      expect(preview.eligibleCount, 2);
      expect(leaseA.score(drive.id), isNull);

      await expectLater(
        leaseA.backfillLegacyWorld(preview, mapMatchingConsent: false),
        throwsA(isA<StateError>()),
      );
      expect(provider.calls, 0);

      final result = await leaseA.backfillLegacyWorld(
        preview,
        mapMatchingConsent: true,
      );
      expect(result.processed, 2);
      expect(provider.calls, 2);
      expect(provider.receivedTelemetry, isFalse);
      expect(leaseA.score(drive.id), isNull);
      expect((await leaseA.worldMap()).traces, hasLength(1));

      final repeated = await leaseA.previewLegacyWorldBackfill();
      expect(repeated.eligibleCount, 0);
      expect(repeated.alreadyProcessed, 2);
      final rebuilt = await leaseA.rebuildWorld();
      expect(rebuilt.success, isTrue);
      expect((await leaseA.worldMap()).traces, hasLength(1));

      auth.setUser(_b);
      await runtime.settled;
      expect((await runtime.lease.previewLegacyWorldBackfill()).inspected, 0);
      expect((await runtime.lease.worldMap()).traces, isEmpty);
    },
  );
}
