/// Presentation-only travel direction resolved from the source drive's
/// timestamped canonical telemetry. Persisted World geometry is unchanged.
enum WorldTraceTravelDirection { forward, reverse, unknown }

class WorldTraceTravelDirectionResult {
  const WorldTraceTravelDirectionResult({
    required this.direction,
    required this.confidence,
    required this.projectedSampleCount,
    required this.signedProgressionMeters,
    this.firstProjectedOffset,
    this.lastProjectedOffset,
  });

  const WorldTraceTravelDirectionResult.unknown()
      : direction = WorldTraceTravelDirection.unknown,
        confidence = 0,
        projectedSampleCount = 0,
        signedProgressionMeters = 0,
        firstProjectedOffset = null,
        lastProjectedOffset = null;
  

  final WorldTraceTravelDirection direction;
  final double confidence;
  final int projectedSampleCount;
  final double signedProgressionMeters;
  final double? firstProjectedOffset;
  final double? lastProjectedOffset;
}
