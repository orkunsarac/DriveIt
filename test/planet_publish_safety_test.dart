import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_service.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_source_upload_service.dart';
import 'package:driveit_project/features/world_publish/services/published_drive_source_builder.dart';
import 'package:driveit_project/features/world_publish/widgets/drive_world_publish_section.dart';
import 'package:driveit_project/features/world_publish/segments/planet_publication_section.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment_outbox.dart';
import 'support/legacy_publish_fixture.dart';
import 'planet_segment_test.dart' as segments;

class PublishGateway extends Fake implements WorldPublishGateway {
  int creates = 0;
  Map<String, dynamic>? row;
  @override
  bool get isAvailable => true;
  @override
  String? get currentUserId => 'owner';
  @override
  Future<Map<String, dynamic>?> findForLocalDrive({
    required String userId,
    required String localDriveId,
  }) async => row;
  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload) async {
    creates++;
    return {...publishRow(), ...payload};
  }
}

Map<String, dynamic> publishRow({bool ready = false}) => {
  'id': 'publish',
  'user_id': 'owner',
  'local_drive_id': 'drive',
  'status': 'pending',
  'started_at': '2026-01-01T00:00:00Z',
  'ended_at': '2026-01-01T00:04:00Z',
  'distance_meters': 8000,
  'world_rules_version': 6,
  'created_at': '2026-01-01T00:05:00Z',
  'updated_at': '2026-01-01T00:05:00Z',
  'source_path': ready ? 'owner/publish.json' : null,
  'source_ready_at': ready ? '2026-01-01T00:05:00Z' : null,
};
DriveSession drive({bool routeGap = false}) => DriveSession(
  id: 'drive',
  date: DateTime.utc(2026),
  distance: 24000,
  durationSeconds: 600,
  averageSpeed: 30,
  maxSpeed: 50,
  mapImagePath: '',
  route: [
    RoutePoint(latitude: 40, longitude: 29),
    RoutePoint(latitude: 40.1, longitude: 29, breakBefore: routeGap),
  ],
);

void main() {
  test(
    'direct legacy create blocks canonical gaps, route-only gaps and unknown metadata before insert',
    () async {
      final gateway = PublishGateway();
      for (final pair in [
        (drive(), segments.fixture([8000, 4000, 12000])),
        (drive(routeGap: true), legacyPublishFixture('drive')),
        (drive(), null),
        (
          drive(),
          DriveTelemetryRecord(
            driveSessionId: 'drive',
            dataVersion: 1,
            createdAt: DateTime.utc(2026),
            points: legacyPublishFixture('drive').points,
          ),
        ),
      ]) {
        final service = WorldPublishService(
          gateway: gateway,
          savedDriveLookup: (_) => pair.$1,
          telemetryLoader: (_) => pair.$2,
        );
        expect(
          (await service.createPendingPublish(pair.$1)).status,
          WorldPublishCreateStatus.notEligible,
        );
      }
      expect(gateway.creates, 0);
    },
  );
  test(
    'source v1 builder rejects gap metadata instead of flattening disconnected geometry',
    () {
      final p = WorldPublish.fromRow(publishRow());
      final builder = PublishedDriveSourceBuilder(
        telemetryLoader: (_) => segments.fixture([8000, 12000]),
      );
      expect(
        builder.build(drive: drive(), publish: p).status,
        PublishedDriveSourceBuildStatus.invalidCanonicalTelemetry,
      );
      expect(
        const PublishedDriveSourceBuilder()
            .build(drive: drive(), publish: p)
            .source,
        isNull,
      );
    },
  );
  test('server-ready recovery does not rebuild local unknown source', () async {
    final service = WorldPublishSourceUploadService(
      gateway: ReadySourceGateway(),
    );
    final result = await service.uploadSource(
      drive: drive(),
      publish: WorldPublish.fromRow(publishRow(ready: true)),
    );
    expect(result.status, WorldPublishSourceUploadStatus.success);
  });
  testWidgets(
    'existing-only widget cannot fall back to new legacy creation after missing refetch',
    (tester) async {
      final d = drive();
      final g = PublishGateway();
      final service = WorldPublishService(
        gateway: g,
        savedDriveLookup: (_) => d,
        telemetryLoader: (_) => legacyPublishFixture('drive'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanetPublicationSection(
              drive: d,
              existingLookup: () async => true,
              publishService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DriveWorldPublishSection), findsOneWidget);
      expect(
        find.byKey(const ValueKey('drive_world_publish_button')),
        findsNothing,
      );
      expect(find.textContaining('Mevcut yayın bulunamadı'), findsOneWidget);
      expect(g.creates, 0);
    },
  );
  testWidgets(
    'disabled backend never labels persisted mock acceptance as real publication',
    (tester) async {
      final box = segments.MemoryBox();
      final g = segments.FakeGateway();
      final record = segments.fixture([8000]);
      final s = const PlanetSegmentBuilder()
          .build('drive', record)
          .segments
          .single;
      final mock = PlanetSegmentOutbox(box, gateway: g);
      await mock.prepare('owner', [s]);
      await mock.deliver('owner', s.id);
      expect(mock.entry('owner', s.id)!['state'], 'accepted');
      final disabled = PlanetSegmentOutbox(box);
      expect(disabled.acceptedDistance('owner'), 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlanetPublicationSection(
                drive: drive(),
                record: record,
                existingLookup: () async => false,
                outbox: disabled,
                ownerScope: 'owner',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('gerçek Gezegen kabulü değildir'),
        findsOneWidget,
      );
      expect(find.text("DriveIt Gezegeni'nde"), findsNothing);
      expect(find.text('Sunucu tarafından kabul edildi'), findsNothing);
    },
  );
}

class ReadySourceGateway extends Fake implements WorldPublishSourceGateway {
  @override
  bool get isAvailable => true;
  @override
  String? get currentUserId => 'owner';
  // Any upload/attach would reach Fake.noSuchMethod and fail this recovery test.
}
