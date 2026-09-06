import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kadd/models/city.dart';
import 'package:kadd/services/app_usage_service.dart';
import 'package:kadd/services/installed_apps_service.dart';
import 'package:kadd/services/prayer_times_service.dart';
import 'package:kadd/models/installed_app.dart';
import 'package:kadd/state/app_state.dart';

class FakeAppUsageService extends AppUsageService {
  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> syncLockedPackages(List<String> packages) async {}

  @override
  Future<void> scheduleAthanLocks(List<PrayerSetting> prayers, int delayMinutes) async {}

  @override
  Future<void> grantAthanUnlock() async {}

  @override
  Future<void> grantTemporaryUnlock(String packageName, int minutes) async {}
}

class FakeInstalledAppsService extends InstalledAppsService {
  @override
  Future<List<InstalledApp>> getLaunchableApps({bool forceRefresh = false}) async => [];
}

class FakePrayerTimesService extends PrayerTimesService {
  @override
  Future<PrayerTimesResult> fetchTodayTimings(MoroccanCity city) async {
    final now = DateTime.now();
    return PrayerTimesResult(
      timings: {
        'Fajr': DateTime(now.year, now.month, now.day, 5),
        'Dhuhr': DateTime(now.year, now.month, now.day, 12),
        'Asr': DateTime(now.year, now.month, now.day, 15),
        'Maghrib': DateTime(now.year, now.month, now.day, 19),
        'Isha': DateTime(now.year, now.month, now.day, 21),
      },
    );
  }
}

AppState createState() => AppState(
      prayerTimesService: FakePrayerTimesService(),
      usageService: FakeAppUsageService(),
      installedAppsService: FakeInstalledAppsService(),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new state starts with zero daily earnings and streak', () async {
    final state = createState();
    await state.init();

    expect(state.minutesEarnedToday, 0);
    expect(state.streakDays, 0);
    expect(state.repsThisWeek, 0);
  });

  test('activity is persisted and restored across AppState instances', () async {
    final first = createState();
    await first.init();

    await first.onRugVerified();
    expect(first.streakDays, 1);

    final second = createState();
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

    final state = createState();
    await state.init();

    expect(state.minutesEarnedToday, 0);
  });
}
