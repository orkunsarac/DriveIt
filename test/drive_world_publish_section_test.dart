import 'package:driveit_project/features/my_world/config/my_world_rules.dart';
import 'package:driveit_project/features/world_publish/models/world_publish.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_service.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_processing_service.dart';
import 'package:driveit_project/features/world_publish/services/world_publish_source_upload_service.dart';
import 'package:driveit_project/features/world_publish/widgets/drive_world_publish_section.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Gateway implements WorldPublishGateway {
  bool available = true;
  String? userId = 'auth-user';
  Map<String, dynamic>? row;
  Object? insertError;
  bool returnPendingAfterDuplicate = false;
  int lookupCalls = 0;
  int insertCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, dynamic>?> findForLocalDrive({
    required String userId,
    required String localDriveId,
  }) async {
    lookupCalls++;
    return row;
  }

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload) async {
    insertCalls++;
    if (returnPendingAfterDuplicate) row = _row('pending');
    if (insertError case final error?) throw error;
    return _row('pending');
  }
}

class _UploadService extends WorldPublishSourceUploadService {
  int calls = 0;
  bool fail = false;
  @override
  Future<WorldPublishSourceUploadResult> uploadSource({
    required DriveSession drive,
    required WorldPublish publish,
    Future<WorldPublish?> Function(String localDriveId)? reloadPublish,
  }) async {
    calls++;
    if (fail) {
      return const WorldPublishSourceUploadResult(
        WorldPublishSourceUploadStatus.uploadFailure,
      );
    }
    return WorldPublishSourceUploadResult(
      WorldPublishSourceUploadStatus.success,
      publish: WorldPublish.fromRow(_row('pending', ready: true)),
    );
  }
}

class _ProcessingGateway implements WorldPublishProcessingGateway {
  _ProcessingGateway(this.owner);
  final _Gateway owner;
  bool available = true;
  bool session = true;
  Object? response = {'ok': false, 'error_code': 'publish_lookup_failed'};
  int calls = 0;
  @override
  bool get isAvailable => available;
  @override
  bool get hasSession => session;
  @override
  Future<Object?> invoke(String functionName, Map<String, dynamic> body) async {
    expect(functionName, 'process-world-publish');
    expect(body, {'publish_id': 'publish-1'});
    calls++;
    if (response is Map && (response as Map)['ok'] == true) {
      owner.row = _row('processing', ready: true);
    }
    return response;
  }
}

DriveSession _drive([double distance = 5000]) => DriveSession(
  id: 'drive-1',
  date: DateTime.utc(2026, 9, 23, 12),
  distance: distance,
  durationSeconds: 120,
  averageSpeed: 40,
  maxSpeed: 60,
  mapImagePath: '',
  route: const [],
);

Map<String, dynamic> _row(
  String status, {
  String? errorCode,
  bool ready = false,
}) => {
  'id': 'publish-1',
  'user_id': 'auth-user',
  'local_drive_id': 'drive-1',
  'started_at': '2026-09-23T11:58:00Z',
  'ended_at': '2026-09-23T12:00:00Z',
  'distance_meters': 5000,
  'world_rules_version': MyWorldRules.worldRulesVersion,
  'status': status,
  'error_code': errorCode,
  'created_at': '2026-09-23T12:01:00Z',
  'updated_at': '2026-09-23T12:01:00Z',
  'processed_at': null,
  'source_path': ready ? 'auth-user/publish-1.json' : null,
  'source_ready_at': ready ? '2026-09-23T12:02:00Z' : null,
};

