import '../telemetry/telemetry_sample.dart';

class TelemetrySession {
  final List<TelemetrySample> samples;

  const TelemetrySession({
    required this.samples,
  });

  int get sampleCount => samples.length;

  bool get isEmpty => samples.isEmpty;

  bool get isNotEmpty => samples.isNotEmpty;
}