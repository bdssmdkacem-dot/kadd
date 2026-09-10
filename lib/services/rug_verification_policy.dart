/// Deterministic multi-step policy for prayer-rug verification.
///
/// Generic image labels are only a visual signal. The policy therefore adds
/// session-level anti-replay constraints: three strong captures, a minimum
/// interval between captures, and a bounded verification session.
class RugVerificationPolicy {
  static const int requiredCaptures = 3;
  static const double perCaptureFloor = 0.70;
  static const double averageGate = 0.85;
  static const double maxSpread = 0.25;
  static const Duration minimumCaptureInterval = Duration(milliseconds: 800);
  static const Duration maximumSessionDuration = Duration(seconds: 20);

  const RugVerificationPolicy._();

  static bool passes(
    List<double> confidences, {
    List<DateTime> captureTimes = const <DateTime>[],
  }) {
    if (confidences.length != requiredCaptures) return false;
    if (captureTimes.length != requiredCaptures) return false;
    if (confidences.any((value) => value < perCaptureFloor || value > 1.0)) {
      return false;
    }

    for (var index = 1; index < captureTimes.length; index++) {
      final interval = captureTimes[index].difference(captureTimes[index - 1]);
      if (interval < minimumCaptureInterval) return false;
    }

    if (captureTimes.last.difference(captureTimes.first) > maximumSessionDuration) {
      return false;
    }

    final average = confidences.reduce((a, b) => a + b) / confidences.length;
    final minimum = confidences.reduce((a, b) => a < b ? a : b);
    final maximum = confidences.reduce((a, b) => a > b ? a : b);

    return average >= averageGate && (maximum - minimum) <= maxSpread;
  }

  static double average(List<double> confidences) {
    if (confidences.isEmpty) return 0.0;
    return confidences.reduce((a, b) => a + b) / confidences.length;
  }
}
