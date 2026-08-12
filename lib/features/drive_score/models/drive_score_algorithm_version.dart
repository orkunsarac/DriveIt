/// Versions supported by the in-memory Drive Score calculation pipeline.
///
/// A future version must be added deliberately; unsupported persisted values
/// are never silently interpreted as v1.
enum DriveScoreAlgorithmVersion {
  v1(1);

  const DriveScoreAlgorithmVersion(this.value);

  final int value;

  static DriveScoreAlgorithmVersion fromValue(int value) {
    for (final version in values) {
      if (version.value == value) return version;
    }
    throw UnsupportedDriveScoreAlgorithmVersion(value);
  }
}

class UnsupportedDriveScoreAlgorithmVersion implements Exception {
  const UnsupportedDriveScoreAlgorithmVersion(this.value);

  final int value;

  @override
  String toString() => 'Unsupported Drive Score algorithm version: $value';
}
