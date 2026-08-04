import 'package:geolocator/geolocator.dart';

class SpeedService {
  double _currentSpeed = 0;
  double _maxSpeed = 0;
  Position? _anchorPosition;
  DateTime? _anchorTime;
  bool _moving = false;
  final List<double> _speedWindow = [];

  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  bool get isMoving => _moving;

  void reset() {
    _currentSpeed = 0;
    _maxSpeed = 0;
    _anchorPosition = null;
    _anchorTime = null;
    _moving = false;
    _speedWindow.clear();
  }

  void update(Position position) {
    if (!position.accuracy.isFinite || position.accuracy > 30) {
      _currentSpeed = 0;
      return;
    }

    _anchorPosition ??= position;
    _anchorTime ??= position.timestamp;
    final anchor = _anchorPosition!;
    final displacement = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      position.latitude,
      position.longitude,
    );

    // GPS speed commonly oscillates while stationary. Until the device has
    // moved outside a 10 m stop radius, treat it as zero.
    var candidateKmh = 0.0;
    final wasMoving = _moving;
    if (displacement >= 10) {
      _moving = true;
      _anchorPosition = position;
      _anchorTime = position.timestamp;
    } else if (_anchorTime != null &&
        position.timestamp.difference(_anchorTime!).inSeconds >= 3) {
      _moving = false;
    }
    if (wasMoving && !_moving) _speedWindow.clear();
    final rawKmh = position.speed.isFinite && position.speed > 0
        ? position.speed * 3.6
        : 0.0;
    if (_moving) candidateKmh = rawKmh.clamp(0.0, 350.0).toDouble();

    _speedWindow.add(candidateKmh);
    if (_speedWindow.length > 5) _speedWindow.removeAt(0);
    final sorted = [..._speedWindow]..sort();
    final filtered = sorted[sorted.length ~/ 2];
    _currentSpeed = filtered < 3 ? 0 : filtered;

    if (_currentSpeed > _maxSpeed) {
      _maxSpeed = _currentSpeed;
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
