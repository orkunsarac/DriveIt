/// Starting calibration for the 150-point Tempo & Performance category.
///
/// Category maxima are constitutional product rules. The curves below are
/// absolute fallback curves until route-relative comparisons are available.
class TempoPerformanceCalibration {
  static const double cruisingSpeedMaximumScore = 60;
  static const double maxSpeedMaximumScore = 30;
  static const double distanceTimeMaximumScore = 60;
  static const double totalMaximumScore =
      cruisingSpeedMaximumScore +
      maxSpeedMaximumScore +
      distanceTimeMaximumScore;

  static const double stoppedSpeedMps = 5 / 3.6;
  static const Duration minimumMovingDuration = Duration(seconds: 90);
  static const double minimumReliableDistanceMeters = 1000;
  static const int minimumReliableSampleCount = 6;

  static const double maxSpeedNeighbourToleranceMps = 10;
  static const int maxSpeedMinimumSupportingSamples = 2;

  /// [km/h, normalised score] points for moving tempo.
  static const List<List<double>> cruisingSpeedCurve = <List<double>>[
    <double>[0, 0],
    <double>[30, .25],
    <double>[60, .58],
    <double>[100, .83],
    <double>[150, 1],
  ];

  /// [km/h, normalised score] points for validated peak speed.
  static const List<List<double>> maxSpeedCurve = <List<double>>[
    <double>[0, 0],
    <double>[80, .33],
    <double>[140, .67],
    <double>[200, 1],
  ];

  /// [km/h, normalised score] absolute fallback for route completion tempo.
  /// It intentionally uses elapsed time, including all confirmed stops.
  static const List<List<double>> distanceTimeCurve = <List<double>>[
    <double>[0, 0],
    <double>[20, .25],
    <double>[50, .58],
    <double>[80, .83],
    <double>[120, 1],
  ];

  const TempoPerformanceCalibration._();
}
