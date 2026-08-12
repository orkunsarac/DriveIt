import 'dart:math' as math;

import 'package:driveit_project/features/drive_score/models/drive_score_algorithm_version.dart';
import 'package:driveit_project/features/drive_score/models/drive_score_result.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_calculator.dart';
import 'package:driveit_project/features/my_world/models/common_road_match.dart';
import 'package:driveit_project/features/my_world/models/local_winning_road_region.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/services/common_road_local_score_service.dart';
import 'package:driveit_project/features/my_world/services/local_winning_road_region_service.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5 local winner-region detection', () {
    test('a challenger better across two kilometres produces one region', () {
      final result = _analyze(<_WindowKind>[
        ...List<_WindowKind>.filled(20, _WindowKind.challenger),
      ]);

      expect(result.status, LocalRoadRegionAnalysisStatus.success);
      expect(result.winningRegions, hasLength(1));
      expect(result.winningRegions.single.winningDistanceMeters, closeTo(2000, 2));
      expect(result.winningRegions.single.supportingWindowCount, 20);
    });

    test('less than one percent, equal, and existing-better windows do not win', () {
      final result = _analyze(<_WindowKind>[
        ...List<_WindowKind>.filled(5, _WindowKind.neutral),
        ...List<_WindowKind>.filled(5, _WindowKind.existing),
        ...List<_WindowKind>.filled(5, _WindowKind.equal),
      ]);

      expect(result.winningRegions, isEmpty);
      expect(result.windows.map((window) => window.state), containsAll(<LocalRoadWindowState>[
        LocalRoadWindowState.noMeaningfulDifference,
        LocalRoadWindowState.existingBetter,
      ]));
    });

    test('a 300 metre challenger run is discarded while exactly 500 metres wins', () {
      final short = _analyze(List<_WindowKind>.filled(3, _WindowKind.challenger));
      final exact = _analyze(List<_WindowKind>.filled(5, _WindowKind.challenger));

      expect(short.winningRegions, isEmpty);
      expect(exact.winningRegions, hasLength(1));
      expect(exact.winningRegions.single.winningDistanceMeters, closeTo(500, 2));
    });

    test('a neutral 100 metre gap merges challenger runs', () {
      final result = _analyze(<_WindowKind>[
        ...List<_WindowKind>.filled(4, _WindowKind.challenger),
        _WindowKind.neutral,
        ...List<_WindowKind>.filled(4, _WindowKind.challenger),
      ]);

      expect(result.winningRegions, hasLength(1));
      expect(result.winningRegions.single.winningDistanceMeters, closeTo(900, 2));
    });

    test('a 300 metre gap does not merge two sub-500 metre challenger runs', () {
      final result = _analyze(<_WindowKind>[
        ...List<_WindowKind>.filled(4, _WindowKind.challenger),
        ...List<_WindowKind>.filled(3, _WindowKind.invalid),
        ...List<_WindowKind>.filled(4, _WindowKind.challenger),
      ]);

      expect(result.winningRegions, isEmpty);
    });

    test('a 200 metre invalid gap is tolerated but a 201 metre physical gap is not', () {
      final tolerated = _analyze(<_WindowKind>[
        ...List<_WindowKind>.filled(7, _WindowKind.challenger),
        ...List<_WindowKind>.filled(2, _WindowKind.invalid),
        ...List<_WindowKind>.filled(8, _WindowKind.challenger),
      ]);
      final notTolerated = _analyze(
        <_WindowKind>[
          ...List<_WindowKind>.filled(4, _WindowKind.challenger),
          ...List<_WindowKind>.filled(2, _WindowKind.invalid),
          _WindowKind.invalidShort,
          ...List<_WindowKind>.filled(4, _WindowKind.challenger),
        ],
        commonDistanceMeters: 1001,
      );

      expect(tolerated.winningRegions, hasLength(1));
      expect(tolerated.winningRegions.single.winningDistanceMeters, closeTo(1700, 2));
      expect(notTolerated.winningRegions, isEmpty);
    });

    test('multiple winner regions retain both drives physical offsets', () {
      final result = _analyze(<_WindowKind>[
        ...List<_WindowKind>.filled(6, _WindowKind.challenger),
        ...List<_WindowKind>.filled(3, _WindowKind.existing),
        ...List<_WindowKind>.filled(7, _WindowKind.challenger),
      ], firstOffsetStart: 8800, secondOffsetStart: 3700);

      expect(result.winningRegions, hasLength(2));
      expect(result.winningRegions.first.startOffsetOnExistingMeters, closeTo(8800, 2));
      expect(result.winningRegions.first.endOffsetOnExistingMeters, closeTo(9400, 2));
      expect(result.winningRegions.last.startOffsetOnChallengerMeters, closeTo(4600, 2));
      expect(result.winningRegions.last.endOffsetOnChallengerMeters, closeTo(5300, 2));
    });

    test('a 1050 metre match has a deterministic short final window', () {
      final result = _analyze(
        List<_WindowKind>.filled(11, _WindowKind.challenger),
        commonDistanceMeters: 1050,
      );

      expect(result.windows, hasLength(11));
      expect(result.windows.last.distanceMeters, closeTo(50, 2));
      expect(result.winningRegions.single.winningDistanceMeters, closeTo(1050, 2));
    });

    test('a below-one-kilometre common match is skipped before score calls', () {
      final calculator = _WindowCalculator(<Object>[_score(800), _score(808)]);
      final service = LocalWinningRoadRegionService(
        localScoreService: CommonRoadLocalScoreService(calculator: calculator),
      );
      final result = service.analyze(
        match: _match(999, eligible: false),
        existingRoad: _road('first', 999),
        existingTelemetry: _telemetry(999),
        challengerRoad: _road('second', 999),
        challengerTelemetry: _telemetry(999),
      );

      expect(result.status, LocalRoadRegionAnalysisStatus.notEligible);
      expect(calculator.calls, 0);
    });
  });
}

