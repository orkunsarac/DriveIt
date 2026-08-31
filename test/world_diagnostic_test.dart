import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/validated_road.dart';
import 'package:driveit_project/features/my_world/models/world_index_snapshot.dart';
import 'package:driveit_project/features/my_world/models/world_processing.dart';
import 'package:driveit_project/features/my_world/services/world_diagnostic_service.dart';
import 'package:flutter_test/flutter_test.dart';

ValidatedRoad road({double distance = 5000}) {
  final now = DateTime.utc(2026, 1, 1);
  return ValidatedRoad(
    id: 'road-1',
    driveSessionId: 'drive-1',
    geometry: const [
      MatchedRoadPoint(latitude: 1, longitude: 1),
      MatchedRoadPoint(latitude: 1.01, longitude: 1.01),
    ],
    validDistanceMeters: distance,
    status: RoadValidationStatus.validated,
    validatedAt: now,
    providerId: 'test',
    confidence: 1,
    processingVersion: 1,
    directionKey: 'forward',
    averageHeadingDegrees: 90,
    createdAt: now,
    updatedAt: now,
  );
}

WorldDiagnosticInput input({
  List<ValidatedRoad> roads = const [],
  WorldDriveProcessingRecord? processing,
  WorldIndexSnapshot? snapshot,
  int activeTraceCount = 0,
}) => WorldDiagnosticInput(
  driveFound: true,
  canonicalTelemetryPresent: true,
  validatedRoads: roads,
  processing: processing,
  pendingJobs: const [],
  activeSnapshot: snapshot,
  activeTraceCount: activeTraceCount,
);

void main() {
  test('missing validated road is classified as not enqueued', () {
    expect(
      WorldDiagnosticClassifier.classify(input()),
      WorldDiagnosticDiagnosis.worldJobNotEnqueued,
    );
  });

  test('2999 metres is below the World threshold', () {
    expect(
      WorldDiagnosticClassifier.classify(input(roads: [road(distance: 2999)])),
      WorldDiagnosticDiagnosis.validatedDistanceBelow3km,
    );
  });

  test('5000 metres without an active trace is ready but unprocessed', () {
    final processing = WorldDriveProcessingRecord(
      driveSessionId: 'drive-1',
      state: WorldProcessingState.readyForWorldProcessing,
      validatedRoadId: 'road-1',
      lastError: null,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    expect(
      WorldDiagnosticClassifier.classify(
        input(roads: [road()], processing: processing),
      ),
      WorldDiagnosticDiagnosis.validatedReadyButWorldNotProcessed,
    );
  });

  test('a 5000 metre active trace is success', () {
    expect(
      WorldDiagnosticClassifier.classify(
        input(roads: [road()], activeTraceCount: 1),
      ),
      WorldDiagnosticDiagnosis.success,
    );
  });

  test('processed drive without a trace reports missing index commit', () {
    final processing = WorldDriveProcessingRecord(
      driveSessionId: 'drive-1',
      state: WorldProcessingState.processed,
      validatedRoadId: 'road-1',
      lastError: null,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final snapshot = WorldIndexSnapshot.empty(
      driveScoreAlgorithmVersion: 1,
      validatedRoadProcessingVersion: 1,
    ).copyWith(processedDriveSessionIds: const ['drive-1']);
    expect(
      WorldDiagnosticClassifier.classify(
        input(roads: [road()], processing: processing, snapshot: snapshot),
      ),
      WorldDiagnosticDiagnosis.worldIndexCommitMissing,
    );
  });
}
