// Synthetic data only; shared by host and real Android MethodChannel tests.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/src/hive_impl.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/persistence/my_world_hive.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/legacy_owner_consent.dart';
import 'package:driveit_project/services/legacy_import_inventory.dart';
import 'package:driveit_project/services/legacy_asset_transfer.dart';
import 'package:driveit_project/services/legacy_claim_ledger.dart';
import 'package:driveit_project/services/legacy_account_import.dart';
import '../local_lifecycle_foundation_test.dart' as data;

const importA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const importB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class ImportAuth implements LocalOwnerAuth {
  @override
  String? userId = importA;
  final events = StreamController<String?>.broadcast(sync: true);
  @override
  Stream<String?> get changes => events.stream;
  void change(String? value) {
    userId = value;
    events.add(value);
  }
}

class SyntheticDisk implements ImportDisk {
  int free = 1 << 40;
  bool failSync = false;
  @override
  Future<int> availableBytes(Directory directory) async => free;
  @override
  Future<void> syncDirectory(Directory directory) async {
    if (failSync) throw const ImportFailure('synthetic_fsync_failed');
  }
}

class ImportFixture {
  ImportFixture(this.root, this.factory);
  final Directory root;
  final DatabaseFactory factory;
  late HiveImpl old;
  late Directory oldRoot, documents;
  late LegacyClaimLedger ledger;
  late LocalOwnerLifecycle runtime;
  final auth = ImportAuth();
  final disk = SyntheticDisk();
  final readers = <VerifiedLegacyImport>[];
  late LegacyImportSource source;
  late LegacyOwnerConsent consent;
  late LegacyImportInventory inventory;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aT1sAAAAASUVORK5CYII=',
  );
  Future<void> start() async {
    oldRoot = await Directory('${root.path}/legacy_hive').create();
    documents = await Directory('${root.path}/documents').create();
    await Directory('${documents.path}/posters').create();
    await File('${documents.path}/map.png').writeAsBytes(png, flush: true);
    for (final name in ['poster.png', 'background.png', 'orphan.png']) {
      await File(
        '${documents.path}/posters/$name',
      ).writeAsBytes(png, flush: true);
    }
    old = HiveImpl()..init(oldRoot.path);
    OwnerScopedLocalStore.register(old);
    await old.openBox<DriveSession>('drives');
    await DriveTelemetryHive.openBox(old);
    await DriveScoreHive.openBox(old);
    await MyWorldHive.openBoxes(old);
    for (final group in OwnerScopedLocalStore.groups) {
      if (!old.isBoxOpen(group)) await old.openBox<dynamic>(group);
    }
    final bundle = data.fixture('old');
    bundle.drive.mapImagePath = '${documents.path}/map.png';
    bundle.drive.route.add(
      RoutePoint(
        latitude: 40.02,
        longitude: 29,
        legacyHiveFields: {2: DateTime.utc(2025, 9, 28), 7: 'reserved legacy'},
      ),
    );
    await old.box<DriveSession>('drives').put('old', bundle.drive);
    await old
        .box<DriveTelemetryRecord>('drive_telemetry')
        .put('old', bundle.telemetry!);
    await old
        .box<DriveScoreRecord>('drive_scores')
        .put('old:v1', bundle.score!);
    await old
        .box<ValidatedRoad>('my_world_validated_roads')
        .put(bundle.roads.single.id, bundle.roads.single);
    await CareerContributionRepository(
      old.box<dynamic>('career_contributions_v1'),
    ).prepareLegacy(sources: [bundle], totals: data.totals([bundle]));
    await WorldSourceSnapshotRepository(
      old.box<dynamic>('my_world_source_snapshots_v1'),
    ).prepare(bundle);
    await old
        .box<WorldIndexSnapshot>('my_world_index_snapshots')
        .put(
          1,
          WorldIndexSnapshot(
            generation: 1,
            operationId: 'synthetic',
            processedDriveSessionIds: ['old'],
            traces: [
              ActiveWorldTrace(
                id: 'trace',
                sourceDriveSessionId: 'old',
                validatedRoadId: bundle.roads.single.id,
                matchedSectionId: bundle.roads.single.sections.single.id,
                startOffsetMeters: 0,
                endOffsetMeters: 6000,
                directionKey: 'forward',
                minLatitude: 40,
                maxLatitude: 40.02,
                minLongitude: 29,
                maxLongitude: 29,
                createdAt: data.date,
                updatedAt: data.date,
                processingVersion: 2,
              ),
            ],
            driveScoreAlgorithmVersion: 1,
            validatedRoadProcessingVersion: 2,
            createdAt: data.date,
          ),
        );
    await old
        .box<WorldIndexPointer>('my_world_index_metadata')
        .put(
          'active_generation',
          WorldIndexPointer(activeGeneration: 1, updatedAt: data.date),
        );
    await old.box<dynamic>('drive_posters').put('poster', {
      'id': 'poster',
      'driveId': 'old',
      'createdAt': data.date.millisecondsSinceEpoch,
      'fileName': 'poster.png',
      'exportedPosterPath': 'poster.png',
      'backgroundFileName': 'background.png',
      'backgroundReference': 'background.png',
      'backgroundSourceType': 'customImage',
      'themeId': 'blackout',
      'logoVariant': 'wordmark',
      'startLabel': 'synthetic',
      'endLabel': 'synthetic',
      'showMaxSpeed': true,
    });
    await old.box<dynamic>('profile').put('avatar_bytes', png);
    await old.box<dynamic>('drive_names').put('old', 'synthetic name');
    await old.box<dynamic>('local_lifecycle_v1').put('world:removed', {
      'version': 1,
      'state': 'prepared',
    });
    await old
        .box<dynamic>('planet_segment_outbox_v1')
        .put(
          jsonEncode(['guest', 'segment']),
          jsonEncode({
            'version': 1,
            'owner': 'guest',
            'state': 'queued',
            'payload': {'id': 'segment', 'sourceDriveId': 'old'},
          }),
        );
    for (final group in OwnerScopedLocalStore.groups) {
      await OwnerScopedLocalStore.registeredBox(old, group).flush();
    }
    ledger = await LegacyClaimLedger.open(
      factory: factory,
      path: '${root.path}/claims.sqlite',
    );
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: '${root.path}/live', owner: owner),
      driveInProgress: () async => false,
    );
    await runtime.start();
    source = LegacyImportSource(
      hive: old,
      hiveRoot: oldRoot,
      documents: documents,
      allowedFileRoots: [documents],
      groups: OwnerScopedLocalStore.groups,
    );
    await approve();
  }

  Future<void> approve() async {
    inventory = await source.survey();
    consent = LegacyOwnerConsentController(
      runtime,
      LegacyOwnerPreview(
        manifestFingerprint: inventory.fingerprint,
        driveCount: 1,
        worldStatus: 'synthetic',
        careerStatus: 'synthetic',
        copyContractVerified: true,
      ),
    ).approve();
  }

  LegacyAccountImporter importer({
    Future<void> Function(String)? boundary,
    Future<void> Function(String)? beforeFlush,
    Future<void> Function(int)? onChunk,
    ImportDisk? deviceDisk,
    LocalOwnershipGate? gate,
  }) => LegacyAccountImporter(
    gate: gate ?? LocalOwnershipGate.synthetic(),
    ledger: ledger,
    root: Directory('${root.path}/imports'),
    disk: deviceDisk ?? disk,
    boundary: boundary,
    beforeFlush: beforeFlush,
    onFileChunk: onChunk,
  );
  Future<VerifiedLegacyImport> run([LegacyAccountImporter? importer]) async {
    final result = await (importer ?? this.importer()).import(
      source: source,
      consent: consent,
    );
    readers.add(result);
    return result;
  }

  Future<void> closeReaders() async {
    for (final reader in readers) {
      await reader.close();
    }
    readers.clear();
  }

  Future<void> close() async {
    await closeReaders();
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await old.close();
    await ledger.close();
    // Only the test-created unique root, never application data.
    await root.delete(recursive: true);
  }
}