enum _WindowKind { challenger, existing, neutral, equal, invalid, invalidShort }

LocalWinningRoadRegionAnalysis _analyze(
  List<_WindowKind> kinds, {
  double? commonDistanceMeters,
  double firstOffsetStart = 0,
  double secondOffsetStart = 0,
}) {
  final length = commonDistanceMeters ?? kinds.length * 100.0;
  final results = <Object>[];
  for (final kind in kinds) {
    switch (kind) {
      case _WindowKind.challenger:
        results.addAll(<Object>[_score(800), _score(808)]);
      case _WindowKind.existing:
        results.addAll(<Object>[_score(808), _score(800)]);
      case _WindowKind.neutral:
        results.addAll(<Object>[_score(800), _score(807.92)]);
      case _WindowKind.equal:
        results.addAll(<Object>[_score(800), _score(800)]);
      case _WindowKind.invalid:
      case _WindowKind.invalidShort:
        results.addAll(<Object>[StateError('invalid local score'), _score(808)]);
    }
  }
  final calculator = _WindowCalculator(results);
  final service = LocalWinningRoadRegionService(
    localScoreService: CommonRoadLocalScoreService(calculator: calculator),
  );
  return service.analyze(
    match: _match(
      length,
      firstOffsetStart: firstOffsetStart,
      secondOffsetStart: secondOffsetStart,
    ),
    existingRoad: _road('first', length + firstOffsetStart),
    existingTelemetry: _telemetry(length + firstOffsetStart),
    challengerRoad: _road('second', length + secondOffsetStart),
    challengerTelemetry: _telemetry(length + secondOffsetStart),
  );
}

class _WindowCalculator extends DriveScoreCalculator {
  _WindowCalculator(this._results);

  final List<Object> _results;
  var calls = 0;

  @override
  DriveScoreResult calculate({
    required Iterable<CanonicalTelemetryPoint> telemetry,
    DriveScoreAlgorithmVersion algorithmVersion =
        DriveScoreAlgorithmVersion.v1,
  }) {
    final result = _results[calls++];
    if (result is StateError) {
      // A local comparison stops after its first failing side. Consume the
      // paired fixture value so following physical windows stay aligned.
      if (calls < _results.length) {
        calls += 1;
      }
      throw result;
    }
    return result as DriveScoreResult;
  }
}

DriveScoreResult _score(double total) => DriveScoreResult(
  totalScore: total,
  displayScore: total.round(),
  overallConfidence: 1,
  algorithmVersion: 1,
  categories: const <String, DriveScoreCategoryStatus>{},
  contributions: const <String, DriveScoreCategoryContribution>{},
  diagnostics: 'test',
);

CommonRoadMatch _match(
  double distanceMeters, {
  bool eligible = true,
  double firstOffsetStart = 0,
  double secondOffsetStart = 0,
}) => CommonRoadMatch(
  firstDriveId: 'first-drive',
  secondDriveId: 'second-drive',
  firstSectionId: 'first:geometry',
  secondSectionId: 'second:geometry',
  firstStartOffsetMeters: firstOffsetStart,
  firstEndOffsetMeters: firstOffsetStart + distanceMeters,
  secondStartOffsetMeters: secondOffsetStart,
  secondEndOffsetMeters: secondOffsetStart + distanceMeters,
  commonStart: _point(0),
  commonEnd: _point(distanceMeters),
  commonDistanceMeters: distanceMeters,
  directionCompatible: true,
  geometryConfidence: 1,
  comparisonEligible: eligible,
  referenceGeometry: <MatchedRoadPoint>[_point(0), _point(distanceMeters)],
);

ValidatedRoad _road(String id, double endMeters) => ValidatedRoad(
  id: id,
  driveSessionId: '$id-drive',
  geometry: <MatchedRoadPoint>[_point(0), _point(endMeters)],
  validDistanceMeters: endMeters,
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

List<CanonicalTelemetryPoint> _telemetry(double endMeters) =>
    List<CanonicalTelemetryPoint>.generate(
      (endMeters / 50).ceil() + 1,
      (index) {
        final position = math.min(index * 50.0, endMeters);
        return CanonicalTelemetryPoint(
          latitude: _point(position).latitude,
          longitude: _point(position).longitude,
          timestamp: DateTime.utc(2026, 8, 12).add(Duration(seconds: index * 5)),
          speedMps: 15,
          headingDegrees: 90,
          altitudeMeters: 0,
          accuracyMeters: 5,
          distanceFromPreviousMeters: index == 0 ? 0 : 50,
          accelerationMps2: 0,
        );
      },
    );

MatchedRoadPoint _point(double meters) => MatchedRoadPoint(
  latitude: 41,
  longitude: 29 + meters / (111320 * math.cos(41 * math.pi / 180)),
  headingDegrees: 90,
);
