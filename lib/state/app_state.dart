import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/city.dart';
import '../models/locked_app.dart';
import '../models/prayer.dart';
import '../services/app_usage_service.dart';
import '../services/installed_apps_service.dart';
import '../services/prayer_times_service.dart';

class AppState extends ChangeNotifier {
  List<LockedApp> apps = [];
  Difficulty difficulty = Difficulty.medium;

  List<PrayerSetting> prayers = defaultPrayerSettings();
  int delayMinutesAfterAthan = 5;
  MoroccanCity selectedCity = moroccanCities.first; // Casablanca

  // Stats
  int repsThisWeek = 0;
  int minutesEarnedToday = 0;
  int streakDays = 0;
  final List<bool> last7Days = List.filled(7, false);

  bool hasUsageAccess = false;

  /// Every launchable app on the device, for the "add app to lock" picker.
  List<AppInfo> availableApps = [];
  bool loadingAvailableApps = false;
  final Map<String, AppInfo> _appInfoCache = {};

  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  final AppUsageService _usageService = AppUsageService();
  final InstalledAppsService _installedAppsService = InstalledAppsService();

  Future<void> init() async {
    await _loadFromDisk();
    await refreshPrayerTimes();
    await _usageService.syncLockedPackages(
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
    await checkUsageAccess();
    await loadAvailableApps();
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

  /// Loads the device's installed apps for the picker, and caches each one
  /// by package name so displayNameFor()/iconFor() can resolve locked apps
  /// instantly without a repeat lookup.
  Future<void> loadAvailableApps({bool forceRefresh = false}) async {
    loadingAvailableApps = true;
    notifyListeners();
    availableApps = await _installedAppsService.getLaunchableApps(forceRefresh: forceRefresh);
    for (final info in availableApps) {
      _appInfoCache[info.packageName] = info;
    }
    loadingAvailableApps = false;
    notifyListeners();
  }

  /// Best-effort display name for a locked app. Falls back to the raw
  /// package name if the app isn't in the cache (e.g. it was uninstalled
  /// after being locked) — never breaks the UI over a missing lookup.
  String displayNameFor(String packageName) => _appInfoCache[packageName]?.name ?? packageName;

  Uint8List? iconFor(String packageName) => _appInfoCache[packageName]?.icon;

  /// Adds a newly-picked app to the lock list (if not already present) and
  /// syncs the native side immediately.
  Future<void> addLockedApp(String packageName) async {
    if (apps.any((a) => a.packageName == packageName)) return;
    apps.add(LockedApp(packageName: packageName));
    notifyListeners();
    await _persistApps();
    await _usageService.syncLockedPackages(
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
  }

  Future<void> removeLockedApp(String packageName) async {
    apps.removeWhere((a) => a.packageName == packageName);
    notifyListeners();
    await _persistApps();
    await _usageService.syncLockedPackages(
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    difficulty = Difficulty.values[prefs.getInt('difficulty') ?? Difficulty.medium.index];
    delayMinutesAfterAthan = prefs.getInt('delayMinutes') ?? 5;
    repsThisWeek = prefs.getInt('repsThisWeek') ?? 0;
    minutesEarnedToday = prefs.getInt('minutesEarnedToday') ?? 0;
    streakDays = prefs.getInt('streakDays') ?? 0;

    final cityName = prefs.getString('selectedCity');
    if (cityName != null) {
      selectedCity = moroccanCities.firstWhere(
        (c) => c.aladhanName == cityName,
        orElse: () => moroccanCities.first,
      );
    }

    final appsJson = prefs.getString('lockedApps');
    if (appsJson != null) {
      try {
        final decoded = jsonDecode(appsJson) as List;
        apps = decoded.map((j) => LockedApp.fromJson(j as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Failed to decode saved locked apps: $e');
      }
    }

    final enabledPrayerNames = prefs.getStringList('enabledPrayerNames');
    if (enabledPrayerNames != null) {
      for (final p in prayers) {
        p.enabled = enabledPrayerNames.contains(p.name.name);
      }
    }
  }

  Future<void> _persistApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lockedApps', jsonEncode(apps.map((a) => a.toJson()).toList()));
  }

  Future<void> _persistEnabledPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'enabledPrayerNames',
      prayers.where((p) => p.enabled).map((p) => p.name.name).toList(),
    );
  }

  Future<void> setCity(MoroccanCity city) async {
    selectedCity = city;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('selectedCity', city.aladhanName);
    await refreshPrayerTimes();
  }

  Future<void> refreshPrayerTimes() async {
    try {
      final result = await _prayerTimesService.fetchTodayTimings(selectedCity);
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
    await _persistApps();
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
