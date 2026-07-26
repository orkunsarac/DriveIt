import 'package:geolocator/geolocator.dart';

class SpeedService {
  double _currentSpeed = 0;
  double _maxSpeed = 0;

  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;

  void reset() {
    _currentSpeed = 0;
    _maxSpeed = 0;
  }

  void update(Position position) {
    final speed = (position.speed * 3.6).clamp(0.0, 999.0);

    _currentSpeed = speed;

    if (speed > _maxSpeed) {
      _maxSpeed = speed;
    }
  }

  double calculateAverageSpeed(
    double totalDistance,
    Duration duration,
  ) {
    if (duration.inSeconds == 0) {
      return 0;
    }

    return (totalDistance / 1000) /
        (duration.inSeconds / 3600);
  }
}