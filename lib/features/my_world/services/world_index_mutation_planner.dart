import 'dart:math' as math;

import '../../../features/drive_score/models/drive_score_algorithm_version.dart';
import '../config/my_world_rules.dart';
import '../models/active_world_trace.dart';
import '../models/common_road_match.dart';
import '../models/local_winning_road_region.dart';
import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/validated_road.dart';
import '../models/world_index_mutation_plan.dart';
import '../models/world_index_snapshot.dart';
import '../models/world_trace_overlap_analysis.dart';
import 'world_section_offset_mapper.dart';

/// Pure ownership mutation planner. It never writes Hive or scores a road.
class WorldIndexMutationPlanner {
  const WorldIndexMutationPlanner();

  WorldIndexMutationPlan plan({
    required WorldIndexSnapshot current,
    required ValidatedRoad challengerRoad,
    required List<WorldTraceOverlapAnalysis> overlaps,
    required DateTime now,
    DriveScoreAlgorithmVersion algorithmVersion =
        DriveScoreAlgorithmVersion.v1,
  }) {
    final operationId = 'world:${challengerRoad.driveSessionId}:v${algorithmVersion.value}';
    final replacements = <String, List<_TraceInterval>>{};
    final challengerIntervals = <_TraceInterval>[];
    final coveredByExisting = <String, List<_Interval>>{};

    for (final overlap in overlaps) {
      for (final match in overlap.matches) {
        // Geometric same-road/same-direction coverage suppresses duplicate
        // ownership even when the overlap is too short for local score
        // comparison. The 3 km rule belongs exclusively to scoring.
        if (!match.ownershipCovered || !match.directionCompatible) continue;
        final clipped = _clipMatchToTrace(match, overlap.existingTrace);
        if (clipped == null) continue;
        coveredByExisting
            .putIfAbsent(clipped.secondSectionId, () => [])
            .add(_Interval(clipped.secondStart, clipped.secondEnd));
      }

      final winners = overlap.winningRegions
          .where(
            (region) =>
                region.challengerDriveId == challengerRoad.driveSessionId &&
                region.winningDistanceMeters + _epsilon >=
                    MyWorldRules.minimumLocalWinningRegionMeters,
          )
          .map((region) => _clipWinner(region, overlap.existingTrace))
          .whereType<_WinnerReplacement>()
          .toList(growable: false);
      if (winners.isEmpty) continue;

      final existingIntervals = _splitExisting(overlap.existingTrace, winners, now);
      replacements[overlap.existingTrace.id] = existingIntervals;
      challengerIntervals.addAll(
        winners.map(
          (winner) => _TraceInterval(
            validatedRoadId: challengerRoad.id,
            sourceDriveSessionId: challengerRoad.driveSessionId,
            sectionId: winner.challengerSectionId,
            start: winner.challengerStart,
            end: winner.challengerEnd,
            directionKey: challengerRoad.directionKey,
          ),
        ),
      );
    }

    final challengerSections = _sectionsWithOffsets(challengerRoad);
    for (final section in challengerSections) {
      final covered = _mergeIntervals(
        coveredByExisting[section.section.id] ?? const [],
      );
      for (final remaining in _subtract(
        _Interval(section.start, section.end),
        covered,
      )) {
        challengerIntervals.add(
          _TraceInterval(
            validatedRoadId: challengerRoad.id,
            sourceDriveSessionId: challengerRoad.driveSessionId,
            sectionId: section.section.id,
            start: remaining.start,
            end: remaining.end,
            directionKey: challengerRoad.directionKey,
          ),
        );
      }
    }

    final retained = <ActiveWorldTrace>[];
    final removed = <ActiveWorldTrace>[];
    for (final trace in current.traces) {
      final replacement = replacements[trace.id];
      if (replacement == null) {
        retained.add(trace);
      } else {
        removed.add(trace);
        retained.addAll(
          replacement.map((interval) => _traceForExisting(interval, trace, now)),
        );
      }
    }
    final created = <ActiveWorldTrace>[
      ...challengerIntervals
          .where((interval) => interval.distance > _epsilon)
          .map((interval) => _traceForChallenger(interval, challengerRoad, now)),
    ];
    final normalized = _sanitizeActiveTraces(
      _mergeAdjacent([...retained, ...created], now),
    );
    _assertNoDuplicateOwnership(normalized);

    final processed = <String>{
      ...current.processedDriveSessionIds,
      challengerRoad.driveSessionId,
    }.toList(growable: false)..sort();
    final snapshot = WorldIndexSnapshot(
      generation: current.generation + 1,
      operationId: operationId,
      traces: List.unmodifiable(normalized),
      processedDriveSessionIds: List.unmodifiable(processed),
      driveScoreAlgorithmVersion: algorithmVersion.value,
      validatedRoadProcessingVersion: MyWorldRules.worldRulesVersion,
      createdAt: now.toUtc(),
    );
    return WorldIndexMutationPlan(
      operationId: operationId,
      sourceDriveSessionId: challengerRoad.driveSessionId,
      baseGeneration: current.generation,
      tracesToRemove: List.unmodifiable(removed),
      tracesToCreate: List.unmodifiable(
        created.where(_isActiveTraceLengthValid).toList(growable: false),
      ),
      resultingSnapshot: snapshot,
    );
  }

