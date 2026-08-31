import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/services/world_road_overlap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const overlap = WorldRoadOverlapService();

  test('same road in the same direction returns an eligible full overlap', () {
    final matches = overlap.findCommonRoads(
      _road('first', _line(0, 3200)),
      _road('second', _line(0, 3200)),
    );

    expect(matches, hasLength(1));
    expect(matches.single.directionCompatible, isTrue);
    expect(matches.single.commonDistanceMeters, closeTo(3200, 35));
    expect(matches.single.comparisonEligible, isTrue);
  });

  test('same geometry in reverse direction is not a common World road', () {
    final matches = overlap.findCommonRoads(
      _road('first', _line(0, 1200)),
      _road('second', _line(0, 1200).reversed.toList()),
    );

    expect(matches, isEmpty);
  });

  test('middle-only overlap exposes independent road-distance offsets', () {
    final matches = overlap.findCommonRoads(
      _road('first', _line(0, 3000)),
      _road('second', _line(1000, 2200)),
    );

    expect(matches, hasLength(1));
    final match = matches.single;
    expect(match.firstStartOffsetMeters, closeTo(1000, 35));
    expect(match.firstEndOffsetMeters, closeTo(2200, 35));
    expect(match.secondStartOffsetMeters, closeTo(0, 35));
    expect(match.secondEndOffsetMeters, closeTo(1200, 35));
  });

  test('a 300 metre common road is detected but not comparison eligible', () {
    final matches = overlap.findCommonRoads(
      _road('first', _line(0, 300)),
      _road('second', _line(0, 300)),
    );

    expect(matches, hasLength(1));
    expect(matches.single.comparisonEligible, isFalse);
  });

  test('2999 and 3000 metre boundaries use the central eligibility rule', () {
    final below = overlap.findCommonRoads(
      _road('first', _line(0, 2999)),
      _road('second', _line(0, 2999)),
    );
    final at = overlap.findCommonRoads(
      _road('first', _line(0, 3200)),
      _road('second', _line(0, 3200)),
    );

    expect(below.single.comparisonEligible, isFalse);
    expect(at.single.comparisonEligible, isTrue);
  });

  test('parallel roads and short intersection-only contact do not match', () {
    final parallel = overlap.findCommonRoads(
      _road('first', _line(0, 1200)),
      _road('second', _line(0, 1200, yMeters: 35)),
    );
    final crossing = overlap.findCommonRoads(
      _road('first', _line(0, 1200)),
      _road('second', [_point(600, -250), _point(600, 250)]),
    );

    expect(parallel, isEmpty);
    expect(crossing, isEmpty);
  });

  test('small Mapbox geometry variation and point density remain matchable', () {
    final dense = List.generate(49, (index) => _point(index * 25.0, 6));
    final matches = overlap.findCommonRoads(
      _road('first', _line(0, 1200)),
      _road('second', dense),
    );

    expect(matches, hasLength(1));
    expect(matches.single.commonDistanceMeters, greaterThan(1100));
  });

  test('disconnected matched sections produce separate common matches', () {
    final first = _roadWithSections('first', [
      _section('a', _line(0, 500)),
      _section('b', _line(1000, 1500)),
    ]);
    final second = _roadWithSections('second', [
      _section('x', _line(0, 500)),
      _section('y', _line(1000, 1500)),
    ]);

    final matches = overlap.findCommonRoads(first, second);

    expect(matches, hasLength(2));
    expect(matches.map((match) => match.commonDistanceMeters),
        everyElement(closeTo(500, 35)));
  });

  test('empty and one-point validated geometry are safe', () {
    expect(overlap.findCommonRoads(_road('empty', []), _road('other', _line(0, 500))), isEmpty);
    expect(
      overlap.findCommonRoads(
        _road('one', [_point(0)]),
        _road('other', _line(0, 500)),
      ),
      isEmpty,
    );
  });
}

ValidatedRoad _road(String id, List<MatchedRoadPoint> geometry) => ValidatedRoad(
  id: id,
  driveSessionId: '$id-drive',
  geometry: geometry,
  validDistanceMeters: _distance(geometry),
  status: RoadValidationStatus.validated,
  validatedAt: DateTime.utc(2026, 8, 12),
  providerId: 'test',
  confidence: 1,
  processingVersion: 2,
  directionKey: id,
  averageHeadingDegrees: 90,
  createdAt: DateTime.utc(2026, 8, 12),
  updatedAt: DateTime.utc(2026, 8, 12),
);

ValidatedRoad _roadWithSections(String id, List<MatchedRoadSection> sections) =>
    ValidatedRoad(
      id: id,
      driveSessionId: '$id-drive',
      geometry: sections.expand((section) => section.geometry).toList(),
      sections: sections,
      validDistanceMeters:
          sections.fold(0, (sum, section) => sum + section.distanceMeters),
      status: RoadValidationStatus.partiallyValidated,
      validatedAt: DateTime.utc(2026, 8, 12),
      providerId: 'test',
      confidence: 1,
      processingVersion: 2,
      directionKey: id,
      averageHeadingDegrees: 90,
      createdAt: DateTime.utc(2026, 8, 12),
      updatedAt: DateTime.utc(2026, 8, 12),
    );

MatchedRoadSection _section(String id, List<MatchedRoadPoint> geometry) =>
    MatchedRoadSection(
      id: id,
      geometry: geometry,
      distanceMeters: _distance(geometry),
      confidence: 1,
      sourceTraceIndex: 0,
      sourceChunkIndex: 0,
    );

List<MatchedRoadPoint> _line(
  double startMeters,
  double endMeters, {
  double yMeters = 0,
}) => [_point(startMeters, yMeters), _point(endMeters, yMeters)];

MatchedRoadPoint _point(double xMeters, [double yMeters = 0]) => MatchedRoadPoint(
  latitude: 41 + yMeters / 111320,
  longitude: 29 + xMeters / 84000,
  headingDegrees: 90,
);

double _distance(List<MatchedRoadPoint> points) {
  var result = 0.0;
  for (var index = 1; index < points.length; index++) {
    final first = points[index - 1];
    final second = points[index];
    final latitudeDistance = (second.latitude - first.latitude) * 111320;
    final longitudeDistance = (second.longitude - first.longitude) * 84000;
    result += (latitudeDistance * latitudeDistance +
            longitudeDistance * longitudeDistance)
        .sqrt();
  }
  return result;
}

extension on double {
  double sqrt() => this <= 0 ? 0 : _sqrt(this);
}

double _sqrt(double value) {
  var estimate = value;
  for (var index = 0; index < 12; index++) {
    estimate = (estimate + value / estimate) / 2;
  }
  return estimate;
}
