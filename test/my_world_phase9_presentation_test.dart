import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/world_map_read_model.dart';
import 'package:driveit_project/features/my_world/models/world_trace_detail.dart';
import 'package:driveit_project/features/my_world/services/my_world_settings_service.dart';
import 'package:driveit_project/features/my_world/services/world_intro_policy.dart';
import 'package:driveit_project/features/my_world/services/world_trace_detail_service.dart';
import 'package:driveit_project/models/drive_score_record.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/screens/my_world_map_screen.dart';
import 'package:driveit_project/screens/profile_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 9 intro and settings', () {
    test('skip setting defaults false and persists both values', () async {
      final store = MemoryMyWorldSettingsStore();
      expect(store.skipIntroAnimation, isFalse);
      await store.setSkipIntroAnimation(true);
      expect(store.skipIntroAnimation, isTrue);
      await store.setSkipIntroAnimation(false);
      expect(store.skipIntroAnimation, isFalse);
    });

    test('active World plays unless skipped; empty World never plays', () {
      final active = _mapData(processedIds: const ['drive-a']);
      final empty = _mapData(traces: const [], processedIds: const []);
      expect(
        WorldIntroPolicy.shouldPlay(data: active, skipIntroAnimation: false),
        isTrue,
      );
      expect(
        WorldIntroPolicy.shouldPlay(data: active, skipIntroAnimation: true),
        isFalse,
      );
      expect(
        WorldIntroPolicy.shouldPlay(data: empty, skipIntroAnimation: false),
        isFalse,
      );
    });

    test('normalized reveal stays bounded and duration is fixed', () {
      expect(WorldIntroPolicy.duration, const Duration(seconds: 3));
      expect(
        WorldIntroPolicy.revealProgress(
          animationProgress: 0,
          traceIndex: 999,
          traceCount: 1000,
        ),
        0,
      );
      expect(
        WorldIntroPolicy.revealProgress(
          animationProgress: 1,
          traceIndex: 999,
          traceCount: 1000,
        ),
        1,
      );
    });

    testWidgets('profile settings writes and reloads existing skip value', (
      tester,
    ) async {
      final store = MemoryMyWorldSettingsStore();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsScreen(
            worldSettings: store,
            profileLoader: () async =>
                throw StateError('Profile unavailable in this World-only test'),
          ),
        ),
      );
      SwitchListTile tile() => tester.widget<SwitchListTile>(
        find.byKey(const Key('world_intro_enabled_switch')),
      );
      expect(tile().value, isTrue);
      await tester.ensureVisible(
        find.byKey(const Key('world_intro_enabled_switch')),
      );
      await tester.tap(find.byKey(const Key('world_intro_enabled_switch')));
      await tester.pump();
      expect(store.skipIntroAnimation, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSettingsScreen(
            key: const ValueKey('reopened'),
            worldSettings: store,
            profileLoader: () async =>
                throw StateError('Profile unavailable in this World-only test'),
          ),
        ),
      );
      expect(tile().value, isFalse);
    });
  });

  group('Phase 9 trace detail and last World drive', () {
    test(
      'detail loader reads drive, persisted score and total active distance',
      () async {
        final drive = _drive('drive-a', DateTime(2026, 8, 12, 14, 35));
        final score = _score('drive-a', 742);
        final service = WorldTraceDetailService(
          driveLoader: (id) => id == drive.id ? drive : null,
          scoreLoader: (id) => id == drive.id ? score : null,
          activeDistanceLoader: (_) async => 4321,
        );
        final detail = await service.load('drive-a');
        expect(detail!.drive, same(drive));
        expect(detail.score, same(score));
        expect(detail.activeWorldDistanceMeters, 4321);
        expect(await service.load('missing'), isNull);
      },
    );

    test('latest processed World drive ignores newer unprocessed drive', () {
      final result = WorldTraceDetailService.latestProcessedDrive(
        processedDriveIds: const ['processed-old', 'processed-new'],
        drives: [
          _drive('processed-old', DateTime(2026, 8, 1)),
          _drive('unprocessed', DateTime(2026, 8, 12)),
          _drive('processed-new', DateTime(2026, 8, 10)),
        ],
      );
      expect(result!.id, 'processed-new');
    });

    testWidgets('trace detail renders real metrics and opens correct drive', (
      tester,
    ) async {
      final drive = _drive('drive-a', DateTime(2026, 8, 12, 14, 35));
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldTraceDetailSheet(
              detail: WorldTraceDetail(
                drive: drive,
                score: _score(drive.id, 742),
                activeWorldDistanceMeters: 4321,
              ),
              onViewDrive: () => opened = true,
            ),
          ),
        ),
      );
      expect(find.text('12.08.2026 14:35'), findsOneWidget);
      expect(find.text('742'), findsOneWidget);
      expect(find.text('2 dk'), findsOneWidget);
      expect(find.text('96 km/s'), findsOneWidget);
      expect(find.text('54 km/s'), findsOneWidget);
      expect(find.text('4,3 km'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('view_world_trace_drive_button')));
      expect(opened, isTrue);
    });

    testWidgets('missing Drive Score has a safe non-zero-fabricating label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldTraceDetailSheet(
              detail: WorldTraceDetail(
                drive: _drive('legacy', DateTime(2026, 8, 12)),
                score: null,
                activeWorldDistanceMeters: 1000,
              ),
              onViewDrive: () {},
            ),
          ),
        ),
      );
      expect(find.text('Mevcut değil'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}

MyWorldMapData _mapData({
  List<ResolvedWorldTrace>? traces,
  required List<String> processedIds,
}) {
  final resolved = traces ?? [_resolvedTrace()];
  return MyWorldMapData(
    snapshotGeneration: 1,
    traces: resolved,
    totalActiveDistanceMeters: resolved.fold(
      0,
      (sum, item) => sum + item.trace.distanceMeters,
    ),
    processedDriveCount: processedIds.toSet().length,
    processedDriveSessionIds: processedIds,
    skippedBrokenTraceCount: 0,
    viewport: resolved.isEmpty
        ? null
        : const WorldMapViewport(
            minLatitude: 41,
            maxLatitude: 41.01,
            minLongitude: 29,
            maxLongitude: 29.01,
            source: 'test',
          ),
  );
}

ResolvedWorldTrace _resolvedTrace() => ResolvedWorldTrace(
  trace: ActiveWorldTrace(
    id: 'trace-a',
    sourceDriveSessionId: 'drive-a',
    validatedRoadId: 'road-a',
    matchedSectionId: 'section-a',
    startOffsetMeters: 0,
    endOffsetMeters: 1000,
    directionKey: 'east',
    minLatitude: 41,
    maxLatitude: 41.01,
    minLongitude: 29,
    maxLongitude: 29.01,
    createdAt: DateTime.utc(2026, 8, 12),
    updatedAt: DateTime.utc(2026, 8, 12),
    processingVersion: 2,
  ),
  geometry: const [
    MatchedRoadPoint(latitude: 41, longitude: 29),
    MatchedRoadPoint(latitude: 41.01, longitude: 29.01),
  ],
  visualVariant: 0,
);

DriveSession _drive(String id, DateTime date) => DriveSession(
  id: id,
  date: date,
  distance: 4321,
  durationSeconds: 125,
  averageSpeed: 54,
  maxSpeed: 96,
  mapImagePath: '',
  route: const [],
);

DriveScoreRecord _score(String driveId, double total) => DriveScoreRecord(
  driveId: driveId,
  algorithmVersion: 1,
  telemetryDataVersion: 1,
  calculatedAt: DateTime.utc(2026, 8, 12),
  totalScore: total,
  overallConfidence: .9,
  categories: const [],
);
