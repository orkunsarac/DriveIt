import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driveit_project/features/planet/models/planet_viewport.dart';
import 'package:driveit_project/features/planet/services/planet_map_controller.dart';
import 'package:driveit_project/features/planet/services/planet_map_repository.dart';
import 'package:driveit_project/features/planet/services/planet_map_presentation.dart';
import 'package:driveit_project/features/my_world/services/world_trace_presentation_service.dart';
import 'package:driveit_project/screens/planet_map_screen.dart';

class FakePlanet implements PlanetMapRepository {
  final requests = <Completer<PlanetSnapshot>>[];
  @override
  Future<PlanetSnapshot> read(PlanetViewport v) {
    final c = Completer<PlanetSnapshot>();
    requests.add(c);
    return c.future;
  }
}

PlanetSnapshot data(int generation, {bool empty = false}) => PlanetSnapshot(
  BigInt.from(generation),
  false,
  empty
      ? []
      : [
          PlanetTrace('id', 'style', 5000, const [
            LatLng(0, 0),
            LatLng(0, .03),
          ]),
        ],
);
void main() {
  testWidgets('lower authoritative generation cannot replace newer viewport', (
    tester,
  ) async {
    final repo = FakePlanet(), c = PlanetMapController(FakePlanet());
    c.dispose();
    final controller = PlanetMapController(repo);
    controller.cameraIdle(const PlanetViewport(0, .1, 0, .1, 12));
    await tester.pump(const Duration(milliseconds: 301));
    repo.requests.last.complete(data(3));
    await tester.pump();
    controller.retry();
    await tester.pump(const Duration(milliseconds: 301));
    repo.requests.last.complete(data(2));
    await tester.pump();
    expect(controller.snapshot!.generation, BigInt.from(3));
    expect(controller.error, isNotNull);
    controller.dispose();
  });
  test('bounded synthetic parse/render measurement: 50 traces x 573 points', () {
    final body = {
      'generation': '2',
      'state': 'ready',
      'traces': List.generate(
        50,
        (i) => {
          'id': 'synthetic:$i',
          'style_key': 'owner:$i',
          'distance_meters': '6998.4',
          'geometry': {
            'type': 'LineString',
            'coordinates': List.generate(
              573,
              (j) => [29 + j * .00001, 40 + i * .00001],
            ),
          },
        },
      ),
    };
    final json = jsonEncode(body), watch = Stopwatch()..start();
    final snapshot = PlanetSnapshot.parse(jsonDecode(json));
    final parseUs = watch.elapsedMicroseconds;
    final drawing = PlanetMapPresentation.draw(snapshot, 12);
    final renderUs = watch.elapsedMicroseconds - parseUs;
    expect(drawing.polylines.length, 100);
    expect(drawing.circles.length, 100);
    // Synthetic coordinates only; never print actual read geometry/identity.
    debugPrint(
      'PLANET_SYNTHETIC bytes=${utf8.encode(json).length} parse_us=$parseUs render_us=$renderUs',
    );
  });
  test(
    'contract rejects bad geometry/duplicates/private fields not needed',
    () {
      final body = {
        'generation': '2',
        'state': 'ready',
        'traces': [
          {
            'id': 'opaque',
            'style_key': 'opaque',
            'distance_meters': '1000',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [29, 40],
                [29.1, 40.1],
              ],
            },
          },
        ],
      };
      final parsed = PlanetSnapshot.parse(body);
      expect(parsed.traces.single.geometry.first, const LatLng(40, 29));
      (body['traces'] as List).add((body['traces'] as List).first);
      expect(() => PlanetSnapshot.parse(body), throwsFormatException);
    },
  );
  testWidgets(
    'stale viewport, identical cache, generation replacement, dispose',
    (tester) async {
      final repo = FakePlanet(), controller = PlanetMapController(FakePlanet());
      controller.dispose();
      final c = PlanetMapController(repo);
      const a = PlanetViewport(0, .1, 0, .1, 12),
          b = PlanetViewport(0, .1, .1, .2, 12);
      c.cameraIdle(a);
      await tester.pump(const Duration(milliseconds: 301));
      c.cameraIdle(b);
      await tester.pump(const Duration(milliseconds: 301));
      repo.requests[1].complete(data(3));
      await tester.pump();
      repo.requests[0].complete(data(2));
      await tester.pump();
      expect(c.snapshot!.generation, BigInt.from(3));
      c.cameraIdle(b);
      await tester.pump(const Duration(milliseconds: 301));
      expect(repo.requests.length, 2);
      c.retry();
      await tester.pump(const Duration(milliseconds: 301));
      repo.requests.last.complete(data(4, empty: true));
      await tester.pump();
      expect(c.snapshot!.traces, isEmpty);
      c.retry();
      await tester.pump(const Duration(milliseconds: 301));
      c.dispose();
      repo.requests.last.complete(data(5));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('map load, empty, server failure and retry', (tester) async {
    final repo = FakePlanet();
    await tester.pumpWidget(
      MaterialApp(
        home: PlanetMapScreen(
          repository: repo,
          mapBuilder: (drawing) => Text('lines:${drawing.polylines.length}'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 301));
    repo.requests.last.complete(data(2));
    await tester.pump();
    expect(find.text('lines:2'), findsOneWidget);
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pump(const Duration(milliseconds: 301));
    repo.requests.last.completeError(const PlanetReadFailure('Test error'));
    await tester.pump();
    expect(find.text('Tekrar Dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pump(const Duration(milliseconds: 301));
    repo.requests.last.complete(data(3, empty: true));
    await tester.pump();
    expect(find.text('Bu bölgede henüz gezegen izi yok.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'shared opposite offset/corner math, no ownership geometry mutation',
    () {
      const service = WorldTracePresentationService();
      const forward = [LatLng(0, 0), LatLng(0, .01)],
          reverse = [LatLng(0, .01), LatLng(0, 0)];
      expect(service.oppositeGeometry(forward, reverse), isTrue);
      final drawn = PlanetMapPresentation.draw(
        PlanetSnapshot(BigInt.two, false, [
          PlanetTrace('a', 'a', 1000, forward),
          PlanetTrace('b', 'b', 1000, reverse),
        ]),
        12,
      );
      expect(drawn.polylines.length, 4);
      expect(drawn.circles.length, 4);
      expect(
        drawn.polylines.first.points,
        service.renderPoints(
          id: 'a',
          points: forward,
          separateOpposite: true,
          zoom: 12,
          partnerId: 'b',
          partnerPoints: reverse,
        ),
      );
      expect(forward.first, const LatLng(0, 0));
    },
  );
}
