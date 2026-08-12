import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../config/mapbox_config.dart';
import '../../config/my_world_rules.dart';
import '../../models/map_matching_input.dart';
import '../../models/matched_road_point.dart';
import '../../models/matched_road_section.dart';
import '../../models/validated_road.dart';
import '../../services/geo_distance.dart';
import '../../services/gps_route_preprocessor.dart';
import '../../services/map_matching_chunker.dart';
import '../road_matching_provider.dart';
import 'mapbox_http_transport.dart';
import 'mapbox_response_dto.dart';

class MapboxRoadMatchingProvider implements RoadMatchingProvider {
  final MapboxHttpTransport _transport;
  final GpsRoutePreprocessor preprocessor;
  final MapMatchingChunker chunker;
  final String accessToken;
  final Uri _endpoint;

  MapboxRoadMatchingProvider({
    MapboxHttpTransport? transport,
    this.preprocessor = const GpsRoutePreprocessor(),
    this.chunker = const MapMatchingChunker(),
    this.accessToken = MapboxConfig.accessToken,
    Uri? endpoint,
  }) : _transport = transport ?? IoMapboxHttpTransport(),
       _endpoint =
           endpoint ??
           Uri.parse('https://api.mapbox.com/matching/v5/mapbox/driving');

  @override
  String get providerId => 'mapbox-map-matching-v5-driving';

  @override
  Future<RoadMatchingResult> match(RoadMatchingRequest request) async {
    if (accessToken.trim().isEmpty) {
      return RoadMatchingResult.failure(
        kind: RoadMatchingFailureKind.missingAccessToken,
        message: 'Mapbox access token is not configured.',
      );
    }

    final cleaned = preprocessor.clean(request.rawRoute);
    final chunks = chunker.build(cleaned.traces);
    if (chunks.isEmpty) {
      return RoadMatchingResult.failure(
        kind: RoadMatchingFailureKind.insufficientInput,
        message: 'The route does not contain a continuous pair of GPS points.',
      );
    }

    final sections = <MatchedRoadSection>[];
    RoadMatchingFailureKind failureKind = RoadMatchingFailureKind.none;
    String? errorMessage;
    var unmatchedChunks = 0;

    for (final chunk in chunks) {
      final response = await _matchChunk(chunk);
      if (!response.isSuccess) {
        unmatchedChunks++;
        failureKind = _preferFailure(failureKind, response.failureKind);
        errorMessage ??= response.errorMessage;
        if (response.failureKind == RoadMatchingFailureKind.authentication ||
            response.failureKind.isRetryable) {
          break;
        }
        continue;
      }
      for (final section in response.sections) {
        _appendOrMerge(sections, section);
      }
    }

    if (sections.isEmpty) {
      return RoadMatchingResult.failure(
        kind: failureKind == RoadMatchingFailureKind.none
            ? RoadMatchingFailureKind.apiError
            : failureKind,
        message: errorMessage ?? 'Mapbox returned no usable road geometry.',
      );
    }

    final geometry = sections
        .expand((section) => section.geometry)
        .toList(growable: false);
    final distance = sections.fold<double>(
      0,
      (total, section) => total + section.distanceMeters,
    );
    final confidence = _weightedConfidence(sections);
    final isPartial =
        unmatchedChunks > 0 || sections.length > cleaned.traces.length;
    return RoadMatchingResult(
      sections: List.unmodifiable(sections),
      geometry: List.unmodifiable(geometry),
      validDistanceMeters: distance,
      status: isPartial
          ? RoadValidationStatus.partiallyValidated
          : RoadValidationStatus.validated,
      confidence: confidence,
      directionKey: _directionKey(sections),
      averageHeadingDegrees: _averageHeading(geometry),
      failureKind: failureKind,
      errorMessage: errorMessage,
    );
  }

