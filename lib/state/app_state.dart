import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/locked_app.dart';
import '../models/prayer.dart';
import '../services/prayer_times_service.dart';
import '../services/app_usage_service.dart';

class AppState extends ChangeNotifier {
  List<LockedApp> apps = List.of(defaultLockedApps);
  Difficulty difficulty = Difficulty.medium;

  List<PrayerSetting> prayers = defaultPrayerSettings();
  int delayMinutesAfterAthan = 5;
  String cityLabel = 'جارٍ تحديد الموقع…';

  // Stats
  int repsThisWeek = 0;
  int minutesEarnedToday = 0;
  int streakDays = 0;
  final List<bool> last7Days = List.filled(7, false);

  bool hasUsageAccess = false;

  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  final AppUsageService _usageService = AppUsageService();

  Future<void> init() async {
    await _loadFromDisk();
    await refreshPrayerTimes();
    await _usageService.syncLockedPackages(
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
    await checkUsageAccess();
  }

  /// Call again on app resume (e.g. after the user comes back from the
  /// system Usage Access settings screen) — there's no direct callback for
  /// "permission granted" here, so re-checking on resume is the standard
  /// pattern for this particular Android permission.
  Future<void> checkUsageAccess() async {
    hasUsageAccess = await _usageService.hasUsageAccess();
    notifyListeners();
  }

  Future<void> requestUsageAccess() => _usageService.requestUsageAccess();

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    difficulty = Difficulty.values[prefs.getInt('difficulty') ?? Difficulty.medium.index];
    delayMinutesAfterAthan = prefs.getInt('delayMinutes') ?? 5;
    repsThisWeek = prefs.getInt('repsThisWeek') ?? 0;
    minutesEarnedToday = prefs.getInt('minutesEarnedToday') ?? 0;
    streakDays = prefs.getInt('streakDays') ?? 0;

    // Enabled apps: if the key has never been written, keep each app's
    // built-in default (see defaultLockedApps) instead of forcing them all
    // off — StringList returns null on first run, not an empty list.
    final enabledPackages = prefs.getStringList('enabledAppPackages');
    if (enabledPackages != null) {
      for (final app in apps) {
        app.isEnabled = enabledPackages.contains(app.packageName);
      }
    }

    final enabledPrayerNames = prefs.getStringList('enabledPrayerNames');
    if (enabledPrayerNames != null) {
      for (final p in prayers) {
        p.enabled = enabledPrayerNames.contains(p.name.name);
      }
    }
  }

  Future<void> _persistEnabledApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'enabledAppPackages',
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
  }

  Future<void> _persistEnabledPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'enabledPrayerNames',
      prayers.where((p) => p.enabled).map((p) => p.name.name).toList(),
    );
  }

  Future<void> refreshPrayerTimes() async {
    try {
      final result = await _prayerTimesService.fetchTodayTimings();
      cityLabel = result.cityLabel;
      for (final p in prayers) {
        p.timeToday = result.timings[p.name.aladhanKey];
      }
      await _usageService.scheduleAthanLocks(
        prayers.where((p) => p.enabled && p.timeToday != null).toList(),
        delayMinutesAfterAthan,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Prayer time fetch failed: $e');
      // Fall back gracefully — do not block the rest of the app on network.
    }
  }

  Future<void> setDifficulty(Difficulty d) async {
    difficulty = d;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('difficulty', d.index);
  }

  Future<void> toggleApp(LockedApp app, bool value) async {
    app.isEnabled = value;
    notifyListeners();
    await _persistEnabledApps();
    await _usageService.syncLockedPackages(
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
  }

  Future<void> togglePrayer(PrayerSetting p, bool value) async {
    p.enabled = value;
    notifyListeners();
    await _persistEnabledPrayers();
    await refreshPrayerTimes(); // re-schedules native alarms
  }

  Future<void> setDelayMinutes(int minutes) async {
    delayMinutesAfterAthan = minutes.clamp(0, 60);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('delayMinutes', delayMinutesAfterAthan);
    await refreshPrayerTimes();
  }

  /// Called by RepCameraScreen once the target rep count is reached.
  Future<void> onRepsVerified(LockedApp app) async {
    repsThisWeek += app.repsFor(difficulty);
    minutesEarnedToday += app.minutesGranted;
    _bumpStreak();
    notifyListeners();
    await _usageService.grantTemporaryUnlock(app.packageName, app.minutesGranted);
    await _persistStats();
  }

  /// Called by RugScanScreen once the classifier confirms a prayer rug.
  Future<void> onRugVerified() async {
    _bumpStreak();
    notifyListeners();
    await _usageService.grantAthanUnlock();
    await _persistStats();
  }

  void _bumpStreak() {
    final todayIndex = DateTime.now().weekday % 7; // 0 = Sunday
    last7Days[todayIndex] = true;
    if (!last7Days.contains(false)) streakDays += 1;
  }

  Future<void> _persistStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('repsThisWeek', repsThisWeek);
    await prefs.setInt('minutesEarnedToday', minutesEarnedToday);
    await prefs.setInt('streakDays', streakDays);
  }
}
