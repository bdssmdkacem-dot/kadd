import 'package:flutter_test/flutter_test.dart';
import 'package:kadd/state/app_state.dart';

void main() {
  test('serializes and restores app usage summary', () {
    final original = AppUsageSummary(
      reps: 48,
      minutes: 30,
      unlocks: 3,
      lastUnlockDate: '2026-09-10',
    );

    final restored = AppUsageSummary.fromJson(original.toJson());

    expect(restored.reps, 48);
    expect(restored.minutes, 30);
    expect(restored.unlocks, 3);
    expect(restored.lastUnlockDate, '2026-09-10');
  });

  test('defensively clamps invalid numeric values', () {
    final summary = AppUsageSummary.fromJson({
      'reps': -10,
      'minutes': 9999999999,
      'unlocks': -4,
      'lastUnlockDate': 123,
    });

    expect(summary.reps, 0);
    expect(summary.minutes, 100000000);
    expect(summary.unlocks, 0);
    expect(summary.lastUnlockDate, isNull);
  });
}