  static const double _epsilon = .01;

  bool _isActiveTraceLengthValid(ActiveWorldTrace trace) =>
      trace.distanceMeters >= MyWorldRules.minimumActiveTraceMeters;

  List<ActiveWorldTrace> _sanitizeActiveTraces(
    Iterable<ActiveWorldTrace> traces,
  ) => traces.where(_isActiveTraceLengthValid).toList(growable: false);

  List<_TraceInterval> _splitExisting(
    ActiveWorldTrace trace,
    List<_WinnerReplacement> winners,
    DateTime now,
  ) {
    final sorted = winners
        .map((winner) => _Interval(winner.existingStart, winner.existingEnd))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final output = <_TraceInterval>[];
    var cursor = trace.startOffsetMeters;
    for (final winner in sorted) {
      if (winner.start > cursor + _epsilon) {
        final remainder = _TraceInterval.fromTrace(trace, cursor, winner.start);
        if (remainder.distance >= MyWorldRules.minimumVisibleRemainderMeters) {
          output.add(remainder);
        }
      }
      cursor = math.max(cursor, winner.end);
    }
    if (cursor < trace.endOffsetMeters - _epsilon) {
      final remainder = _TraceInterval.fromTrace(
        trace,
        cursor,
        trace.endOffsetMeters,
      );
      if (remainder.distance >= MyWorldRules.minimumVisibleRemainderMeters) {
        output.add(remainder);
      }
    }
    return output;
  }

  _WinnerReplacement? _clipWinner(
    LocalWinningRoadRegion region,
    ActiveWorldTrace trace,
  ) {
    if (region.match.firstSectionId != trace.matchedSectionId) return null;
    final start = math.max(region.startOffsetOnExistingMeters, trace.startOffsetMeters);
    final end = math.min(region.endOffsetOnExistingMeters, trace.endOffsetMeters);
    if (end - start + _epsilon < MyWorldRules.minimumLocalWinningRegionMeters) {
      return null;
    }
    final existingSpan = region.endOffsetOnExistingMeters - region.startOffsetOnExistingMeters;
    if (existingSpan <= _epsilon) return null;
    final startRatio = (start - region.startOffsetOnExistingMeters) / existingSpan;
    final endRatio = (end - region.startOffsetOnExistingMeters) / existingSpan;
    return _WinnerReplacement(
      existingStart: start,
      existingEnd: end,
      challengerSectionId: region.match.secondSectionId,
      challengerStart: _interpolate(
        region.startOffsetOnChallengerMeters,
        region.endOffsetOnChallengerMeters,
        startRatio,
      ),
      challengerEnd: _interpolate(
        region.startOffsetOnChallengerMeters,
        region.endOffsetOnChallengerMeters,
        endRatio,
      ),
    );
  }

