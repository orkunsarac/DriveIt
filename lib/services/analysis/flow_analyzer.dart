import 'dart:math';

import '../../models/analysis/flow_report.dart';
import 'telemetry_session.dart';

class FlowAnalyzer {
  static const double _stopSpeed = 5;

  FlowReport analyze(TelemetrySession session) {
    if (session.samples.isEmpty) {
      return const FlowReport(
        score: 100,
        cruiseSpeed: 0,
        speedStability: 100,
        oscillationCount: 0,
      );
    }

    final speeds = session.samples
        .where((s) => s.speed >= _stopSpeed)
        .map((s) => s.speed)
        .toList();

    if (speeds.length < 2) {
      return const FlowReport(
        score: 100,
        cruiseSpeed: 0,
        speedStability: 100,
        oscillationCount: 0,
      );
    }

    final average =
        speeds.reduce((a, b) => a + b) / speeds.length;

    double variance = 0;

    for (final speed in speeds) {
      variance += pow(speed - average, 2);
    }

    variance /= speeds.length;

    final std = sqrt(variance);

    double score = 100 - (std * 2);

    score = score.clamp(0.0, 100.0).toDouble();

    final double stability =
    (100 - std).clamp(0.0, 100.0).toDouble();

    return FlowReport(
      score: score,
      cruiseSpeed: average,
      speedStability: stability,
      oscillationCount: 0,
    );
  }
}