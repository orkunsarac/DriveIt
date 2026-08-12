class WorldDriveLifecycleInfo {
  const WorldDriveLifecycleInfo({
    required this.hasActiveTrace,
    required this.activeTraceCount,
    required this.activeDistanceMeters,
  });

  final bool hasActiveTrace;
  final int activeTraceCount;
  final double activeDistanceMeters;
}
