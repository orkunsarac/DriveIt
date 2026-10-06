// The standalone adapter and its domain imports must share Dart library identity.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/my_world/models/active_world_trace.dart';
import '../lib/features/my_world/services/active_world_coverage.dart';
import '../lib/features/my_world/services/world_section_offset_mapper.dart';
import '../tool/world_scoring_adapter.dart';

void main() {
  final cases =
      jsonDecode(
            File('test/fixtures/active_world_scoring.json').readAsStringSync(),
          )
          as List;
  Json fixture(String name) =>
      cases.firstWhere((c) => c['name'] == name) as Json;
  test('A: 4000 geometry / 5000 canonical maps [2400,2600] to [1920,2080]', () {
    expect(
      WorldSectionOffsetMapper.geometryOffsetForCanonical(
        canonicalOffsetMeters: 2400,
        geometryLengthMeters: 4000,
        sectionLengthMeters: 5000,
      ),
      1920,
    );
    expect(
      WorldSectionOffsetMapper.geometryOffsetForCanonical(
        canonicalOffsetMeters: 2600,
        geometryLengthMeters: 4000,
        sectionLengthMeters: 5000,
      ),
      2080,
    );
    final c = fixture('SEM-A-geometry4000-canonical5000');
    final result = evaluateWorldScoring(c);
    expect(result['status'], 'success');
    expect(result['firstExtraction']['startIndex'], inInclusiveRange(192, 193));
    expect(result['firstExtraction']['endIndex'], inInclusiveRange(207, 208));
    // Physical middle = 2000m, never the old 2500m geometry location.
    expect(result['firstExtraction']['startIndex'], lessThan(200));
    expect(result['firstExtraction']['endIndex'], greaterThan(200));
    final unequal = Map<String, dynamic>.from(c['match']);
    unequal.addAll({
      'firstStartOffsetMeters': 0,
      'firstEndOffsetMeters': 5000,
      'secondStartOffsetMeters': 0,
      'secondEndOffsetMeters': 4000,
    });
    final clipped = ActiveWorldCoverage.clip(
      decodeMatch(unequal),
      trace(2400, 2600),
    )!;
    expect(clipped.secondStartOffsetMeters, 1920);
    expect(clipped.secondEndOffsetMeters, 2080);
    expect(clipped.commonDistanceMeters, 160);
  });
  test(
    'cumulative prefix uses canonical lengths and geometry fallback consistently',
    () {
      for (final name in ['SEM-multi-cumulative', 'SEM-prefix-fallback']) {
        final result = evaluateWorldScoring(fixture(name));
        expect(result['status'], 'success');
        expect(
          result['firstExtraction']['startIndex'],
          inInclusiveRange(380, 381),
        );
        expect(
          result['firstExtraction']['endIndex'],
          inInclusiveRange(399, 400),
        );
      }
    },
  );
  test(
    'B: inactive full match cannot make 2000 active metres performance eligible',
    () {
      final c = fixture('A-challenger-better');
      final raw = decodeMatch(c['match']);
      final bounded = ActiveWorldCoverage.clip(raw, trace(1000, 3000))!;
      expect(raw.comparisonEligible, isTrue);
      expect(bounded.commonDistanceMeters, 2000);
      expect(bounded.comparisonEligible, isFalse);
      final input = jsonDecode(jsonEncode(c)) as Json;
      input['match'].addAll({
        'firstStartOffsetMeters': bounded.firstStartOffsetMeters,
        'firstEndOffsetMeters': bounded.firstEndOffsetMeters,
        'secondStartOffsetMeters': bounded.secondStartOffsetMeters,
        'secondEndOffsetMeters': bounded.secondEndOffsetMeters,
        'commonDistanceMeters': bounded.commonDistanceMeters,
        'comparisonEligible': bounded.comparisonEligible,
      });
      expect(evaluateWorldScoring(input)['winningRegions'], isEmpty);
    },
  );
  test(
    'exact active 2999/3000 boundary, opposite direction and no intersection',
    () {
      final raw = decodeMatch(fixture('A-challenger-better')['match']);
      expect(
        ActiveWorldCoverage.clip(raw, trace(500, 3499))!.comparisonEligible,
        isFalse,
      );
      expect(
        ActiveWorldCoverage.clip(raw, trace(500, 3500))!.comparisonEligible,
        isTrue,
      );
      expect(ActiveWorldCoverage.clip(raw, trace(5000, 6000)), isNull);
      final reversed = Map<String, dynamic>.from(
        fixture('A-challenger-better')['match'],
      );
      reversed['directionCompatible'] = false;
      expect(
        ActiveWorldCoverage.clip(decodeMatch(reversed), trace(500, 3500)),
        isNull,
      );
    },
  );
}

ActiveWorldTrace trace(double start, double end) => ActiveWorldTrace(
  id: 'synthetic',
  sourceDriveSessionId: 'first-drive',
  validatedRoadId: 'first',
  matchedSectionId: 'first-section',
  startOffsetMeters: start,
  endOffsetMeters: end,
  directionKey: 'east',
  minLatitude: 0,
  maxLatitude: 0,
  minLongitude: 0,
  maxLongitude: .04,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  processingVersion: 3,
);