Future<void> _show(
  WidgetTester tester,
  _Gateway gateway, {
  double distance = 5000,
  _UploadService? uploadService,
  WorldPublishProcessingService? processingService,
}) async {
  final drive = _drive(distance);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DriveWorldPublishSection(
          drive: drive,
          publishService: WorldPublishService(
            gateway: gateway,
            savedDriveLookup: (_) => drive,
          ),
          sourceUploadService: uploadService ?? _UploadService(),
          processingService: processingService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out user sees account message, short drive is disabled', (
    tester,
  ) async {
    final gateway = _Gateway()..userId = null;
    await _show(tester, gateway);
    expect(
      find.text(
        "DriveIt Gezegeni'ne yayınlamak için DriveIt hesabına giriş yap.",
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('drive_world_publish_button')),
      findsNothing,
    );
    expect(gateway.insertCalls, 0);

    gateway.userId = 'auth-user';
    await _show(tester, gateway, distance: 4999);
    expect(
      find.text(
        'Bu sürüş DriveIt Gezegeni için minimum 5 km şartını karşılamıyor.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('drive_world_publish_button')),
      findsNothing,
    );
  });

  testWidgets(
    'empty publish shows button; cancel does not insert; success requires source',
    (tester) async {
      final gateway = _Gateway();
      final uploader = _UploadService();
      await _show(tester, gateway, uploadService: uploader);
      final button = find.byKey(const ValueKey('drive_world_publish_button'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text("DriveIt Gezegeni'ne yayınlansın mı?"), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(gateway.insertCalls, 0);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yayınla'));
      await tester.pumpAndSettle();
      expect(gateway.insertCalls, 1);
      expect(uploader.calls, 1);
      expect(find.text('Yayın isteği alındı'), findsOneWidget);
      expect(button, findsNothing);
    },
  );

  testWidgets('server publish statuses use accurate labels', (tester) async {
    final gateway = _Gateway();
    for (final (status, text) in [
      ('pending', 'Yayın verisi henüz gönderilmedi'),
      ('processing', "DriveIt Gezegeni'ne işleniyor"),
      ('published', "DriveIt Gezegeni'nde"),
      ('failed', 'Yayınlama işlenemedi'),
    ]) {
      gateway.row = _row(
        status,
        errorCode: status == 'failed' ? 'server_code' : null,
      );
      await _show(tester, gateway);
      expect(find.text(text), findsOneWidget);
      expect(
        find.byKey(const ValueKey('drive_world_publish_button')),
        findsNothing,
      );
      if (status == 'failed') {
        expect(
          find.textContaining('Sürüş işlenirken bir sorun oluştu.'),
          findsOneWidget,
        );
        expect(find.textContaining('server_code'), findsNothing);
      }
    }
  });

  testWidgets('old pending row offers completion without another insert', (
    tester,
  ) async {
    final gateway = _Gateway()..row = _row('pending');
    final uploader = _UploadService();
    await _show(tester, gateway, uploadService: uploader);
    expect(find.text('Yayın verisi henüz gönderilmedi'), findsOneWidget);
    await tester.tap(find.text('Gönderimi Tamamla'));
    await tester.pumpAndSettle();
    expect(gateway.insertCalls, 0);
    expect(uploader.calls, 1);
    expect(find.text('Yayın isteği alındı'), findsOneWidget);
  });

  testWidgets('source-ready pending row offers processing recovery', (
    tester,
  ) async {
    final gateway = _Gateway()..row = _row('pending', ready: true);
    final processingGateway = _ProcessingGateway(gateway);
    processingGateway.response = {
      'ok': true,
      'validation': {
        'validated_road_id': 'road-1',
        'valid_distance_meters': 5000,
        'eligible_for_world': true,
        'section_count': 2,
      },
    };
    final uploader = _UploadService();
    await _show(
      tester,
      gateway,
      uploadService: uploader,
      processingService: WorldPublishProcessingService(
        gateway: processingGateway,
      ),
    );
    expect(find.text('Yayın isteği alındı'), findsOneWidget);
    expect(find.text('İşlemeyi Başlat'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('process_world_publish')));
    await tester.pumpAndSettle();
    expect(processingGateway.calls, 1);
    expect(gateway.insertCalls, 0);
    expect(uploader.calls, 0);
    expect(find.text("DriveIt Gezegeni'ne işleniyor"), findsOneWidget);
    expect(find.text('İşlemeyi Başlat'), findsNothing);
  });

  testWidgets('retryable processing failure can be retried without upload', (
    tester,
  ) async {
    final gateway = _Gateway()..row = _row('pending', ready: true);
    final processingGateway = _ProcessingGateway(gateway);
    final uploader = _UploadService();
    await _show(
      tester,
      gateway,
      uploadService: uploader,
      processingService: WorldPublishProcessingService(
        gateway: processingGateway,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('process_world_publish')));
    await tester.pumpAndSettle();
    expect(
      find.text('İşleme başlatılamadı. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(find.text('İşlemeyi Başlat'), findsOneWidget);
    expect(uploader.calls, 0);
    expect(gateway.insertCalls, 0);
    processingGateway.response = {
      'ok': true,
      'validation': {
        'validated_road_id': 'road-1',
        'valid_distance_meters': 5000,
        'eligible_for_world': true,
        'section_count': 2,
      },
    };
    await tester.tap(find.byKey(const ValueKey('process_world_publish')));
    await tester.pumpAndSettle();
    expect(processingGateway.calls, 2);
    expect(find.text("DriveIt Gezegeni'ne işleniyor"), findsOneWidget);
    expect(uploader.calls, 0);
  });

  testWidgets('source transfer failure remains pending and can retry', (
    tester,
  ) async {
    final gateway = _Gateway()..row = _row('pending');
    final uploader = _UploadService()..fail = true;
    await _show(tester, gateway, uploadService: uploader);
    await tester.tap(find.text('Gönderimi Tamamla'));
    await tester.pumpAndSettle();
    expect(find.text('Yayın verisi gönderilemedi.'), findsOneWidget);
    expect(find.text('Gönderimi Tamamla'), findsOneWidget);
    expect(gateway.insertCalls, 0);
    uploader.fail = false;
    await tester.tap(find.text('Gönderimi Tamamla'));
    await tester.pumpAndSettle();
    expect(uploader.calls, 2);
    expect(find.text('Yayın isteği alındı'), findsOneWidget);
  });

  testWidgets('duplicate insert reloads the server-owned status', (
    tester,
  ) async {
    final gateway = _Gateway()
      ..returnPendingAfterDuplicate = true
      ..insertError = const PostgrestException(
        message: 'duplicate',
        code: '23505',
      );
    await _show(tester, gateway);
    expect(gateway.lookupCalls, 1);
    await tester.tap(find.byKey(const ValueKey('drive_world_publish_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yayınla'));
    await tester.pumpAndSettle();
    expect(gateway.insertCalls, 1);
    expect(gateway.lookupCalls, 3);
    expect(find.text('Yayın isteği alındı'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drive_world_publish_button')),
      findsNothing,
    );
  });
}