  Future<_ChunkResult> _matchChunk(MapMatchingChunk chunk) async {
    final uri = _endpoint.replace(
      queryParameters: <String, String>{'access_token': accessToken},
    );
    final coordinates = chunk.points
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final radiuses = List<String>.filled(
      chunk.points.length,
      MyWorldRules.mapMatchingRadiusMeters.toStringAsFixed(0),
    ).join(';');
    final formBody = Uri(
      queryParameters: <String, String>{
        'coordinates': coordinates,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'false',
        'tidy': 'true',
        'radiuses': radiuses,
      },
    ).query;

    try {
      final response = await _transport.post(
        uri: uri,
        formBody: formBody,
        timeout: MyWorldRules.mapMatchingTimeout,
      );
      final httpFailure = _httpFailure(response.statusCode);
      if (httpFailure != RoadMatchingFailureKind.none) {
        return _ChunkResult.failure(
          httpFailure,
          _safeHttpMessage(response.statusCode),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return _ChunkResult.failure(
          RoadMatchingFailureKind.malformedResponse,
          'Mapbox returned an invalid response body.',
        );
      }
      final dto = MapboxMapMatchingResponseDto.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (dto.code != 'Ok') {
        return _ChunkResult.failure(
          RoadMatchingFailureKind.apiError,
          _safeApiMessage(dto.code),
        );
      }

      final sections = <MatchedRoadSection>[];
      for (
        var matchingIndex = 0;
        matchingIndex < dto.matchings.length;
        matchingIndex++
      ) {
        final matching = dto.matchings[matchingIndex];
        if (matching.geometry.length < 2) continue;
        final geometry = _withHeadings(matching.geometry, matching.confidence);
        sections.add(
          MatchedRoadSection(
            id: 't${chunk.traceIndex}:c${chunk.chunkIndex}:m$matchingIndex',
            geometry: geometry,
            distanceMeters: _geometryDistance(geometry),
            confidence: matching.confidence,
            sourceTraceIndex: chunk.traceIndex,
            sourceChunkIndex: chunk.chunkIndex,
          ),
        );
      }
      if (sections.isEmpty) {
        return _ChunkResult.failure(
          RoadMatchingFailureKind.apiError,
          'Mapbox returned no matching geometry.',
        );
      }
      return _ChunkResult.success(sections);
    } on TimeoutException {
      return _ChunkResult.failure(
        RoadMatchingFailureKind.timeout,
        'Mapbox validation timed out.',
      );
    } on SocketException {
      return _ChunkResult.failure(
        RoadMatchingFailureKind.network,
        'Mapbox validation is waiting for a network connection.',
      );
    } on FormatException {
      return _ChunkResult.failure(
        RoadMatchingFailureKind.malformedResponse,
        'Mapbox returned malformed JSON.',
      );
    } on TypeError {
      return _ChunkResult.failure(
        RoadMatchingFailureKind.malformedResponse,
        'Mapbox returned an unexpected response shape.',
      );
    } catch (_) {
      return _ChunkResult.failure(
        RoadMatchingFailureKind.network,
        'Mapbox validation could not be completed.',
      );
    }
  }

  List<MatchedRoadPoint> _withHeadings(
    List<MapboxCoordinateDto> coordinates,
    double? confidence,
  ) {
    final points = <MatchedRoadPoint>[];
    for (var index = 0; index < coordinates.length; index++) {
      final coordinate = coordinates[index];
      final neighbor = index < coordinates.length - 1
          ? coordinates[index + 1]
          : coordinates[index - 1];
      final heading = index < coordinates.length - 1
          ? GeoDistance.bearing(
              coordinate.latitude,
              coordinate.longitude,
              neighbor.latitude,
              neighbor.longitude,
            )
          : GeoDistance.bearing(
              neighbor.latitude,
              neighbor.longitude,
              coordinate.latitude,
              coordinate.longitude,
            );
      points.add(
        MatchedRoadPoint(
          latitude: coordinate.latitude,
          longitude: coordinate.longitude,
          headingDegrees: heading,
          providerRoadReference: null,
          confidence: confidence,
        ),
      );
    }
    return List.unmodifiable(points);
  }

  void _appendOrMerge(
    List<MatchedRoadSection> sections,
    MatchedRoadSection incoming,
  ) {
    if (sections.isEmpty) {
      sections.add(incoming);
      return;
    }
    final previous = sections.last;
    final adjacentChunks =
        previous.sourceTraceIndex == incoming.sourceTraceIndex &&
        incoming.sourceChunkIndex == previous.sourceChunkIndex + 1;
    if (!adjacentChunks) {
      sections.add(incoming);
      return;
    }

    final overlap = _overlapLength(previous.geometry, incoming.geometry);
    if (overlap == 0) {
      sections.add(incoming);
      return;
    }
    final geometry = <MatchedRoadPoint>[
      ...previous.geometry,
      ...incoming.geometry.skip(overlap),
    ];
    sections[sections.length - 1] = MatchedRoadSection(
      id: previous.id,
      geometry: List.unmodifiable(geometry),
      distanceMeters: _geometryDistance(geometry),
      confidence: _weightedPairConfidence(previous, incoming),
      sourceTraceIndex: previous.sourceTraceIndex,
      sourceChunkIndex: incoming.sourceChunkIndex,
    );
  }

  int _overlapLength(
    List<MatchedRoadPoint> previous,
    List<MatchedRoadPoint> incoming,
  ) {
    final maximum = math.min(
      MyWorldRules.mapMatchingChunkOverlap * 8,
      math.min(previous.length, incoming.length),
    );
    for (var count = maximum; count >= 1; count--) {
      var matches = true;
      for (var index = 0; index < count; index++) {
        final a = previous[previous.length - count + index];
        final b = incoming[index];
        if (GeoDistance.between(
              a.latitude,
              a.longitude,
              b.latitude,
              b.longitude,
            ) >
            MyWorldRules.chunkGeometryMergeToleranceMeters) {
          matches = false;
          break;
        }
      }
      if (matches) return count;
    }
    return 0;
  }

  double _geometryDistance(List<MatchedRoadPoint> geometry) {
    var total = 0.0;
    for (var index = 1; index < geometry.length; index++) {
      final previous = geometry[index - 1];
      final current = geometry[index];
      total += GeoDistance.between(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }
    return total;
  }

  double? _weightedConfidence(List<MatchedRoadSection> sections) {
    var weighted = 0.0;
    var distance = 0.0;
    for (final section in sections) {
      final confidence = section.confidence;
      if (confidence == null) continue;
      weighted += confidence * section.distanceMeters;
      distance += section.distanceMeters;
    }
    return distance > 0 ? weighted / distance : null;
  }

  double? _weightedPairConfidence(
    MatchedRoadSection first,
    MatchedRoadSection second,
  ) {
    if (first.confidence == null) return second.confidence;
    if (second.confidence == null) return first.confidence;
    final total = first.distanceMeters + second.distanceMeters;
    if (total <= 0) return null;
    return (first.confidence! * first.distanceMeters +
            second.confidence! * second.distanceMeters) /
        total;
  }

  String _directionKey(List<MatchedRoadSection> sections) {
    final first = sections.first.geometry.first;
    final last = sections.last.geometry.last;
    String key(MatchedRoadPoint point) =>
        '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
    return '${key(first)}>${key(last)}';
  }

  double? _averageHeading(List<MatchedRoadPoint> geometry) {
    final headings = geometry
        .map((point) => point.headingDegrees)
        .whereType<double>()
        .toList(growable: false);
    if (headings.isEmpty) return null;
    var x = 0.0;
    var y = 0.0;
    for (final heading in headings) {
      final radians = heading * math.pi / 180;
      x += math.cos(radians);
      y += math.sin(radians);
    }
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  RoadMatchingFailureKind _httpFailure(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return RoadMatchingFailureKind.none;
    }
    if (statusCode == 401 || statusCode == 403) {
      return RoadMatchingFailureKind.authentication;
    }
    if (statusCode == 429) return RoadMatchingFailureKind.rateLimited;
    if (statusCode >= 500) return RoadMatchingFailureKind.server;
    return RoadMatchingFailureKind.invalidInput;
  }

  RoadMatchingFailureKind _preferFailure(
    RoadMatchingFailureKind current,
    RoadMatchingFailureKind candidate,
  ) {
    if (current == RoadMatchingFailureKind.none || candidate.isRetryable) {
      return candidate;
    }
    return current;
  }

  String _safeHttpMessage(int statusCode) =>
      'Mapbox validation failed with HTTP status $statusCode.';

  String _safeApiMessage(String code) =>
      code.isEmpty ? 'Mapbox validation failed.' : 'Mapbox error: $code.';
}

class _ChunkResult {
  final List<MatchedRoadSection> sections;
  final RoadMatchingFailureKind failureKind;
  final String? errorMessage;

  const _ChunkResult({
    required this.sections,
    required this.failureKind,
    required this.errorMessage,
  });

  bool get isSuccess => sections.isNotEmpty;

  factory _ChunkResult.success(List<MatchedRoadSection> sections) =>
      _ChunkResult(
        sections: sections,
        failureKind: RoadMatchingFailureKind.none,
        errorMessage: null,
      );

  factory _ChunkResult.failure(RoadMatchingFailureKind kind, String message) =>
      _ChunkResult(
        sections: const [],
        failureKind: kind,
        errorMessage: message,
      );
}
