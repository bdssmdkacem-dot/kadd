import 'package:flutter_test/flutter_test.dart';
import 'package:kadd/services/exercise_rep_tracker.dart';

void main() {
  group('ExerciseRepTracker', () {
    test('requires confirmed down then up before counting', () {
      final tracker = ExerciseRepTracker();
      final start = DateTime(2026, 1, 1, 10);

      for (var i = 0; i < 3; i++) {
        expect(
          tracker.update(goodPosition: true, upPosition: false, now: start.add(Duration(milliseconds: i * 100))),
          isFalse,
        );
      }
      expect(tracker.isDown, isTrue);
      expect(tracker.reps, 0);

      expect(
        tracker.update(goodPosition: false, upPosition: true, now: start.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        tracker.update(goodPosition: false, upPosition: true, now: start.add(const Duration(milliseconds: 1200))),
        isFalse,
      );
      expect(
        tracker.update(goodPosition: false, upPosition: true, now: start.add(const Duration(milliseconds: 1400))),
        isTrue,
      );
      expect(tracker.reps, 1);
      expect(tracker.isDown, isFalse);
    });

    test('ignores noisy single frames and cooldown duplicates', () {
      final tracker = ExerciseRepTracker();
      final start = DateTime(2026, 1, 1, 10);

      for (var i = 0; i < 3; i++) {
        tracker.update(goodPosition: true, upPosition: false, now: start.add(Duration(milliseconds: i * 100)));
      }
      for (var i = 0; i < 3; i++) {
        tracker.update(goodPosition: false, upPosition: true, now: start.add(Duration(seconds: 1, milliseconds: i * 100)));
      }
      expect(tracker.reps, 1);

      // A new down/up cycle inside the cooldown must not create a second rep.
      for (var i = 0; i < 3; i++) {
        tracker.update(goodPosition: true, upPosition: false, now: start.add(const Duration(milliseconds: 1300 + 100)));
      }
      for (var i = 0; i < 3; i++) {
        tracker.update(goodPosition: false, upPosition: true, now: start.add(const Duration(milliseconds: 1500 + 100)));
      }
      expect(tracker.reps, 1);
    });

    test('reset returns the session to its initial state', () {
      final tracker = ExerciseRepTracker();
      final start = DateTime(2026, 1, 1, 10);
      for (var i = 0; i < 3; i++) {
        tracker.update(goodPosition: true, upPosition: false, now: start.add(Duration(milliseconds: i * 100)));
      }
      for (var i = 0; i < 3; i++) {
        tracker.update(goodPosition: false, upPosition: true, now: start.add(Duration(seconds: 1, milliseconds: i * 100)));
      }
      expect(tracker.reps, 1);

      tracker.reset();
      expect(tracker.reps, 0);
      expect(tracker.isDown, isFalse);
      expect(tracker.isGoodPosition, isFalse);
      expect(tracker.lastRepAt, isNull);
    });
  });
}
