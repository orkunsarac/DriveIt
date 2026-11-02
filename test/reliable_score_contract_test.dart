import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:driveit_project/features/world_publish/services/world_publish_source_upload_service.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/services/drive_score_storage_service.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_calculator.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_persistence_coordinator.dart';
import 'package:driveit_project/features/drive_score/services/published_source_score_calculator.dart';
import 'package:driveit_project/features/world_publish/models/published_drive_source.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/published_drive_source_builder.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/local_source_bundle.dart';

class ReliableSourceUploadGateway implements WorldPublishSourceGateway {
  Map<String, dynamic>? uploaded;
  bool downgrade = false;
  @override
  bool get isAvailable => true;
  @override
  String get currentUserId => 'u';
  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  }) async {
    expect(path, 'u/p.json');
    expect(upsert, false);
    uploaded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> attach(Map<String, dynamic> params) async {
    expect(params['p_source_schema_version'], 2);
    final source = uploaded!;
    return {
      'id': 'p',
      'user_id': 'u',
      'local_drive_id': 'new',
      'started_at': source['started_at'],
      'ended_at': source['ended_at'],
      'distance_meters': source['recorded_distance_meters'],
      'world_rules_version': 6,
      'status': 'pending',
      'error_code': null,
      'created_at': source['started_at'],
      'updated_at': source['ended_at'],
      'processed_at': null,
      'source_path': 'u/p.json',
      'source_ready_at': source['ended_at'],
      'source_schema_version': downgrade ? 1 : 2,
      'telemetry_version': 1,
      'drive_score_algorithm_version': 1,
      'raw_route_point_count': (source['raw_route'] as List).length,
      'telemetry_point_count': (source['canonical_telemetry'] as List).length,
    };
  }
}

class LegacySevenFieldAdapter extends DriveScoreRecordAdapter {
  @override
  void write(BinaryWriter writer, DriveScoreRecord record) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(record.driveId)
      ..writeByte(1)
      ..write(record.algorithmVersion)
      ..writeByte(2)
      ..write(record.telemetryDataVersion)
      ..writeByte(3)
      ..write(record.calculatedAt)
      ..writeByte(4)
      ..write(record.totalScore)
      ..writeByte(5)
      ..write(record.overallConfidence)
      ..writeByte(6)
      ..write(record.categories.map((c) => c.toMap()).toList());
  }
}

