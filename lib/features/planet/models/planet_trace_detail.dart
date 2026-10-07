class PlanetScoreCategory {
  const PlanetScoreCategory(
    this.key,
    this.score,
    this.maximum,
    this.applicable,
    this.sufficient,
  );
  final String key;
  final double score, maximum;
  final bool applicable, sufficient;
}

class PlanetTraceDetail {
  const PlanetTraceDetail({
    required this.traceId,
    required this.generation,
    required this.displayName,
    required this.username,
    required this.date,
    required this.distance,
    required this.duration,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.ownershipDistance,
    required this.score,
    required this.categories,
  });
  final String traceId;
  final BigInt generation;
  final String? displayName, username;
  final DateTime date;
  final double distance, averageSpeed, maxSpeed, ownershipDistance;
  final int duration;
  final int? score;
  final List<PlanetScoreCategory> categories;
  factory PlanetTraceDetail.parse(Map<String, dynamic> value) {
    double number(String key) {
      final n = (value[key] as num).toDouble();
      if (!n.isFinite || n < 0) {
        throw const FormatException('Invalid detail metric');
      }
      return n;
    }

    final scoring = value['score'] as Map<String, dynamic>?;
    final raw = scoring?['categories'] as Map<String, dynamic>? ?? {};
    return PlanetTraceDetail(
      traceId: value['trace_id'] as String,
      generation: BigInt.parse(value['generation'] as String),
      displayName: value['display_name'] as String?,
      username: value['username'] as String?,
      date: DateTime.parse(value['drive_date'] as String),
      distance: number('distance_meters'),
      duration: value['duration_seconds'] as int,
      averageSpeed: number('average_speed_kmh'),
      maxSpeed: number('maximum_speed_kmh'),
      ownershipDistance: number('ownership_distance_meters'),
      score: scoring?['displayScore'] as int?,
      categories: List.unmodifiable([
        for (final entry in raw.entries)
          PlanetScoreCategory(
            entry.key,
            (entry.value['score'] as num).toDouble(),
            (entry.value['maximum'] as num).toDouble(),
            entry.value['applicable'] as bool,
            entry.value['sampleSufficient'] as bool,
          ),
      ]),
    );
  }
}
