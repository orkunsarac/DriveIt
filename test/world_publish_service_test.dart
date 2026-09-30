import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_service.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeGateway implements WorldPublishGateway {
  bool available = true;
  String? userId = 'auth-user';
  Map<String, dynamic>? insertedPayload;
  Map<String, dynamic>? lookupRow;
  String? lookupUserId;
  String? lookupDriveId;
  Object? insertError;

  @override
  bool get isAvailable => available;

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload) async {
    insertedPayload = Map.of(payload);
    if (insertError case final error?) throw error;
    return _row(payload);
  }

  @override
  Future<Map<String, dynamic>?> findForLocalDrive({
    required String userId,
    required String localDriveId,
  }) async {
    lookupUserId = userId;
    lookupDriveId = localDriveId;
    return lookupRow;
  }
}

DriveSession _drive({
  String id = 'stable-drive-id',
  double distance = 5250.5,
}) => DriveSession(
  id: id,
  date: DateTime.utc(2026, 9, 23, 12, 2),
  distance: distance,
  durationSeconds: 120,
  averageSpeed: 37.5,
  maxSpeed: 55,
  mapImagePath: '',
  route: const [],
);

Map<String, dynamic> _row(Map<String, dynamic> payload) => {
  'id': 'publish-id',
  'user_id': 'auth-user',
  ...payload,
  'status': 'pending',
  'error_code': null,
  'created_at': '2026-09-23T12:03:00Z',
  'updated_at': '2026-09-23T12:03:00Z',
  'processed_at': null,
};

void main() {
  test('inserts only client-owned fields from the saved drive', () async {
    final gateway = _FakeGateway();
    final saved = _drive();
    final service = WorldPublishService(
      gateway: gateway,
      savedDriveLookup: (id) => id == saved.id ? saved : null,
    );

    final result = await service.createPendingPublish(_drive());

    expect(result.status, WorldPublishCreateStatus.success);
    expect(gateway.insertedPayload, {
      'local_drive_id': 'stable-drive-id',
      'started_at': '2026-09-23T12:00:00.000Z',
      'ended_at': '2026-09-23T12:02:00.000Z',
      'distance_meters': 5250.5,
      'world_rules_version': MyWorldRules.worldRulesVersion,
    });
    expect(gateway.insertedPayload!.containsKey('user_id'), isFalse);
    expect(gateway.insertedPayload!.containsKey('status'), isFalse);
    expect(result.publish!.status, WorldPublishStatus.pending);
    expect(result.publish!.userId, 'auth-user');
    expect(result.publish!.distanceMeters, 5250.5);
    expect(result.publish!.processedAt, isNull);
    expect(saved.id, 'stable-drive-id');
    expect(saved.distance, 5250.5);
    expect(saved.durationSeconds, 120);
    expect(saved.date, DateTime.utc(2026, 9, 23, 12, 2));
  });

  test(
    'publish distance boundary is 4999 rejected and 5000 accepted',
    () async {
      final gateway = _FakeGateway();
      expect(MyWorldRules.minimumValidDistanceMeters, 5000);
      var saved = _drive(distance: 4999);
      final service = WorldPublishService(
        gateway: gateway,
        savedDriveLookup: (_) => saved,
      );
      expect(
        (await service.createPendingPublish(saved)).status,
        WorldPublishCreateStatus.notEligible,
      );
      expect(gateway.insertedPayload, isNull);

      saved = _drive(distance: 5000);
      expect(
        (await service.createPendingPublish(saved)).status,
        WorldPublishCreateStatus.success,
      );
      expect(gateway.insertedPayload!['distance_meters'], 5000);
    },
  );

  test(
    'rejects missing, unfinished, or unsaved drives before insert',
    () async {
      final gateway = _FakeGateway();
      final unsaved = WorldPublishService(
        gateway: gateway,
        savedDriveLookup: (_) => null,
      );
      expect(
        (await unsaved.createPendingPublish(_drive())).status,
        WorldPublishCreateStatus.invalidDrive,
      );
      final unfinished = _drive()..durationSeconds = 0;
      final service = WorldPublishService(
        gateway: gateway,
        savedDriveLookup: (_) => unfinished,
      );
      expect(
        (await service.createPendingPublish(unfinished)).status,
        WorldPublishCreateStatus.invalidDrive,
      );
      expect(gateway.insertedPayload, isNull);
    },
  );

  test('maps duplicate, missing session, and missing bootstrap', () async {
    final gateway = _FakeGateway()
      ..insertError = const PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
    final drive = _drive();
    final service = WorldPublishService(
      gateway: gateway,
      savedDriveLookup: (_) => drive,
    );
    expect(
      (await service.createPendingPublish(drive)).status,
      WorldPublishCreateStatus.alreadyPublished,
    );
    gateway.userId = null;
    expect(
      (await service.createPendingPublish(drive)).status,
      WorldPublishCreateStatus.notSignedIn,
    );
    gateway.available = false;
    expect(
      (await service.createPendingPublish(drive)).status,
      WorldPublishCreateStatus.supabaseUnavailable,
    );
  });

  test(
    'reads only the active user record and returns null when absent',
    () async {
      final gateway = _FakeGateway();
      final service = WorldPublishService(gateway: gateway);
      expect(await service.getPublishForLocalDrive('stable-drive-id'), isNull);
      expect(gateway.lookupUserId, 'auth-user');
      expect(gateway.lookupDriveId, 'stable-drive-id');

      gateway.lookupRow =
          _row({
              'local_drive_id': 'stable-drive-id',
              'started_at': '2026-09-23T12:00:00Z',
              'ended_at': '2026-09-23T12:02:00Z',
              'distance_meters': 1250.5,
              'world_rules_version': MyWorldRules.worldRulesVersion,
            })
            ..['status'] = 'published'
            ..['processed_at'] = '2026-09-23T12:04:00Z';
      final publish = await service.getPublishForLocalDrive('stable-drive-id');
      expect(publish?.status, WorldPublishStatus.published);
      expect(publish?.localDriveId, 'stable-drive-id');
      expect(publish?.processedAt, DateTime.utc(2026, 9, 23, 12, 4));
    },
  );
}
