import '../config/endurance_score_calibration.dart';
import '../models/endurance_score_models.dart';
import '../models/drive_score_result.dart';

class EnduranceScoreEngine {
  const EnduranceScoreEngine();
  EnduranceScoreResult score({
    required double distanceKm,
    required Iterable<DriveScoreCategoryStatus> qualityCategories,
  }) {
    final usable = qualityCategories
        .where((x) => x.applicable && x.sampleSufficient)
        .toList();
    if (distanceKm < EnduranceScoreCalibration.minimumMeaningfulDistanceKm ||
        usable.isEmpty) {
      return EnduranceScoreResult(
        totalScore: 0,
        distanceKm: distanceKm,
        distancePotential: 0,
        sustainedQualityFactor: 0,
        qualityConfidence: usable.length / 6,
        applicable: false,
        sampleSufficient: false,
        diagnostics: 'Insufficient distance or quality evidence.',
      );
    }
    final potential = _potential(distanceKm);
    final quality =
        (usable.map((x) => x.score / x.maximum).reduce((a, b) => a + b) /
                usable.length)
            .clamp(EnduranceScoreCalibration.qualityFloor, 1)
            .toDouble();
    return EnduranceScoreResult(
      totalScore: potential * quality * EnduranceScoreCalibration.maximumScore,
      distanceKm: distanceKm,
      distancePotential: potential,
      sustainedQualityFactor: quality,
      qualityConfidence: (usable.length / 6).clamp(0, 1).toDouble(),
      applicable: true,
      sampleSufficient:
          distanceKm >= EnduranceScoreCalibration.highPotentialDistanceKm &&
          usable.length >= 3,
      diagnostics: 'Distance potential and sustained category quality.',
    );
  }

  double _potential(double km) {
    if (km <= 5) {
      return km / 5 * .15;
    }
    if (km <= 50) {
      return .15 + (km - 5) / 45 * .6;
    }
    return (.75 + (km - 50) / 100 * .25).clamp(0, 1).toDouble();
  }
}
