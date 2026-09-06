import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kadd/state/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new state starts with zero daily earnings and streak', () async {
    final state = AppState();
    await state.init();

    expect(state.minutesEarnedToday, 0);
    expect(state.streakDays, 0);
    expect(state.repsThisWeek, 0);
  });

  test('activity is persisted and restored across AppState instances', () async {
    final first = AppState();
    await first.init();

    await first.onRugVerified();
    expect(first.streakDays, 1);

    final second = AppState();
    await second.init();

    expect(second.streakDays, 1);
    expect(second.last7Days.last, true);
  });

  test('today earnings are reset when persisted day is not today', () async {
    SharedPreferences.setMockInitialValues({
      'minutesEarnedToday': 25,
      'statsDayKey': '2000-01-01',
      'activityDates': <String>[],
    });

    final state = AppState();
    await state.init();

    expect(state.minutesEarnedToday, 0);
  });
}
