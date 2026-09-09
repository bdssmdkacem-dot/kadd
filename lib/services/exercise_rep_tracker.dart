import 'package:flutter/foundation.dart';

/// Small, deterministic state machine for exercise verification.
///
/// Keeping rep transitions outside the camera widget makes the critical
/// verification rule unit-testable and prevents UI rebuilds from changing
/// the counting state.
class ExerciseRepTracker extends ChangeNotifier {
  ExerciseRepTracker({
    this.framesToConfirm = 3,
    this.minRepInterval = const Duration(milliseconds: 500),
  })  : assert(framesToConfirm > 0),
        assert(minRepInterval >= Duration.zero);

  final int framesToConfirm;
  final Duration minRepInterval;

  int reps = 0;
  bool isDown = false;
  bool isGoodPosition = false;
  int consecutiveGoodFrames = 0;
  int consecutiveUpFrames = 0;
  DateTime? lastRepAt;

  /// Feeds one debounced pose classification into the state machine.
  /// Returns true only when a new repetition is accepted.
  bool update({
    required bool goodPosition,
    required bool upPosition,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    consecutiveGoodFrames = goodPosition ? consecutiveGoodFrames + 1 : 0;
    consecutiveUpFrames = upPosition ? consecutiveUpFrames + 1 : 0;

    var counted = false;
    if (!isDown && consecutiveGoodFrames >= framesToConfirm) {
      isDown = true;
    } else if (isDown && consecutiveUpFrames >= framesToConfirm) {
      final canCount = lastRepAt == null ||
          timestamp.difference(lastRepAt!) >= minRepInterval;
      if (canCount) {
        isDown = false;
        reps++;
        lastRepAt = timestamp;
        counted = true;
      }
    }

    isGoodPosition = consecutiveGoodFrames >= framesToConfirm;
    notifyListeners();
    return counted;
  }

  void reset() {
    reps = 0;
    isDown = false;
    isGoodPosition = false;
    consecutiveGoodFrames = 0;
    consecutiveUpFrames = 0;
    lastRepAt = null;
    notifyListeners();
  }
}
