import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/drive_route_presentation.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'local_lifecycle_foundation_test.dart' as fixtures;

List<RoutePoint> route(int parts) => [
  for (var i = 0; i < parts; i++) ...[
    RoutePoint(latitude: 40 + i * .01, longitude: 29, breakBefore: i > 0),
    RoutePoint(latitude: 40 + i * .01 + .001, longitude: 29),
  ],
];

void main() {
  test('uninterrupted geometry has no gap and is not mutated', () {
    final points = route(1);
    expect(DriveRoutePresentation(points).gaps, isEmpty);
    expect(routeSegments(points).single, points);
  });
  for (final count in [2, 3]) {
    test(
      '$count reliable parts retain exact endpoints with ${count - 1} visual gaps',
      () {
        final points = route(count);
        final segments = routeSegments(points);
        final presentation = DriveRoutePresentation(points);
        expect(presentation.gaps.length, count - 1);
        for (var i = 0; i < count - 1; i++) {
          expect(identical(presentation.gaps[i].first, segments[i].last), true);
          expect(
            identical(presentation.gaps[i].last, segments[i + 1].first),
            true,
          );
        }
        expect(routeSegments(points), segments);
      },
    );
  }
  test('invalid or isolated endpoint never manufactures a connection', () {
    for (final bad in [double.nan, double.infinity, 91.0]) {
      final points = route(2);
      points[1].latitude = bad;
      expect(DriveRoutePresentation(points).gaps, isEmpty);
    }
    expect(
      DriveRoutePresentation([route(2)[0], route(2)[2], route(2)[3]]).gaps,
      isEmpty,
    );
  });
  test('distance alone cannot infer a missing section in legacy geometry', () {
    final points = route(2);
    points[2].breakBefore = false;
    expect(DriveRoutePresentation(points).gaps, isEmpty);
  });
  test(
    'independent snapshot geometry, score and distance stay byte-equivalent',
    () {
      final source = fixtures.fixture('snapshot');
      source.drive.route = route(3);
      final before = jsonEncode(source.toMap());
      final restored = LocalSourceBundle.fromMap(jsonDecode(before));
      expect(DriveRoutePresentation(restored.drive.route).gaps, hasLength(2));
      expect(jsonEncode(restored.toMap()), before);
      expect(jsonEncode(source.toMap()), before);
    },
  );
  test('large routes use one linear projection without added route points', () {
    final points = route(10000);
    for (var i = 0; i < points.length; i++) {
      points[i].latitude = 40 + (i % 1000) * .00001;
    }
    final timer = Stopwatch()..start();
    final p = DriveRoutePresentation(points);
    timer.stop();
    expect(p.gaps, hasLength(9999));
    expect(points, hasLength(20000));
    expect(timer.elapsed.inSeconds, lessThan(5));
  });
}
