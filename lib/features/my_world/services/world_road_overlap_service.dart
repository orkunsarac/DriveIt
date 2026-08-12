import 'dart:math' as math;

import '../config/my_world_rules.dart';
import '../models/common_road_match.dart';
import '../models/matched_road_point.dart';
import '../models/matched_road_section.dart';
import '../models/validated_road.dart';
import 'geo_distance.dart';

/// Finds continuous common sections in provider-validated, travel-ordered
/// geometry. It is a pure domain service: no Hive, HTTP, Drive Score, or UI.
class WorldRoadOverlapService {
  const WorldRoadOverlapService();

  List<CommonRoadMatch> findCommonRoads(
    ValidatedRoad first,
    ValidatedRoad second,
  ) {
    final firstSections = _sectionsFor(first);
    final secondSections = _sectionsFor(second);
    if (firstSections.isEmpty || secondSections.isEmpty) return const [];

    final matches = <CommonRoadMatch>[];
    for (final firstSection in firstSections) {
      final firstBounds = _Bounds.from(firstSection.samples);
      for (final secondSection in secondSections) {
        if (!firstBounds.intersects(
          _Bounds.from(secondSection.samples),
          MyWorldRules.commonRoadGeometryToleranceMeters,
        )) {
          continue;
        }
        matches.addAll(_matchSections(first, second, firstSection, secondSection));
      }
    }
    return List.unmodifiable(matches);
  }