void main() {
  final start = DateTime.utc(2026, 1, 1, 0, 0, 0, 0, 123);
  final points = List.generate(
    180,
    (i) => CanonicalTelemetryPoint(
      latitude: 40,
      longitude: 29 + i * .00001,
      timestamp: start.add(Duration(seconds: i)),
      speedMps: 10,
      headingDegrees: 90,
      altitudeMeters: 10,
      accuracyMeters: 3,
      distanceFromPreviousMeters: i == 0 ? 0 : 40,
      accelerationMps2: 0,
      speedSource: 'native',
      breakBefore: i == 90,
      gapDurationMicros: 0,
      accelerationReliable: i != 90,
    ),
  );
  final record = DriveTelemetryRecord(
    driveSessionId: 'new',
    dataVersion: 1,
    createdAt: start,
    points: points,
    acquisitionMetadata: {
      'reliabilityPolicyVersion': 1,
      'startedAtMicros': start.microsecondsSinceEpoch,
      'stopRequestedAtMicros': points.last.timestamp.microsecondsSinceEpoch,
    },
  );
  final drive = DriveSession(
    id: 'new',
    date: points.last.timestamp,
    distance: 7160,
    durationSeconds: 179,
    averageSpeed: 36,
    maxSpeed: 36,
    mapImagePath: '',
    route: [
      RoutePoint(latitude: 40, longitude: 29),
      RoutePoint(latitude: 40, longitude: 29.01),
    ],
  );
  final publish = WorldPublish(
    id: 'p',
    userId: 'u',
    localDriveId: 'new',
    startedAt: start,
    endedAt: points.last.timestamp,
    distanceMeters: 7160,
    worldRulesVersion: 6,
    status: WorldPublishStatus.pending,
    errorCode: null,
    createdAt: start,
    updatedAt: start,
    processedAt: null,
  );
  test(
    'actual source upload retains schema2 quality and refuses a downgraded ACK',
    () async {
      final saved = DriveScoreRecord.fromResult(
        driveId: 'new',
        telemetryDataVersion: 1,
        calculatedAt: start,
        result: const DriveScoreCalculator().calculateReliable(
          telemetry: points,
        ),
      );
      final gateway = ReliableSourceUploadGateway();
      final service = WorldPublishSourceUploadService(
        gateway: gateway,
        builder: PublishedDriveSourceBuilder(
          telemetryLoader: (_) => record,
          scoreLoader: (_) => saved,
        ),
      );
      expect(
        (await service.uploadSource(drive: drive, publish: publish)).status,
        WorldPublishSourceUploadStatus.success,
      );
      expect(gateway.uploaded!['score_calculation_mode'], 'reliable_intervals');
      expect(gateway.uploaded!.containsKey('score'), false);
      expect(
        gateway.uploaded!['canonical_telemetry'][90]['break_before'],
        true,
      );
      gateway.downgrade = true;
      expect(
        (await service.uploadSource(drive: drive, publish: publish)).status,
        WorldPublishSourceUploadStatus.attachFailure,
      );
    },
  );
  test(
    'old seven-field Hive scores remain unchanged and new mode survives reopen',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'driveit_score_contract_',
      );
      Hive.init(root.path);
      try {
        Hive.registerAdapter<DriveScoreRecord>(
          LegacySevenFieldAdapter(),
          override: true,
        );
        var box = await Hive.openBox<DriveScoreRecord>('contract');
        final old = DriveScoreRecord.fromResult(
          driveId: 'old',
          telemetryDataVersion: 1,
          calculatedAt: start,
          result: const DriveScoreCalculator().calculate(telemetry: points),
        );
        await box.put('old', old);
        await box.close();
        Hive.registerAdapter<DriveScoreRecord>(
          DriveScoreRecordAdapter(),
          override: true,
        );
        box = await Hive.openBox<DriveScoreRecord>('contract');
        expect(box.get('old')!.totalScore, old.totalScore);
        expect(box.get('old')!.calculationMode, 'unspecified');
        final reliable = DriveScoreRecord.fromResult(
          driveId: 'new',
          telemetryDataVersion: 1,
          calculatedAt: start,
          result: const DriveScoreCalculator().calculateReliable(
            telemetry: points,
          ),
        );
        await box.put('new', reliable);
        await box.close();
        box = await Hive.openBox<DriveScoreRecord>('contract');
        expect(box.get('new')!.calculationMode, 'reliable_intervals');
        expect(box.get('new')!.calculationVersion, 1);
        expect(box.get('new')!.reliabilityPolicyVersion, 1);
        expect(box.get('old')!.totalScore, old.totalScore);
        await box.close();
      } finally {
        await Hive.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'new reliable record and source2 retain all quality evidence and score contract',
    () async {
      DriveScoreRecord? saved;
      final local = await const DriveScorePersistenceCoordinator()
          .calculateAndPersist(
            driveId: 'new',
            existing: null,
            telemetry: record,
            persist: (r) async {
              saved = r;
            },
          );
      expect(local!.calculationMode, 'reliable_intervals');
      expect(saved!.reliabilityPolicyVersion, 1);
      final source = PublishedDriveSourceBuilder(
        telemetryLoader: (_) => record,
        scoreLoader: (_) => saved,
      ).build(drive: drive, publish: publish).source!;
      expect(source.schemaVersion, 2);
      final encoded = source.toJson();
      final restored = PublishedDriveSource.fromJson(encoded);
      expect(restored.toJson(), encoded);
      expect(restored.canonicalTelemetry[90].breakBefore, true);
      expect(restored.canonicalTelemetry[90].accelerationReliable, false);
      expect(
        restored.canonicalTelemetry.first.timestamp.microsecondsSinceEpoch,
        start.microsecondsSinceEpoch,
      );
      final remote = calculateReliablePublishedSource(encoded);
      expect(remote.eligible, true);
      expect(remote.result.totalScore, local.totalScore);
      expect(remote.result.overallConfidence, local.overallConfidence);
      final bundle = LocalSourceBundle(
        drive: drive,
        telemetry: record,
        score: local,
      );
      final roundtrip = LocalSourceBundle.fromMap(bundle.toMap());
      expect(roundtrip.score!.calculationMode, 'reliable_intervals');
      expect(roundtrip.score!.reliabilityPolicyVersion, 1);
      for (final key in [
        'score_calculation_mode',
        'score_calculation_version',
        'telemetry_reliability',
      ]) {
        final broken = Map<String, dynamic>.from(encoded)..remove(key);
        expect(
          () => calculateReliablePublishedSource(broken),
          throwsA(anything),
        );
      }
      final bad = Map<String, dynamic>.from(encoded);
      bad['canonical_telemetry'] = [
        for (final p in encoded['canonical_telemetry'] as List)
          Map<String, dynamic>.from(p),
      ];
      bad['canonical_telemetry'][0]['timestamp_micros'] = '1';
      expect(
        () => calculateReliablePublishedSource(bad),
        throwsFormatException,
      );
    },
  );
  test(
    'persisted historical score is returned untouched and unknown policy cannot create a score',
    () async {
      final old = DriveScoreRecord(
        driveId: 'new',
        algorithmVersion: 1,
        telemetryDataVersion: 1,
        calculatedAt: start,
        totalScore: 123,
        overallConfidence: .5,
        categories: const [],
      );
      var writes = 0;
      final result = await const DriveScorePersistenceCoordinator()
          .calculateAndPersist(
            driveId: 'new',
            existing: old,
            telemetry: record,
            persist: (_) async {
              writes++;
            },
          );
      expect(identical(result, old), true);
      expect(result!.calculationMode, 'unspecified');
      expect(writes, 0);
      final unknown = DriveTelemetryRecord(
        driveSessionId: 'new',
        dataVersion: 1,
        createdAt: start,
        points: points,
        acquisitionMetadata: {
          ...record.acquisitionMetadata,
          'reliabilityPolicyVersion': 99,
        },
      );
      expect(
        await const DriveScorePersistenceCoordinator().calculateAndPersist(
          driveId: 'new',
          existing: null,
          telemetry: unknown,
          persist: (_) async {
            writes++;
          },
        ),
        isNull,
      );
      expect(writes, 0);
      expect(
        const DriveScoreCalculator()
            .calculate(telemetry: points)
            .calculationMode,
        'legacy_v1',
      );
    },
  );
}
