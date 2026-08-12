import 'dart:math' as math;

import 'package:driveit_project/features/drive_score/models/drive_score_result.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_calculator.dart';
import 'package:driveit_project/features/my_world/models/common_road_match.dart';
import 'package:driveit_project/features/my_world/models/common_road_score_comparison.dart';
import 'package:driveit_project/features/my_world/models/common_road_telemetry.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/matched_road_section.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/services/common_road_local_score_service.dart';
import 'package:driveit_project/features/my_world/services/common_road_telemetry_extractor.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = CommonRoadTelemetryExtractor();

  group('common-road telemetry extraction', () {
    test('maps a full validated overlap without using raw route distance', () {
      final road = _road('first', _line(0, 1200));
      final pair = extractor.extract(
        match: _match(distanceMeters: 1200),
        firstRoad: road,
        firstTelemetry: _telemetry(0, 1200),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      expect(pair.isUsable, isTrue);
      expect(pair.first.telemetry, hasLength(13));
      expect(pair.first.startIndex, 0);
      expect(pair.first.endIndex, 12);
    });

    test('maps only the middle common road and keeps timestamp order', () {
      final pair = extractor.extract(
        match: _match(
          firstStart: 1050,
          firstEnd: 2150,
          secondStart: 0,
          secondEnd: 1200,
          distanceMeters: 1200,
        ),
        firstRoad: _road('first', _line(0, 3000)),
        firstTelemetry: _telemetry(0, 3000),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      expect(pair.isUsable, isTrue);
      expect(pair.first.startIndex, 11);
      expect(pair.first.endIndex, 21);
      expect(pair.first.telemetry.first.longitude, closeTo(_point(1100).longitude, 1e-8));
      expect(pair.first.telemetry.last.longitude, closeTo(_point(2100).longitude, 1e-8));
    });

    test('uses nearby real samples when a common boundary falls between samples', () {
      final pair = extractor.extract(
        match: _match(firstStart: 1000, firstEnd: 1200, secondStart: 1000, secondEnd: 1200, distanceMeters: 200),
        firstRoad: _road('first', _line(0, 2000)),
        firstTelemetry: _telemetryAt(<double>[998, 1012, 1100, 1190, 1204]),
        secondRoad: _road('second', _line(0, 2000)),
        secondTelemetry: _telemetryAt(<double>[998, 1012, 1100, 1190, 1204]),
      );

      expect(pair.isUsable, isTrue);
      expect(pair.first.startIndex, 1);
      expect(pair.first.endIndex, 3);
    });

    test('does not map telemetry outside a partial matched section', () {
      final firstRoad = _roadWithSections('first', <MatchedRoadSection>[
        _section('first:a', _line(0, 1000)),
        _section('first:b', _line(2000, 3200)),
      ]);
      final secondRoad = _roadWithSections('second', <MatchedRoadSection>[
        _section('second:a', _line(0, 1000)),
        _section('second:b', _line(2000, 3200)),
      ]);
      final pair = extractor.extract(
        match: _match(
          firstSectionId: 'first:b',
          secondSectionId: 'second:b',
          firstStart: 1000,
          firstEnd: 2000,
          secondStart: 1000,
          secondEnd: 2000,
          distanceMeters: 1000,
        ),
        firstRoad: firstRoad,
        firstTelemetry: _telemetryAt(<double>[100, 500, 2050, 2200, 2800, 3150]),
        secondRoad: secondRoad,
        secondTelemetry: _telemetryAt(<double>[100, 500, 2050, 2200, 2800, 3150]),
      );

      expect(pair.isUsable, isTrue);
      expect(pair.first.startIndex, 2);
      expect(pair.first.endIndex, 4);
    });

    test('rejects empty and unmappable telemetry without creating a score input', () {
      final empty = extractor.extract(
        match: _match(distanceMeters: 1200),
        firstRoad: _road('first', _line(0, 1200)),
        firstTelemetry: const <CanonicalTelemetryPoint>[],
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );
      final unmappable = extractor.extract(
        match: _match(distanceMeters: 1200),
        firstRoad: _road('first', _line(0, 1200)),
        firstTelemetry: _telemetryAt(<double>[10_000, 10_100]),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      expect(empty.first.telemetry, isEmpty);
      expect(unmappable.first.telemetry, isEmpty);
      expect(unmappable.first.status, isNot(CommonRoadTelemetryMappingStatus.success));
    });

    test('uses heading to select the correct visit on a self-intersecting route', () {
      final revisitRoad = _road('first', <MatchedRoadPoint>[
        _point(0),
        _point(1000),
        _point(0),
      ]);
      final pair = extractor.extract(
        match: _match(
          firstStart: 1000,
          firstEnd: 2000,
          secondEnd: 1000,
          distanceMeters: 1000,
        ),
        firstRoad: revisitRoad,
        firstTelemetry: _telemetryAt(
          <double>[0, 500, 1000, 500, 0],
          headings: <double>[90, 90, 270, 270, 270],
        ),
        secondRoad: _road('second', _line(0, 1000)),
        secondTelemetry: _telemetry(0, 1000),
      );

      expect(pair.first.status, CommonRoadTelemetryMappingStatus.success);
      expect(pair.first.startIndex, 3);
      expect(pair.first.endIndex, 4);
    });
  });

  group('local Drive Score comparison', () {
    test('eligible common roads invoke the real in-memory calculator without Hive', () {
      final result = const CommonRoadLocalScoreService().compare(
        match: _match(distanceMeters: 1200),
        firstRoad: _road('first', _line(0, 1200)),
        firstTelemetry: _telemetry(0, 1200),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      expect(result.comparisonValid, isTrue);
      expect(result.firstLocalScore, isNotNull);
      expect(result.secondLocalScore, isNotNull);
    });

    test('a 999 metre match skips both extraction and calculator calls', () {
      final calculator = _SequencedCalculator(<Object>[_score(800), _score(820)]);
      final result = CommonRoadLocalScoreService(calculator: calculator).compare(
        match: _match(distanceMeters: 999, eligible: false),
        firstRoad: _road('first', _line(0, 1200)),
        firstTelemetry: _telemetry(0, 1200),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      expect(result.outcome, CommonRoadScoreComparisonOutcome.notEligible);
      expect(calculator.calls, 0);
    });

    test('uses the one percent threshold inclusively and remains generic by side', () {
      CommonRoadScoreComparison compare(double first, double second) =>
          CommonRoadLocalScoreService(
            calculator: _SequencedCalculator(<Object>[_score(first), _score(second)]),
          ).compare(
            match: _match(distanceMeters: 1200),
            firstRoad: _road('first', _line(0, 1200)),
            firstTelemetry: _telemetry(0, 1200),
            secondRoad: _road('second', _line(0, 1200)),
            secondTelemetry: _telemetry(0, 1200),
          );

      expect(compare(800, 807).outcome, CommonRoadScoreComparisonOutcome.noMeaningfulDifference);
      expect(compare(800, 808).outcome, CommonRoadScoreComparisonOutcome.secondWins);
      expect(compare(809, 800).outcome, CommonRoadScoreComparisonOutcome.firstWins);
      expect(compare(800, 800).outcome, CommonRoadScoreComparisonOutcome.noMeaningfulDifference);
    });

    test('one score calculation failure never elects the other drive as winner', () {
      final result = CommonRoadLocalScoreService(
        calculator: _SequencedCalculator(<Object>[StateError('test failure'), _score(900)]),
      ).compare(
        match: _match(distanceMeters: 1200),
        firstRoad: _road('first', _line(0, 1200)),
        firstTelemetry: _telemetry(0, 1200),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      expect(result.comparisonValid, isFalse);
      expect(result.outcome, CommonRoadScoreComparisonOutcome.calculationFailed);
      expect(result.firstLocalScore, isNull);
      expect(result.secondLocalScore, isNull);
    });

    test('the same local inputs produce the same v1 comparison result', () {
      CommonRoadScoreComparison compare() => const CommonRoadLocalScoreService().compare(
        match: _match(distanceMeters: 1200),
        firstRoad: _road('first', _line(0, 1200)),
        firstTelemetry: _telemetry(0, 1200),
        secondRoad: _road('second', _line(0, 1200)),
        secondTelemetry: _telemetry(0, 1200),
      );

      final first = compare();
      final second = compare();
      expect(first.outcome, second.outcome);
      expect(first.scoreDifference, second.scoreDifference);
      expect(first.relativeDifference, second.relativeDifference);
    });
  });
}

class _SequencedCalculator extends DriveScoreCalculator {
  _SequencedCalculator(this._results);

  final List<Object> _results;
  var calls = 0;

  @override
  DriveScoreResult calculate({
    required Iterable<CanonicalTelemetryPoint> telemetry,
    DriveScoreAlgorithmVersion algorithmVersion =
        DriveScoreAlgorithmVersion.v1,
  }) {
    final next = _results[calls++];
    if (next is Exception) throw next;
    return next as DriveScoreResult;
  }
}

DriveScoreResult _score(double value) => DriveScoreResult(
  totalScore: value,
  displayScore: value.round(),
  overallConfidence: 1,
  algorithmVersion: 1,
  categories: const <String, DriveScoreCategoryStatus>{},
  contributions: const <String, DriveScoreCategoryContribution>{},
  diagnostics: 'test',
);

CommonRoadMatch _match({
  String firstSectionId = 'first:geometry',
  String secondSectionId = 'second:geometry',
  double firstStart = 0,
  double firstEnd = 1200,
  double secondStart = 0,
  double? secondEnd,
  required double distanceMeters,
  bool eligible = true,
}) => CommonRoadMatch(
  firstDriveId: 'first-drive',
  secondDriveId: 'second-drive',
  firstSectionId: firstSectionId,
  secondSectionId: secondSectionId,
  firstStartOffsetMeters: firstStart,
  firstEndOffsetMeters: firstEnd,
  secondStartOffsetMeters: secondStart,
  secondEndOffsetMeters: secondEnd ?? firstEnd,
  commonStart: _point(0),
  commonEnd: _point(distanceMeters),
  commonDistanceMeters: distanceMeters,
  directionCompatible: true,
  geometryConfidence: 1,
  comparisonEligible: eligible,
  referenceGeometry: _line(0, distanceMeters),
);

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
      validDistanceMeters: sections.fold<double>(
        0,
        (total, section) => total + section.distanceMeters,
      ),
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

List<CanonicalTelemetryPoint> _telemetry(double start, double end) =>
    _telemetryAt(List<double>.generate(
      ((end - start) / 100).round() + 1,
      (index) => start + index * 100,
    ));

List<CanonicalTelemetryPoint> _telemetryAt(
  List<double> positions, {
  List<double>? headings,
}) => List<CanonicalTelemetryPoint>.generate(
  positions.length,
  (index) => CanonicalTelemetryPoint(
    latitude: _point(positions[index]).latitude,
    longitude: _point(positions[index]).longitude,
    timestamp: DateTime.utc(2026, 8, 12).add(Duration(seconds: index * 10)),
    speedMps: 15,
    headingDegrees: headings?[index] ?? 90,
    altitudeMeters: 0,
    accuracyMeters: 5,
    distanceFromPreviousMeters: index == 0 ? 0 : (positions[index] - positions[index - 1]).abs(),
    accelerationMps2: 0,
  ),
);

List<MatchedRoadPoint> _line(double start, double end) => <MatchedRoadPoint>[
  _point(start),
  _point(end),
];

MatchedRoadPoint _point(double xMeters) => MatchedRoadPoint(
  latitude: 41,
  longitude: 29 + xMeters / (111320 * math.cos(41 * math.pi / 180)),
  headingDegrees: 90,
);

double _distance(List<MatchedRoadPoint> points) {
  var result = 0.0;
  for (var index = 1; index < points.length; index++) {
    final latitudeDistance = (points[index].latitude - points[index - 1].latitude) * 111320;
    final longitudeDistance = (points[index].longitude - points[index - 1].longitude) * 84000;
    result += math.sqrt(latitudeDistance * latitudeDistance + longitudeDistance * longitudeDistance);
  }
  return result;
}
