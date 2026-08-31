import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/features/my_world/services/world_trace_visibility_policy.dart';

void main() {
  const policy = WorldTraceVisibilityPolicy();

  test('short traces are filtered at distant zoom levels', () {
    expect(policy.isVisible(distanceMeters: 100, zoom: 10), isFalse);
    expect(policy.isVisible(distanceMeters: 100, zoom: 13), isTrue);
    expect(policy.isVisible(distanceMeters: 500, zoom: 7), isFalse);
    expect(policy.isVisible(distanceMeters: 2500, zoom: 7), isTrue);
    expect(policy.isVisible(distanceMeters: 1000, zoom: 6), isFalse);
    expect(policy.areMarkersVisible(5), isFalse);
    expect(policy.areMarkersVisible(10), isTrue);
  });

  test('marker radius remains small and shrinks with zoom out', () {
    final near = policy.markerRadiusMeters(zoom: 13, selected: false);
    final far = policy.markerRadiusMeters(zoom: 7, selected: false);
    expect(near, lessThan(far));
    expect(
      policy.markerRadiusMeters(zoom: 13, selected: false),
      lessThanOrEqualTo(5),
    );
    expect(
      policy.markerRadiusMeters(zoom: 13, selected: true),
      greaterThanOrEqualTo(2),
    );
  });
}