  _ClippedMatch? _clipMatchToTrace(
    CommonRoadMatch match,
    ActiveWorldTrace trace,
  ) {
    if (match.firstSectionId != trace.matchedSectionId) return null;
    final start = math.max(match.firstStartOffsetMeters, trace.startOffsetMeters);
    final end = math.min(match.firstEndOffsetMeters, trace.endOffsetMeters);
    if (end - start <= _epsilon) return null;
    final span = match.firstEndOffsetMeters - match.firstStartOffsetMeters;
    if (span <= _epsilon) return null;
    return _ClippedMatch(
      secondSectionId: match.secondSectionId,
      secondStart: _interpolate(
        match.secondStartOffsetMeters,
        match.secondEndOffsetMeters,
        (start - match.firstStartOffsetMeters) / span,
      ),
      secondEnd: _interpolate(
        match.secondStartOffsetMeters,
        match.secondEndOffsetMeters,
        (end - match.firstStartOffsetMeters) / span,
      ),
    );
  }

  List<_SectionOffset> _sectionsWithOffsets(ValidatedRoad road) {
    final sections = road.sections.isNotEmpty
        ? road.sections
        : [
            MatchedRoadSection(
              id: '${road.id}:geometry',
              geometry: road.geometry,
              distanceMeters: road.validDistanceMeters,
              confidence: road.confidence,
              sourceTraceIndex: 0,
              sourceChunkIndex: 0,
            ),
          ];
    var offset = 0.0;
    return sections.map((section) {
      final sectionLength = WorldSectionOffsetMapper.sectionLength(section);
      final output = _SectionOffset(section, offset, offset + sectionLength);
      offset += sectionLength;
      return output;
    }).toList(growable: false);
  }

  ActiveWorldTrace _traceForExisting(
    _TraceInterval interval,
    ActiveWorldTrace original,
    DateTime now,
  ) => original.copyWith(
    id: _idFor(interval),
    startOffsetMeters: interval.start,
    endOffsetMeters: interval.end,
    updatedAt: now.toUtc(),
  );

  ActiveWorldTrace _traceForChallenger(
    _TraceInterval interval,
    ValidatedRoad road,
    DateTime now,
  ) {
    final section = _sectionsWithOffsets(road)
        .firstWhere((value) => value.section.id == interval.sectionId)
        .section;
    final bounds = _bounds(section.geometry);
    return ActiveWorldTrace(
      id: _idFor(interval),
      sourceDriveSessionId: interval.sourceDriveSessionId,
      validatedRoadId: interval.validatedRoadId,
      matchedSectionId: interval.sectionId,
      startOffsetMeters: interval.start,
      endOffsetMeters: interval.end,
      directionKey: interval.directionKey,
      minLatitude: bounds.$1,
      maxLatitude: bounds.$2,
      minLongitude: bounds.$3,
      maxLongitude: bounds.$4,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      processingVersion: road.processingVersion,
    );
  }

  List<ActiveWorldTrace> _mergeAdjacent(
    List<ActiveWorldTrace> input,
    DateTime now,
  ) {
    final ordered = [...input]
      ..sort((a, b) {
        final section = a.matchedSectionId.compareTo(b.matchedSectionId);
        return section != 0 ? section : a.startOffsetMeters.compareTo(b.startOffsetMeters);
      });
    final result = <ActiveWorldTrace>[];
    for (final trace in ordered) {
      if (result.isEmpty || !_canMerge(result.last, trace)) {
        result.add(trace);
        continue;
      }
      final previous = result.removeLast();
      result.add(previous.copyWith(
        id: _idFor(_TraceInterval.fromTrace(previous, previous.startOffsetMeters, trace.endOffsetMeters)),
        endOffsetMeters: trace.endOffsetMeters,
        updatedAt: now.toUtc(),
      ));
    }
    return result;
  }

  bool _canMerge(ActiveWorldTrace first, ActiveWorldTrace second) =>
      first.sourceDriveSessionId == second.sourceDriveSessionId &&
      first.validatedRoadId == second.validatedRoadId &&
      first.matchedSectionId == second.matchedSectionId &&
      first.directionKey == second.directionKey &&
      (first.endOffsetMeters - second.startOffsetMeters).abs() <= _epsilon;

