import 'dart:math' as math;
import '../config/my_world_rules.dart';
import '../models/active_world_trace.dart';
import '../models/common_road_match.dart';

/// Canonical road offsets, clipped to the current owner's actual active span.
/// Full source length must never contribute to performance eligibility.
class ActiveWorldCoverage {
  const ActiveWorldCoverage._();

  static CommonRoadMatch? clip(CommonRoadMatch match, ActiveWorldTrace trace) {
    return clipSpan(
      match,
      sectionId: trace.matchedSectionId,
      startOffsetMeters: trace.startOffsetMeters,
      endOffsetMeters: trace.endOffsetMeters,
    );
  }

  static CommonRoadMatch? clipSpan(
    CommonRoadMatch match, {
    required String sectionId,
    required double startOffsetMeters,
    required double endOffsetMeters,
  }) {
    if (!match.directionCompatible ||
        !match.ownershipCovered ||
        match.firstSectionId != sectionId) {
      return null;
    }
    final start = math.max(match.firstStartOffsetMeters, startOffsetMeters);
    final end = math.min(match.firstEndOffsetMeters, endOffsetMeters);
    final originalSpan =
        match.firstEndOffsetMeters - match.firstStartOffsetMeters;
    // Existing planner's interval epsilon, not an eligibility tolerance.
    if (end - start <= .01 || originalSpan <= .01) return null;
    double second(double offset) =>
        match.secondStartOffsetMeters +
        (match.secondEndOffsetMeters - match.secondStartOffsetMeters) *
            ((offset - match.firstStartOffsetMeters) / originalSpan);
    final secondStart = second(start), secondEnd = second(end);
    final common = math.min(end - start, secondEnd - secondStart);
    return CommonRoadMatch(
      firstDriveId: match.firstDriveId,
      secondDriveId: match.secondDriveId,
      firstSectionId: match.firstSectionId,
      secondSectionId: match.secondSectionId,
      firstStartOffsetMeters: start,
      firstEndOffsetMeters: end,
      secondStartOffsetMeters: secondStart,
      secondEndOffsetMeters: secondEnd,
      commonStart: match.commonStart,
      commonEnd: match.commonEnd,
      // Reference geometry is the original match; only canonical intervals
      // define active coverage, never this full-section compatibility view.
      referenceGeometry: match.referenceGeometry,
      commonDistanceMeters: common,
      directionCompatible: match.directionCompatible,
      geometryConfidence: match.geometryConfidence,
      ownershipCovered: match.ownershipCovered,
      comparisonEligible:
          common >= MyWorldRules.minimumCommonWorldDistanceMeters,
    );
  }
}
