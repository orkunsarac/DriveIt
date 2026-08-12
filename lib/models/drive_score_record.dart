import '../features/drive_score/models/drive_score_result.dart';

/// Immutable, versioned snapshot of a calculated Drive Score.
///
/// This intentionally lives outside [DriveSession] so legacy drive records and
/// their Hive field layout remain unchanged.
class DriveScoreRecord {
  static const int currentAlgorithmVersion = 1;

  final String driveId;
  final int algorithmVersion;
  final int telemetryDataVersion;
  final DateTime calculatedAt;
  final double totalScore;
  final double overallConfidence;
  final List<DriveScoreCategoryRecord> categories;

  const DriveScoreRecord({
    required this.driveId,
    required this.algorithmVersion,
    required this.telemetryDataVersion,
    required this.calculatedAt,
    required this.totalScore,
    required this.overallConfidence,
    required this.categories,
  });

  factory DriveScoreRecord.fromResult({
    required String driveId,
    required int telemetryDataVersion,
    required DateTime calculatedAt,
    required DriveScoreResult result,
  }) {
    final categories = result.categories.entries.map((entry) {
      final contribution = result.contributions[entry.key];
      if (contribution == null) {
        throw ArgumentError('Missing contribution for ${entry.key}.');
      }
      return DriveScoreCategoryRecord(
        categoryKey: entry.key,
        rawScore: entry.value.score,
        maximum: entry.value.maximum,
        applicable: entry.value.applicable,
        sampleSufficient: entry.value.sampleSufficient,
        contributionUsed: contribution.contribution,
        contributionSource: contribution.source,
      );
    }).toList(growable: false);
    return DriveScoreRecord(
      driveId: driveId,
      algorithmVersion: result.algorithmVersion,
      telemetryDataVersion: telemetryDataVersion,
      calculatedAt: calculatedAt,
      totalScore: result.totalScore,
      overallConfidence: result.overallConfidence,
      categories: List.unmodifiable(categories),
    );
  }
}

class DriveScoreCategoryRecord {
  final String categoryKey;
  final double rawScore;
  final double maximum;
  final bool applicable;
  final bool sampleSufficient;
  final double contributionUsed;
  final DriveScoreContributionSource contributionSource;

  const DriveScoreCategoryRecord({
    required this.categoryKey,
    required this.rawScore,
    required this.maximum,
    required this.applicable,
    required this.sampleSufficient,
    required this.contributionUsed,
    required this.contributionSource,
  });

  Map<String, Object> toMap() => {
    'key': categoryKey,
    'raw': rawScore,
    'maximum': maximum,
    'applicable': applicable,
    'sampleSufficient': sampleSufficient,
    'contribution': contributionUsed,
    'source': contributionSource.name,
  };

  factory DriveScoreCategoryRecord.fromMap(Map<dynamic, dynamic> map) {
    final sourceName = map['source'] as String?;
    final source = DriveScoreContributionSource.values.firstWhere(
      (value) => value.name == sourceName,
      orElse: () => DriveScoreContributionSource.neutralInsufficient,
    );
    return DriveScoreCategoryRecord(
      categoryKey: map['key'] as String? ?? '',
      rawScore: (map['raw'] as num?)?.toDouble() ?? 0,
      maximum: (map['maximum'] as num?)?.toDouble() ?? 0,
      applicable: map['applicable'] as bool? ?? false,
      sampleSufficient: map['sampleSufficient'] as bool? ?? false,
      contributionUsed: (map['contribution'] as num?)?.toDouble() ?? 0,
      contributionSource: source,
    );
  }
}
