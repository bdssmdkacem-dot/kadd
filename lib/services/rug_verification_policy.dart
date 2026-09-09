/// Deterministic multi-step policy for prayer-rug verification.
///
/// The image classifier supplies a confidence score for each independent
/// capture. This policy deliberately requires consistency across several
/// views instead of trusting one frame.
class RugVerificationPolicy {
  static const int requiredCaptures = 3;
  static const double perCaptureFloor = 0.70;
  static const double averageGate = 0.85;
  static const double maxSpread = 0.25;

  const RugVerificationPolicy._();

  static bool passes(List<double> confidences) {
    if (confidences.length != requiredCaptures) return false;
    if (confidences.any((value) => value < perCaptureFloor)) return false;

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
