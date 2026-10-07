import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driveit_project/features/planet/models/planet_trace_detail.dart';
import 'package:driveit_project/features/planet/models/planet_viewport.dart';
import 'package:driveit_project/features/planet/services/planet_map_repository.dart';
import 'package:driveit_project/features/planet/services/planet_map_presentation.dart';
import 'package:driveit_project/features/planet/services/planet_trace_detail_repository.dart';
import 'package:driveit_project/screens/planet_map_screen.dart';
import 'package:driveit_project/screens/planet_trace_detail_screen.dart';

final trace = PlanetTrace('a' * 32, 'style', 1000, const [
  LatLng(40, 29),
  LatLng(40, 29.002),
]);
PlanetTraceDetail detail() => PlanetTraceDetail.parse({
  'trace_id': trace.id,
  'generation': '4',
  'display_name': 'Test Sürücü',
  'username': 'test_driver',
  'drive_date': '2026-01-01T00:02:00Z',
  'distance_meters': 1000,
  'duration_seconds': 120,
  'average_speed_kmh': 30,
  'maximum_speed_kmh': 36,
  'ownership_distance_meters': 250,
  'score': {
    'displayScore': 800,
    'categories': {
      'brakingAnticipation': {
        'score': 250,
        'maximum': 350,
        'applicable': true,
        'sampleSufficient': true,
      },
      'corneringPerformance': {
        'score': 75,
        'maximum': 150,
        'applicable': false,
        'sampleSufficient': true,
      },
    },
  },
});

class Details implements PlanetTraceDetailRepository {
  int calls = 0;
  bool failed = false;
  @override
  Future<PlanetTraceDetail> read(String id) async {
    calls++;
    if (failed) throw const PlanetDetailFailure('trace_retired');
    return detail();
  }
}

class RetryDetails implements PlanetTraceDetailRepository {
  int calls = 0;
  @override
  Future<PlanetTraceDetail> read(String id) async {
    if (++calls == 1) throw const PlanetDetailFailure('detail_unavailable');
    return detail();
  }
}

class MapRepository implements PlanetMapRepository {
  @override
  Future<PlanetSnapshot> read(PlanetViewport viewport) async =>
      PlanetSnapshot(BigInt.from(4), false, [trace]);
}

void main() {
  testWidgets('detail network failure retries without stale/fake owner', (
    tester,
  ) async {
    final repository = RetryDetails();
    await tester.pumpWidget(
      MaterialApp(
        home: PlanetTraceDetailScreen(
          trace: trace,
          generation: BigInt.from(4),
          repository: repository,
          mapBuilder: (_) => const Text('map'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Sürücü'), findsNothing);
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.text('Test Sürücü'), findsOneWidget);
    expect(repository.calls, 2);
  });
  test('logical trace hit layer and geometry remain selected partial span', () {
    var taps = 0;
    final drawing = PlanetMapPresentation.draw(
      PlanetSnapshot(BigInt.from(4), false, [trace]),
      12,
      onTraceTap: (selected) {
        expect(selected, same(trace));
        taps++;
      },
    );
    expect(drawing.polylines.length, 3);
    for (final line in drawing.polylines) {
      expect(line.points, trace.geometry);
      line.onTap!();
    }
    expect(
      taps,
      3,
    ); // Screen-level single-flight guard prevents duplicate routes.
  });
  testWidgets('detail panel data, N/A, preview and independent scroll region', (
    tester,
  ) async {
    final repository = Details();
    PlanetMapDrawing? preview;
    await tester.pumpWidget(
      MaterialApp(
        home: PlanetTraceDetailScreen(
          trace: trace,
          generation: BigInt.from(4),
          repository: repository,
          mapBuilder: (drawing) {
            preview = drawing;
            return const Text('selected map');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Sürücü'), findsOneWidget);
    expect(find.text('@test_driver'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    expect(find.text('1.00 km'), findsOneWidget);
    expect(preview!.polylines.first.points, trace.geometry);
    await tester.drag(
      find.byKey(const Key('planet-detail-panel')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    expect(find.text('0.25 km'), findsOneWidget);
    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('selected map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'glow plus core callback opens only one detail; back preserves map',
    (tester) async {
      final repository = Details();
      PlanetMapDrawing? drawing;
      await tester.pumpWidget(
        MaterialApp(
          home: PlanetMapScreen(
            repository: MapRepository(),
            detailRepository: repository,
            mapBuilder: (value) {
              drawing = value;
              return const Text('map');
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump();
      final lines = drawing!.polylines.toList();
      final retainedMapDrawing = drawing!;
      lines[0].onTap!();
      lines[1].onTap!();
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(find.text('Gezegen İz Detayı'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('DriveIt Gezegeni'), findsOneWidget);
      expect(retainedMapDrawing.polylines.length, 3);
    },
  );
  testWidgets('retired trace hides stale preview without fake owner', (
    tester,
  ) async {
    final repository = Details()..failed = true;
    PlanetMapDrawing? preview;
    await tester.pumpWidget(
      MaterialApp(
        home: PlanetTraceDetailScreen(
          trace: trace,
          generation: BigInt.from(4),
          repository: repository,
          mapBuilder: (drawing) {
            preview = drawing;
            return const Text('map');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(preview!.polylines, isEmpty);
    expect(find.textContaining('artık güncel değil'), findsOneWidget);
    expect(find.text('Test Sürücü'), findsNothing);
  });
}
