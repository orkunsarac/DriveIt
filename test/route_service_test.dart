import 'package:driveit_project/services/route_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteService GPS filtering', () {
    test('stationary jitter is not appended to the route', () {
      final service = RouteService();

      expect(service.addCoordinate(41.000000, 29.000000, accuracy: 5), isTrue);
      expect(service.addCoordinate(41.000010, 29.000010, accuracy: 5), isFalse);

      expect(service.routePoints, hasLength(1));
      expect(service.distance, 0);
    });

    test('ordered movement creates one open route', () {
      final service = RouteService();

      service.addCoordinate(41.000000, 29.000000, accuracy: 5);
      service.addCoordinate(41.000060, 29.000000, accuracy: 5);
      service.addCoordinate(41.000120, 29.000000, accuracy: 5);

      expect(service.routePoints, hasLength(3));
      expect(service.routePoints.first, isNot(service.routePoints.last));
      expect(service.polylines.single.points, service.routePoints);
    });

    test('poor accuracy and impossible jumps are rejected', () {
      final service = RouteService();

      service.addCoordinate(41.000000, 29.000000, accuracy: 5);
      expect(service.addCoordinate(41.000100, 29.000000, accuracy: 60), isFalse);
      expect(service.addCoordinate(41.010000, 29.000000, accuracy: 5), isFalse);

      expect(service.routePoints, hasLength(1));
    });
  });
}
