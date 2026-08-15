import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/city.dart';
import '../models/locked_app.dart';
import '../models/prayer.dart';
import '../services/app_usage_service.dart';
import '../services/ads_service.dart';
import '../services/installed_apps_service.dart';
import '../services/prayer_times_service.dart';

class AppState extends ChangeNotifier {
  List<LockedApp> apps = [];
  Difficulty difficulty = Difficulty.medium;

  List<PrayerSetting> prayers = defaultPrayerSettings();
  int delayMinutesAfterAthan = 5;
  MoroccanCity selectedCity = moroccanCities.first;

  int repsThisWeek = 0;
  int minutesEarnedToday = 0;
  int streakDays = 0;
  final List<bool> last7Days = List.filled(7, false);

  bool hasUsageAccess = false;

  List<AppInfo> availableApps = [];
  bool loadingAvailableApps = false;
  final Map<String, AppInfo> _appInfoCache = {};

  Object? get availableAppsError => _installedAppsService.lastError;

  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  final AppUsageService _usageService = AppUsageService();
  final InstalledAppsService _installedAppsService = InstalledAppsService();

  Future<void> init() async {
    // Each startup subsystem is isolated. A native lock-service failure must
    // never stop the installed-app picker (or the rest of the UI) loading.
    try {
      await _loadFromDisk();
    } catch (e, st) {
      debugPrint('Kadd: loading saved state failed: $e\n$st');
    }

    try {
      await refreshPrayerTimes();
    } catch (e, st) {
      debugPrint('Kadd: prayer initialization failed: $e\n$st');
    }

    try {
      await checkUsageAccess();
    } catch (e, st) {
      debugPrint('Kadd: usage access initialization failed: $e\n$st');
    }

    // Sync existing locks only after the UI/permissions are initialized.
    // Failure here is reported but does not prevent app discovery.
    try {
      await _syncLockedPackages();
    } catch (e, st) {
      debugPrint('Kadd: initial lock sync failed: $e\n$st');
    }

    await loadAvailableApps();
  }

  Future<void> checkUsageAccess() async {
    hasUsageAccess = await _usageService.hasUsageAccess();
    notifyListeners();
  }

  Future<void> requestUsageAccess() => _usageService.requestUsageAccess();

  Future<void> loadAvailableApps({bool forceRefresh = false}) async {
    loadingAvailableApps = true;
    notifyListeners();
    try {
      availableApps = await _installedAppsService.getLaunchableApps(forceRefresh: forceRefresh);
      for (final info in availableApps) {
        _appInfoCache[info.packageName] = info;
      }
    } finally {
      loadingAvailableApps = false;
      notifyListeners();
    }
  }

  String displayNameFor(String packageName) => _appInfoCache[packageName]?.name ?? packageName;

  Uint8List? iconFor(String packageName) => _appInfoCache[packageName]?.icon;

  Future<void> _syncLockedPackages() async {
    await _usageService.syncLockedPackages(
      apps.where((a) => a.isEnabled).map((a) => a.packageName).toList(),
    );
  }

  /// Adds an app, persists it, and immediately pushes the complete enabled
  /// package set to Android. The UI remains responsive while the native side
  /// starts/updates the foreground lock service.
  Future<void> addLockedApp(String packageName) async {
    if (apps.any((a) => a.packageName == packageName)) return;
    apps.add(LockedApp(packageName: packageName));
    notifyListeners();
    try {
      await _persistApps();
      await _syncLockedPackages();
    } catch (e) {
      debugPrint('Kadd: failed to sync newly locked app $packageName: $e');
      rethrow;
    }
  }

  Future<void> removeLockedApp(String packageName) async {
    final previous = List<LockedApp>.from(apps);
    apps.removeWhere((a) => a.packageName == packageName);
    notifyListeners();
    try {
      await _persistApps();
      await _syncLockedPackages();
    } catch (e) {
      apps = previous;
      notifyListeners();
      debugPrint('Kadd: failed to sync removed app $packageName: $e');
      rethrow;
    }
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
    }
  }

  Future<void> setDifficulty(Difficulty d) async {
    difficulty = d;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('difficulty', d.index);
  }

  Future<void> toggleApp(LockedApp app, bool value) async {
    final previous = app.isEnabled;
    app.isEnabled = value;
    notifyListeners();
    try {
      await _persistApps();
      await _syncLockedPackages();
    } catch (e) {
      app.isEnabled = previous;
      notifyListeners();
      debugPrint('Kadd: failed to sync app toggle ${app.packageName}: $e');
      rethrow;
    }
  }

  Future<void> togglePrayer(PrayerSetting p, bool value) async {
    p.enabled = value;
    notifyListeners();
    await _persistEnabledPrayers();
    await refreshPrayerTimes();
  }

  Future<void> setDelayMinutes(int minutes) async {
    delayMinutesAfterAthan = minutes.clamp(0, 60);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('delayMinutes', delayMinutesAfterAthan);
    await refreshPrayerTimes();
  }

  Future<void> onRepsVerified(LockedApp app) async {
    repsThisWeek += app.repsFor(difficulty);
    minutesEarnedToday += app.minutesGranted;
    _bumpStreak();
    notifyListeners();
    await _usageService.grantTemporaryUnlock(app.packageName, app.minutesGranted);
    await _persistStats();
    AdsService.instance.maybeShowInterstitialAfterUnlock();
  }

  Future<void> onRugVerified() async {
    _bumpStreak();
    notifyListeners();
    await _usageService.grantAthanUnlock();
    await _persistStats();
  }

  void _bumpStreak() {
    final todayIndex = DateTime.now().weekday % 7;
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
