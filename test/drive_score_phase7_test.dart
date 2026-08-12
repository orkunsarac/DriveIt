import 'package:driveit_project/features/drive_score/models/drive_score_result.dart';
import 'package:driveit_project/features/drive_score/services/drive_score_engine.dart';
import 'package:driveit_project/features/drive_score/services/endurance_score_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const endurance = EnduranceScoreEngine();
  const aggregator = DriveScoreEngine();
  final quality = [
    const DriveScoreCategoryStatus(
      score: 90,
      maximum: 100,
      applicable: true,
      sampleSufficient: true,
    ),
  ];
  test(
    'distance curve rewards sustained quality without free distance points',
    () {
      final a = endurance.score(distanceKm: 5, qualityCategories: quality),
          b = endurance.score(distanceKm: 50, qualityCategories: quality),
          c = endurance.score(distanceKm: 150, qualityCategories: quality),
          bad = endurance.score(
            distanceKm: 150,
            qualityCategories: [
              const DriveScoreCategoryStatus(
                score: 0,
                maximum: 100,
                applicable: true,
                sampleSufficient: true,
              ),
            ],
          );
      expect(b.totalScore, greaterThan(a.totalScore));
      expect(c.totalScore, greaterThan(b.totalScore));
      expect(a.totalScore, lessThan(150));
      expect(bad.totalScore, lessThan(c.totalScore));
    },
  );
  test('full score aggregates to 1000 and N/A normalizes', () {
    final all = {
      'b': const DriveScoreCategoryStatus(
        score: 350,
        maximum: 350,
        applicable: true,
        sampleSufficient: true,
      ),
      't': const DriveScoreCategoryStatus(
        score: 150,
        maximum: 150,
        applicable: true,
        sampleSufficient: true,
      ),
      'c': const DriveScoreCategoryStatus(
        score: 150,
        maximum: 150,
        applicable: true,
        sampleSufficient: true,
      ),
      'e': const DriveScoreCategoryStatus(
        score: 150,
        maximum: 150,
        applicable: true,
        sampleSufficient: true,
      ),
      's': const DriveScoreCategoryStatus(
        score: 100,
        maximum: 100,
        applicable: true,
        sampleSufficient: true,
      ),
      'a': const DriveScoreCategoryStatus(
        score: 50,
        maximum: 50,
        applicable: true,
        sampleSufficient: true,
      ),
      'x': const DriveScoreCategoryStatus(
        score: 50,
        maximum: 50,
        applicable: true,
        sampleSufficient: true,
      ),
    };
    expect(aggregator.aggregate(all).totalScore, 1000);
    final na = {
      ...all,
      'c': const DriveScoreCategoryStatus(
        score: 0,
        maximum: 150,
        applicable: false,
        sampleSufficient: false,
      ),
    };
    expect(aggregator.aggregate(na).totalScore, 962.5);
  });
  test('real applicable zero lowers score while insufficient does not', () {
    final base = {
      'a': const DriveScoreCategoryStatus(
        score: 50,
        maximum: 50,
        applicable: true,
        sampleSufficient: true,
      ),
      'b': const DriveScoreCategoryStatus(
        score: 50,
        maximum: 50,
        applicable: true,
        sampleSufficient: true,
      ),
    };
    final zero = {
      ...base,
      'b': const DriveScoreCategoryStatus(
        score: 0,
        maximum: 50,
        applicable: true,
        sampleSufficient: true,
      ),
    };
    final insufficient = {
      ...base,
      'b': const DriveScoreCategoryStatus(
        score: 0,
        maximum: 50,
        applicable: true,
        sampleSufficient: false,
      ),
    };
    expect(aggregator.aggregate(zero).totalScore, 50);
    expect(aggregator.aggregate(insufficient).totalScore, 87.5);
  });
}
