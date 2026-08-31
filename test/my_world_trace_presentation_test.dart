import 'package:flutter_test/flutter_test.dart';

import 'package:driveit_project/features/my_world/models/active_world_trace.dart';
import 'package:driveit_project/features/my_world/models/matched_road_point.dart';
import 'package:driveit_project/features/my_world/models/world_map_read_model.dart';
import 'package:driveit_project/features/my_world/services/world_trace_presentation_service.dart';

void main() {
  const service = WorldTracePresentationService();

  ActiveWorldTrace trace(String id, String direction) => ActiveWorldTrace(
        id: id,
        sourceDriveSessionId: id,
        validatedRoadId: 'road',
        matchedSectionId: 'section',
        startOffsetMeters: 0,
        endOffsetMeters: 1000,
        directionKey: direction,
        minLatitude: 40,
        maxLatitude: 40.01,
        minLongitude: 29,
        maxLongitude: 29.01,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        processingVersion: 1,
      );

  List<MatchedRoadPoint> geometry({required bool reverse}) => reverse
      ? const [
          MatchedRoadPoint(latitude: 40, longitude: 29.01),
          MatchedRoadPoint(latitude: 40, longitude: 29),
        ]
      : const [
          MatchedRoadPoint(latitude: 40, longitude: 29),
          MatchedRoadPoint(latitude: 40, longitude: 29.01),
        ];

  test('opposite near traces receive presentation separation only', () {
    final a = ResolvedWorldTrace(
      trace: trace('a', 'east'),
      geometry: geometry(reverse: false),
      visualVariant: 0,
    );
    final b = ResolvedWorldTrace(
      trace: trace('b', 'west'),
      geometry: geometry(reverse: true),
      visualVariant: 1,
    );
    final ids = service.oppositeTraceIds([a, b]);
    expect(ids, containsAll(<String>['a', 'b']));
    final partners = service.oppositePartnerMap([a, b]);
    expect(partners['a']?.trace.id, 'b');
    expect(partners['b']?.trace.id, 'a');
    final rendered = service.renderGeometry(
      trace: a,
      separateOpposite: true,
      zoom: 13,
    );
    expect(rendered.first.longitude, isNot(a.geometry.first.longitude));
    expect(a.geometry.first.longitude, 29);
  });

  test('same direction trace is not offset', () {
    final a = ResolvedWorldTrace(
      trace: trace('a', 'east'),
      geometry: geometry(reverse: false),
      visualVariant: 0,
    );
    final b = ResolvedWorldTrace(
      trace: trace('b', 'east'),
      geometry: geometry(reverse: false),
      visualVariant: 1,
    );
    expect(service.oppositeTraceIds([a, b]), isEmpty);
    final rendered = service.renderGeometry(
      trace: a,
      separateOpposite: false,
      zoom: 13,
    );
    expect(rendered.first.latitude, a.geometry.first.latitude);
    expect(rendered.first.longitude, a.geometry.first.longitude);
  });

  test('opposite separation is limited to the local overlap', () {
    final a = ResolvedWorldTrace(
      trace: trace('a', 'east'),
      geometry: const [
        MatchedRoadPoint(latitude: 40, longitude: 29),
        MatchedRoadPoint(latitude: 40, longitude: 29.004),
        MatchedRoadPoint(latitude: 40, longitude: 29.008),
      ],
      visualVariant: 0,
    );
    final b = ResolvedWorldTrace(
      trace: trace('b', 'west'),
      geometry: const [
        MatchedRoadPoint(latitude: 40, longitude: 29.004),
        MatchedRoadPoint(latitude: 40, longitude: 29),
      ],
      visualVariant: 1,
    );
    final rendered = service.renderGeometry(
      trace: a,
      separateOpposite: true,
      oppositePartner: b,
      zoom: 15,
    );
    expect(rendered.first.longitude, isNot(a.geometry.first.longitude));
    expect(rendered.last.longitude, a.geometry.last.longitude);
  });
}
