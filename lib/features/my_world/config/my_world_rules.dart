class MyWorldRules {
  const MyWorldRules._();

  /// A drive must contain at least this much provider-validated road before it
  /// can become eligible for future World processing.
  static const double minimumValidDistanceMeters = 3000;

  /// A geometrically detected common road becomes eligible for a future
  /// performance comparison only at or above this length.
  static const double minimumCommonWorldDistanceMeters = 1000;

  /// Temporary matching resolution used only while comparing validated road
  /// geometry. It is never persisted as a World segment.
  static const double commonRoadResampleIntervalMeters = 25;

  /// Map-matched geometry should be close enough to identify the same
  /// carriageway, while remaining too strict to merge nearby parallel roads.
  static const double commonRoadGeometryToleranceMeters = 15;

  static const double commonRoadMinimumReportedDistanceMeters = 100;
  static const double commonRoadMaximumDirectionDifferenceDegrees = 30;
  static const double commonRoadMinimumGeometryConfidence = .65;
  static const double commonRoadMaximumRelativeLengthDifference = .2;

  /// Canonical GPS samples must be this close to their map-matched section to
  /// be accepted for temporary local-score extraction.
  static const double commonRoadTelemetryProjectionToleranceMeters = 35;
  static const double commonRoadTelemetryHeadingToleranceDegrees = 60;
  static const double commonRoadTelemetryOffsetBoundaryToleranceMeters = 5;

  /// A local score can replace another only with at least this relative gain.
  static const double minimumMeaningfulScoreImprovementRatio = .01;

  /// Temporary resolution for Phase 5 local winner-region analysis. It is
  /// never persisted as a World segment or ownership record.
  static const double localScoreAnalysisWindowMeters = 100;

  /// A short non-winning/invalid interval may connect challenger-winning
  /// regions only up to this physical distance.
  static const double localScoreWinnerGapToleranceMeters = 200;

  /// A challenger region must cover at least this much actual common road
  /// before it can become a future World-record candidate.
  static const double minimumLocalWinningRegionMeters = 500;

  /// Matches the recorder's existing stationary-noise threshold.
  static const double minimumUsefulPointDistanceMeters = 3;

  /// Without timestamps a larger gap cannot be proven continuous. The
  /// preprocessor splits at this boundary instead of deleting either side.
  static const double maximumPlausiblePointJumpMeters = 500;

  /// Mapbox Map Matching accepts at most 100 coordinates per request.
  static const int mapMatchingMaximumCoordinates = 100;

  /// Shared input points keep adjacent request chunks continuous.
  static const int mapMatchingChunkOverlap = 3;

  /// RoutePoint no longer retains recorded accuracy, so use a conservative
  /// radius within Mapbox's documented 0-50 metre range.
  static const double mapMatchingRadiusMeters = 25;

  static const double chunkGeometryMergeToleranceMeters = 15;
  static const Duration mapMatchingTimeout = Duration(seconds: 15);

  /// Incremented only when the persisted validated-road representation changes.
  static const int validatedRoadProcessingVersion = 2;
}
