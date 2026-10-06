// Server adapter: algorithms remain the existing, pure Dart source of truth.
// Standalone compiler input intentionally does not require Flutter package resolution.
// ignore_for_file: avoid_relative_lib_imports
import '../lib/features/drive_score/models/drive_score_algorithm_version.dart';
import '../lib/features/drive_score/models/drive_score_result.dart';
import '../lib/features/my_world/config/my_world_rules.dart';
import '../lib/features/my_world/models/common_road_match.dart';
import '../lib/features/my_world/models/common_road_score_comparison.dart';
import '../lib/features/my_world/models/common_road_telemetry.dart';
import '../lib/features/my_world/models/matched_road_point.dart';
import '../lib/features/my_world/models/matched_road_section.dart';
import '../lib/features/my_world/models/validated_road.dart';
import '../lib/features/my_world/services/common_road_local_score_service.dart';
import '../lib/features/my_world/services/common_road_telemetry_extractor.dart';
import '../lib/features/my_world/services/local_winning_road_region_service.dart';
import '../lib/models/canonical_telemetry_point.dart';

typedef Json = Map<String, dynamic>;
double number(Json map, String key) => (map[key] as num).toDouble();
MatchedRoadPoint point(Json p) => MatchedRoadPoint(
  latitude: number(p, 'latitude'),
  longitude: number(p, 'longitude'),
);
ValidatedRoad road(Json r) {
  final sections = (r['sections'] as List)
      .map(
        (s) => MatchedRoadSection(
          id: s['id'] as String,
          geometry: (s['geometry'] as List)
              .map((p) => point(p as Json))
              .toList(),
          distanceMeters: number(s as Json, 'distanceMeters'),
          confidence: null,
          sourceTraceIndex: 0,
          sourceChunkIndex: 0,
        ),
      )
      .toList();
  final epoch = DateTime.utc(1970);
  return ValidatedRoad(
    id: r['id'],
    driveSessionId: r['driveId'],
    geometry: sections.expand((s) => s.geometry).toList(),
    sections: sections,
    validDistanceMeters: sections.fold(0, (v, s) => v + s.distanceMeters),
    status: RoadValidationStatus.validated,
    validatedAt: null,
    providerId: 'mapbox',
    confidence: null,
    processingVersion: MyWorldRules.validatedRoadProcessingVersion,
    directionKey: '',
    averageHeadingDegrees: null,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

List<CanonicalTelemetryPoint> telemetry(List values) => values.map((v) {
  final p = v as Json;
  // Never use fromMap: it clamps values and truncates timestamps to milliseconds.
  return CanonicalTelemetryPoint(
    latitude: number(p, 'latitude'),
    longitude: number(p, 'longitude'),
    timestamp: DateTime.parse(p['timestamp']),
    speedMps: number(p, 'speed_mps'),
    headingDegrees: number(p, 'heading_degrees'),
    altitudeMeters: number(p, 'altitude_meters'),
    accuracyMeters: number(p, 'accuracy_meters'),
    distanceFromPreviousMeters: number(p, 'distance_from_previous_meters'),
    accelerationMps2: number(p, 'acceleration_mps2'),
  );
}).toList();
Json score(DriveScoreResult? s) => s == null
    ? {}
    : {
        'totalScore': s.totalScore,
        'displayScore': s.displayScore,
        'algorithmVersion': s.algorithmVersion,
        'overallConfidence': s.overallConfidence,
        'categories': s.categories.map(
          (key, v) => MapEntry(key, {
            'score': v.score,
            'maximum': v.maximum,
            'applicable': v.applicable,
            'sampleSufficient': v.sampleSufficient,
          }),
        ),
        'contributions': s.contributions.map(
          (key, v) => MapEntry(key, {
            'contribution': v.contribution,
            'source': v.source.name,
          }),
        ),
      };
Json comparison(CommonRoadScoreComparison c) => {
  'outcome': c.outcome.name,
  'comparisonValid': c.comparisonValid,
  'firstLocalScore': c.firstLocalScore == null
      ? null
      : score(c.firstLocalScore),
  'secondLocalScore': c.secondLocalScore == null
      ? null
      : score(c.secondLocalScore),
  'scoreDifference': c.scoreDifference,
  'relativeDifference': c.relativeDifference,
};
Json subset(CommonRoadTelemetrySubset s) => {
  'status': s.status.name, 'startIndex': s.startIndex, 'endIndex': s.endIndex,
  'count': s.telemetry.length, 'mappingConfidence': s.mappingConfidence,
  // Selection identity without exporting source telemetry back to callers.
  'timestamps': s.telemetry
      .map((p) => p.timestamp.toUtc().toIso8601String())
      .toList(),
};

Json evaluateWorldScoring(Json input) {
  final version = input['algorithmVersion'];
  if (version != DriveScoreAlgorithmVersion.v1.value) {
    return {
      'status': 'unsupportedAlgorithmVersion',
      'windows': [],
      'winningRegions': [],
    };
  }
  final match = decodeMatch(input['match'] as Json);
  if (!match.comparisonEligible) {
    return {'status': 'notEligible', 'windows': [], 'winningRegions': []};
  }
  final firstRoad = road(input['firstRoad']),
      secondRoad = road(input['secondRoad']);
  final first = telemetry(input['firstTelemetry']),
      second = telemetry(input['secondTelemetry']);
  return analyzeScoring(match, firstRoad, secondRoad, first, second);
}

CommonRoadMatch decodeMatch(Json m) => CommonRoadMatch(
  firstDriveId: m['firstDriveId'],
  secondDriveId: m['secondDriveId'],
  firstSectionId: m['firstSectionId'],
  secondSectionId: m['secondSectionId'],
  firstStartOffsetMeters: number(m, 'firstStartOffsetMeters'),
  firstEndOffsetMeters: number(m, 'firstEndOffsetMeters'),
  secondStartOffsetMeters: number(m, 'secondStartOffsetMeters'),
  secondEndOffsetMeters: number(m, 'secondEndOffsetMeters'),
  commonStart: point(m['commonStart']),
  commonEnd: point(m['commonEnd']),
  commonDistanceMeters: number(m, 'commonDistanceMeters'),
  directionCompatible: m['directionCompatible'],
  geometryConfidence: number(m, 'geometryConfidence'),
  comparisonEligible: m['comparisonEligible'],
  ownershipCovered: m['ownershipCovered'],
  referenceGeometry: (m['referenceGeometry'] as List)
      .map((p) => point(p as Json))
      .toList(),
);

Json analyzeScoring(
  CommonRoadMatch match,
  ValidatedRoad firstRoad,
  ValidatedRoad secondRoad,
  List<CanonicalTelemetryPoint> first,
  List<CanonicalTelemetryPoint> second, {
  CommonRoadLocalScoreService service = const CommonRoadLocalScoreService(),
}) {
  // Strict outer clipping prevents the window service's +/-5m tolerance from
  // reading outside an active trace or the Stage 2A clipped common span.
  final pair = const CommonRoadTelemetryExtractor().extract(
    match: match,
    firstRoad: firstRoad,
    firstTelemetry: first,
    secondRoad: secondRoad,
    secondTelemetry: second,
  );
  if (!pair.isUsable) {
    return {
      'status': 'telemetryUnavailable',
      'firstExtraction': subset(pair.first),
      'secondExtraction': subset(pair.second),
      'windows': [],
      'winningRegions': [],
    };
  }
  final compared = service.compare(
    match: match,
    firstRoad: firstRoad,
    firstTelemetry: pair.first.telemetry,
    secondRoad: secondRoad,
    secondTelemetry: pair.second.telemetry,
    algorithmVersion: DriveScoreAlgorithmVersion.v1,
  );
  final analysis = LocalWinningRoadRegionService(localScoreService: service)
      .analyze(
        match: match,
        existingRoad: firstRoad,
        existingTelemetry: pair.first.telemetry,
        challengerRoad: secondRoad,
        challengerTelemetry: pair.second.telemetry,
        algorithmVersion: DriveScoreAlgorithmVersion.v1,
      );
  return {
    'status': analysis.status.name,
    'comparison': comparison(compared),
    'firstExtraction': subset(pair.first),
    'secondExtraction': subset(pair.second),
    'windows': analysis.windows
        .map(
          (w) => {
            'commonStartOffsetMeters': w.commonStartOffsetMeters,
            'commonEndOffsetMeters': w.commonEndOffsetMeters,
            'existingStartOffsetMeters': w.existingStartOffsetMeters,
            'existingEndOffsetMeters': w.existingEndOffsetMeters,
            'challengerStartOffsetMeters': w.challengerStartOffsetMeters,
            'challengerEndOffsetMeters': w.challengerEndOffsetMeters,
            'state': w.state.name,
            'comparison': comparison(w.comparison),
          },
        )
        .toList(),
    'winningRegions': analysis.winningRegions
        .map(
          (r) => {
            'existingDriveId': r.existingDriveId,
            'challengerDriveId': r.challengerDriveId,
            'startOffsetOnExistingMeters': r.startOffsetOnExistingMeters,
            'endOffsetOnExistingMeters': r.endOffsetOnExistingMeters,
            'startOffsetOnChallengerMeters': r.startOffsetOnChallengerMeters,
            'endOffsetOnChallengerMeters': r.endOffsetOnChallengerMeters,
            'commonStartOffsetMeters': r.commonStartOffsetMeters,
            'commonEndOffsetMeters': r.commonEndOffsetMeters,
            'winningDistanceMeters': r.winningDistanceMeters,
            'algorithmVersion': r.algorithmVersion.value,
            'confidence': r.confidence,
            'supportingWindowCount': r.supportingWindowCount,
          },
        )
        .toList(),
  };
}