  List<_SectionSamples> _sectionsFor(ValidatedRoad road) {
    final sections = road.sections.isNotEmpty
        ? road.sections
        : <MatchedRoadSection>[
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
    final output = <_SectionSamples>[];
    for (final section in sections) {
      final samples = _resample(section.geometry, offset);
      if (samples.length >= 2) {
        output.add(_SectionSamples(section.id, samples));
      }
      offset += section.distanceMeters;
    }
    return output;
  }

  List<CommonRoadMatch> _matchSections(
    ValidatedRoad firstRoad,
    ValidatedRoad secondRoad,
    _SectionSamples first,
    _SectionSamples second,
  ) {
    final secondIndex = _SpatialSampleIndex(second.samples);
    final runs = <_MatchedRun>[];
    _MatchedRun? active;
    for (final sample in first.samples) {
      final candidate = secondIndex.closestCompatible(sample);
      final canContinue = candidate != null &&
          active != null &&
          candidate.offsetMeters + MyWorldRules.commonRoadResampleIntervalMeters >=
              active.last.second.offsetMeters;
      if (candidate == null || (active != null && !canContinue)) {
        if (active != null) runs.add(active);
        active = candidate == null ? null : _MatchedRun(sample, candidate);
      } else if (active == null) {
        active = _MatchedRun(sample, candidate);
      } else {
        active.add(sample, candidate);
      }
    }
    if (active != null) runs.add(active);

    return runs
        .map(
          (run) => _toMatch(
            firstRoad,
            secondRoad,
            first.id,
            second.id,
            run,
          ),
        )
        .whereType<CommonRoadMatch>()
        .toList(growable: false);
  }

  CommonRoadMatch? _toMatch(
    ValidatedRoad firstRoad,
    ValidatedRoad secondRoad,
    String firstSectionId,
    String secondSectionId,
    _MatchedRun run,
  ) {
    final firstDistance = run.last.first.offsetMeters - run.first.first.offsetMeters;
    final secondDistance =
        run.last.second.offsetMeters - run.first.second.offsetMeters;
    final commonDistance = math.min(firstDistance, secondDistance);
    if (commonDistance < MyWorldRules.commonRoadMinimumReportedDistanceMeters) {
      return null;
    }
    final relativeDifference = (firstDistance - secondDistance).abs() /
        math.max(math.max(firstDistance, secondDistance), 1);
    if (relativeDifference > MyWorldRules.commonRoadMaximumRelativeLengthDifference) {
      return null;
    }
    final meanDistance = run.distanceSum / run.count;
    final meanDirectionAgreement = run.directionAgreementSum / run.count;
    final geometryConfidence = ((1 -
                    meanDistance /
                        MyWorldRules.commonRoadGeometryToleranceMeters) *
                .65 +
            meanDirectionAgreement * .35)
        .clamp(0.0, 1.0)
        .toDouble();
    if (geometryConfidence < MyWorldRules.commonRoadMinimumGeometryConfidence) {
      return null;
    }
    final geometry = run.pairs.map((pair) => pair.first.point).toList(
      growable: false,
    );
    return CommonRoadMatch(
      firstDriveId: firstRoad.driveSessionId,
      secondDriveId: secondRoad.driveSessionId,
      firstSectionId: firstSectionId,
      secondSectionId: secondSectionId,
      firstStartOffsetMeters: run.first.first.offsetMeters,
      firstEndOffsetMeters: run.last.first.offsetMeters,
      secondStartOffsetMeters: run.first.second.offsetMeters,
      secondEndOffsetMeters: run.last.second.offsetMeters,
      commonStart: run.first.first.point,
      commonEnd: run.last.first.point,
      commonDistanceMeters: commonDistance,
      directionCompatible: true,
      geometryConfidence: geometryConfidence,
      comparisonEligible:
          commonDistance >= MyWorldRules.minimumCommonWorldDistanceMeters,
      referenceGeometry: List.unmodifiable(geometry),
    );
  }

  List<_RoadSample> _resample(
    List<MatchedRoadPoint> geometry,
    double sectionStartOffsetMeters,
  ) {
    if (geometry.length < 2) return const [];
    final result = <_RoadSample>[
      _RoadSample(
        point: geometry.first,
        offsetMeters: sectionStartOffsetMeters,
        headingDegrees: GeoDistance.bearing(
          geometry.first.latitude,
          geometry.first.longitude,
          geometry[1].latitude,
          geometry[1].longitude,
        ),
      ),
    ];
    var cumulative = 0.0;
    var nextSampleDistance = MyWorldRules.commonRoadResampleIntervalMeters;
    for (var index = 0; index < geometry.length - 1; index++) {
      final start = geometry[index];
      final end = geometry[index + 1];
      final segmentDistance = _distance(start, end);
      if (segmentDistance <= 0) continue;
      final heading = GeoDistance.bearing(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
      while (nextSampleDistance < cumulative + segmentDistance) {
        final segmentDistanceFromStart = nextSampleDistance - cumulative;
        result.add(
          _interpolate(
            start,
            end,
            segmentDistanceFromStart / segmentDistance,
            sectionStartOffsetMeters + nextSampleDistance,
            heading,
          ),
        );
        nextSampleDistance += MyWorldRules.commonRoadResampleIntervalMeters;
      }
      cumulative += segmentDistance;
    }
    final last = geometry.last;
    if (result.isEmpty || result.last.offsetMeters < sectionStartOffsetMeters + cumulative) {
      final previous = geometry[geometry.length - 2];
      result.add(_RoadSample(
        point: last,
        offsetMeters: sectionStartOffsetMeters + cumulative,
        headingDegrees: GeoDistance.bearing(
          previous.latitude,
          previous.longitude,
          last.latitude,
          last.longitude,
        ),
      ));
    }
    return result;
  }

  _RoadSample _interpolate(
    MatchedRoadPoint start,
    MatchedRoadPoint end,
    double ratio,
    double offsetMeters,
    double headingDegrees,
  ) => _RoadSample(
    point: MatchedRoadPoint(
      latitude: start.latitude + (end.latitude - start.latitude) * ratio,
      longitude: start.longitude + (end.longitude - start.longitude) * ratio,
      headingDegrees: headingDegrees,
    ),
    offsetMeters: offsetMeters,
    headingDegrees: headingDegrees,
  );

  double _distance(MatchedRoadPoint first, MatchedRoadPoint second) =>
      GeoDistance.between(
        first.latitude,
        first.longitude,
        second.latitude,
        second.longitude,
      );
}

class _SectionSamples {
  const _SectionSamples(this.id, this.samples);

  final String id;
  final List<_RoadSample> samples;
}

class _RoadSample {
  const _RoadSample({
    required this.point,
    required this.offsetMeters,
    required this.headingDegrees,
  });

  final MatchedRoadPoint point;
  final double offsetMeters;
  final double headingDegrees;
}

class _SamplePair {
  const _SamplePair(this.first, this.second, this.distanceMeters,
      this.directionAgreement);

  final _RoadSample first;
  final _RoadSample second;
  final double distanceMeters;
  final double directionAgreement;
}

class _MatchedRun {
  _MatchedRun(_RoadSample first, _RoadSample second)
      : pairs = [
          _SamplePair(
            first,
            second,
            GeoDistance.between(
              first.point.latitude,
              first.point.longitude,
              second.point.latitude,
              second.point.longitude,
            ),
            _directionAgreement(first.headingDegrees, second.headingDegrees),
          ),
        ];

  final List<_SamplePair> pairs;

  _SamplePair get first => pairs.first;
  _SamplePair get last => pairs.last;
  int get count => pairs.length;
  double get distanceSum =>
      pairs.fold(0, (sum, pair) => sum + pair.distanceMeters);
  double get directionAgreementSum =>
      pairs.fold(0, (sum, pair) => sum + pair.directionAgreement);

  void add(_RoadSample first, _RoadSample second) {
    pairs.add(
      _SamplePair(
        first,
        second,
        GeoDistance.between(
          first.point.latitude,
          first.point.longitude,
          second.point.latitude,
          second.point.longitude,
        ),
        _directionAgreement(first.headingDegrees, second.headingDegrees),
      ),
    );
  }
}

class _SpatialSampleIndex {
  _SpatialSampleIndex(List<_RoadSample> samples) {
    for (final sample in samples) {
      _buckets.putIfAbsent(_keyFor(_cellFor(sample.point)), () => []).add(sample);
    }
  }

  static const double _cellDegrees = .0005;
  final Map<String, List<_RoadSample>> _buckets = {};

  _RoadSample? closestCompatible(_RoadSample input) {
    _RoadSample? closest;
    var closestDistance = double.infinity;
    final cell = _cellFor(input.point);
    for (var latitude = cell.latitude - 1; latitude <= cell.latitude + 1; latitude++) {
      for (var longitude = cell.longitude - 1;
          longitude <= cell.longitude + 1;
          longitude++) {
        for (final candidate
            in _buckets[_keyFor(_Cell(latitude, longitude))] ?? const []) {
          final direction = _angularDifference(
            input.headingDegrees,
            candidate.headingDegrees,
          );
          if (direction > MyWorldRules.commonRoadMaximumDirectionDifferenceDegrees) {
            continue;
          }
          final distance = GeoDistance.between(
            input.point.latitude,
            input.point.longitude,
            candidate.point.latitude,
            candidate.point.longitude,
          );
          if (distance <= MyWorldRules.commonRoadGeometryToleranceMeters &&
              distance < closestDistance) {
            closest = candidate;
            closestDistance = distance;
          }
        }
      }
    }
    return closest;
  }

  _Cell _cellFor(MatchedRoadPoint point) => _Cell(
    (point.latitude / _cellDegrees).floor(),
    (point.longitude / _cellDegrees).floor(),
  );

  String _keyFor(_Cell cell) => '${cell.latitude}:${cell.longitude}';
}

class _Cell {
  const _Cell(this.latitude, this.longitude);

  final int latitude;
  final int longitude;
}

class _Bounds {
  _Bounds.from(List<_RoadSample> samples)
      : minLatitude = samples.map((point) => point.point.latitude).reduce(math.min),
        maxLatitude = samples.map((point) => point.point.latitude).reduce(math.max),
        minLongitude = samples.map((point) => point.point.longitude).reduce(math.min),
        maxLongitude = samples.map((point) => point.point.longitude).reduce(math.max);

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool intersects(_Bounds other, double toleranceMeters) {
    final latitudePadding = toleranceMeters / 111320;
    final longitudePadding = toleranceMeters /
        math.max(111320 * math.cos(_radians((minLatitude + maxLatitude) / 2)), 1);
    return minLatitude - latitudePadding <= other.maxLatitude &&
        maxLatitude + latitudePadding >= other.minLatitude &&
        minLongitude - longitudePadding <= other.maxLongitude &&
        maxLongitude + longitudePadding >= other.minLongitude;
  }
}

double _angularDifference(double first, double second) =>
    ((first - second + 540) % 360 - 180).abs();

double _directionAgreement(double first, double second) =>
    (1 - _angularDifference(first, second) / 180).clamp(0.0, 1.0).toDouble();

double _radians(double degrees) => degrees * math.pi / 180;
