import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/state/app_state.dart';

void main() {
  group('statistics persistence boundaries', () {
    test('invalid and negative app usage values are normalized', () {
      final summary = AppUsageSummary.fromJson({
        'reps': -10,
        'minutes': '25',
        'unlocks': 999999999999,
        'lastUnlockDate': 'not-a-day',
      });

      expect(summary.reps, 0);
      expect(summary.minutes, 25);
      expect(summary.unlocks, 100000000);
      expect(summary.lastUnlockDate, isNull);
    });

    test('valid day key survives app usage serialization', () {
      final summary = AppUsageSummary(
        reps: 12,
        minutes: 30,
        unlocks: 2,
        lastUnlockDate: '2026-09-10',
      );

      final decoded = jsonDecode(jsonEncode(summary.toJson())) as Map<String, dynamic>;
      final restored = AppUsageSummary.fromJson(decoded);

      expect(restored.reps, 12);
      expect(restored.minutes, 30);
      expect(restored.unlocks, 2);
      expect(restored.lastUnlockDate, '2026-09-10');
    });

    test('expired daily and weekly counters reset on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'repsThisWeek': 20,
        'repsWeekKey': '2026-08-31',
        'minutesEarnedToday': 45,
        'statsDayKey': '2026-09-09',
        'activityDates': <String>['2026-09-09', '2026-09-08'],
      });

      final state = AppState();
      await state.init();

      expect(state.repsThisWeek, 0);
      expect(state.minutesEarnedToday, 0);
      expect(state.streakDays, 0);
    });
  });
}
