import '../../../models/canonical_telemetry_point.dart';

enum CommonRoadTelemetryMappingStatus {
  success,
  mappingFailed,
  insufficientTelemetry,
}

class CommonRoadTelemetrySubset {
  const CommonRoadTelemetrySubset({
    required this.status,
    required this.telemetry,
    required this.startIndex,
    required this.endIndex,
    required this.mappingConfidence,
    required this.reason,
  });

  final CommonRoadTelemetryMappingStatus status;
  final List<CanonicalTelemetryPoint> telemetry;
  final int? startIndex;
  final int? endIndex;
  final double mappingConfidence;
  final String? reason;
}

class CommonRoadTelemetryPair {
  const CommonRoadTelemetryPair({
    required this.first,
    required this.second,
  });

  final CommonRoadTelemetrySubset first;
  final CommonRoadTelemetrySubset second;

  bool get isUsable =>
      first.status == CommonRoadTelemetryMappingStatus.success &&
      second.status == CommonRoadTelemetryMappingStatus.success;
}
