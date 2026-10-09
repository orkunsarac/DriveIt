/// Acquisition continuity, not a speed/acceleration or ownership rule.
/// Existing diagnostics already distinguish >5s and >15s sample gaps.
class GpsGapPolicy {
  static const shortGap = Duration(seconds: 5);
  static const breakAfter = Duration(seconds: 15);
  static bool breaks(DateTime previous, DateTime next) =>
      next.difference(previous) > breakAfter;
}