  void _assertNoDuplicateOwnership(List<ActiveWorldTrace> traces) {
    for (var i = 0; i < traces.length; i++) {
      for (var j = i + 1; j < traces.length; j++) {
        final first = traces[i];
        final second = traces[j];
        if (first.matchedSectionId != second.matchedSectionId ||
            first.directionKey != second.directionKey) {
          continue;
        }
        final overlap = math.min(first.endOffsetMeters, second.endOffsetMeters) -
            math.max(first.startOffsetMeters, second.startOffsetMeters);
        if (overlap > _epsilon &&
            first.sourceDriveSessionId != second.sourceDriveSessionId) {
          throw StateError('Duplicate active ownership for a World road interval.');
        }
      }
    }
  }

  List<_Interval> _mergeIntervals(List<_Interval> input) {
    if (input.isEmpty) return const [];
    final sorted = [...input]..sort((a, b) => a.start.compareTo(b.start));
    final output = <_Interval>[sorted.first];
    for (final interval in sorted.skip(1)) {
      final last = output.last;
      if (interval.start <= last.end + _epsilon) {
        output[output.length - 1] = _Interval(last.start, math.max(last.end, interval.end));
      } else {
        output.add(interval);
      }
    }
    return output;
  }

  List<_Interval> _subtract(_Interval source, List<_Interval> covered) {
    final output = <_Interval>[];
    var cursor = source.start;
    for (final interval in covered) {
      if (interval.end <= source.start || interval.start >= source.end) continue;
      final start = math.max(interval.start, source.start);
      final end = math.min(interval.end, source.end);
      if (start > cursor + _epsilon) output.add(_Interval(cursor, start));
      cursor = math.max(cursor, end);
    }
    if (cursor < source.end - _epsilon) output.add(_Interval(cursor, source.end));
    return output;
  }

  String _idFor(_TraceInterval interval) =>
      '${interval.sourceDriveSessionId}:${interval.validatedRoadId}:${interval.sectionId}:${interval.start.toStringAsFixed(3)}:${interval.end.toStringAsFixed(3)}';

  (double, double, double, double) _bounds(List<MatchedRoadPoint> points) {
    if (points.isEmpty) return (0, 0, 0, 0);
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return (minLat, maxLat, minLng, maxLng);
  }

  double _interpolate(double start, double end, double ratio) =>
      start + (end - start) * ratio;
}

class _SectionOffset {
  const _SectionOffset(this.section, this.start, this.end);
  final MatchedRoadSection section;
  final double start;
  final double end;
}

class _Interval {
  const _Interval(this.start, this.end);
  final double start;
  final double end;
}

class _TraceInterval extends _Interval {
  const _TraceInterval({
    required this.validatedRoadId,
    required this.sourceDriveSessionId,
    required this.sectionId,
    required double start,
    required double end,
    required this.directionKey,
  }) : super(start, end);

  factory _TraceInterval.fromTrace(ActiveWorldTrace trace, double start, double end) =>
      _TraceInterval(
        validatedRoadId: trace.validatedRoadId,
        sourceDriveSessionId: trace.sourceDriveSessionId,
        sectionId: trace.matchedSectionId,
        start: start,
        end: end,
        directionKey: trace.directionKey,
      );

  final String validatedRoadId;
  final String sourceDriveSessionId;
  final String sectionId;
  final String directionKey;
  double get distance => end - start;
}

class _WinnerReplacement {
  const _WinnerReplacement({
    required this.existingStart,
    required this.existingEnd,
    required this.challengerSectionId,
    required this.challengerStart,
    required this.challengerEnd,
  });
  final double existingStart;
  final double existingEnd;
  final String challengerSectionId;
  final double challengerStart;
  final double challengerEnd;
}

class _ClippedMatch {
  const _ClippedMatch({
    required this.secondSectionId,
    required this.secondStart,
    required this.secondEnd,
  });
  final String secondSectionId;
  final double secondStart;
  final double secondEnd;
}
