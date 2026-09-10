import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/city.dart';
import '../models/installed_app.dart';
import '../models/locked_app.dart';
import '../models/prayer.dart';
import '../services/app_usage_service.dart';
import '../services/ads_service.dart';
import '../services/installed_apps_service.dart';
import '../services/prayer_times_service.dart';

class AppUsageSummary {
  int reps;
  int minutes;
  int unlocks;
  String? lastUnlockDate;

  AppUsageSummary({this.reps = 0, this.minutes = 0, this.unlocks = 0, this.lastUnlockDate});

  factory AppUsageSummary.fromJson(Map<String, dynamic> json) => AppUsageSummary(
        reps: (json['reps'] as num?)?.toInt().clamp(0, 100000000) ?? 0,
        minutes: (json['minutes'] as num?)?.toInt().clamp(0, 100000000) ?? 0,
        unlocks: (json['unlocks'] as num?)?.toInt().clamp(0, 100000000) ?? 0,
        lastUnlockDate: json['lastUnlockDate'] is String ? json['lastUnlockDate'] as String : null,
      );

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'minutes': minutes,
        'unlocks': unlocks,
        if (lastUnlockDate != null) 'lastUnlockDate': lastUnlockDate,
      };
}

class AppState extends ChangeNotifier {
  List<LockedApp> apps = [];
  Difficulty difficulty = Difficulty.medium;

  List<PrayerSetting> prayers = defaultPrayerSettings();
  int delayMinutesAfterAthan = 5;
  MoroccanCity selectedCity = moroccanCities.first;

  int repsThisWeek = 0;
  int minutesEarnedToday = 0;
  int streakDays = 0;
  int totalReps = 0;
  int totalMinutesEarned = 0;
  int prayerUnlocks = 0;
  final List<bool> last7Days = List.filled(7, false);
  final Set<String> _activityDates = <String>{};
  final Map<String, AppUsageSummary> _appUsage = <String, AppUsageSummary>{};

  Map<String, AppUsageSummary> get appUsageHistory => Map.unmodifiable(_appUsage);

  bool hasUsageAccess = false;
  bool isInitialized = false;
  bool onboardingComplete = false;

  List<InstalledApp> availableApps = [];
  bool loadingAvailableApps = false;
  final Map<String, InstalledApp> _appInfoCache = {};

  Object? get availableAppsError => _installedAppsService.lastError;
  Map<String, dynamic> get appDiscoveryDiagnostics => _installedAppsService.lastDiagnostics;

  PrayerSetting? get nextPrayer {
    final now = DateTime.now();
    for (final prayer in prayers) {
      final time = prayer.timeToday;
      if (prayer.enabled && time != null && time.isAfter(now)) return prayer;
    }
    return null;
  }

  Duration? get timeUntilNextPrayer {
    final prayer = nextPrayer;
    final time = prayer?.timeToday;
    if (time == null) return null;
    return time.difference(DateTime.now());
  }

  PrayerSetting? get tomorrowFirstEnabledPrayer {
    for (final prayer in prayers) {
      if (prayer.enabled) return prayer;
    }
    return null;
  }

  final PrayerTimesService _prayerTimesService = PrayerTimesService();
  final AppUsageService _usageService = AppUsageService();
  final InstalledAppsService _installedAppsService = InstalledAppsService();

  Future<void> init() async {
    try {
      await _loadFromDisk();
    } catch (e, st) {
      debugPrint('Kadd: loading saved state failed: $e\n$st');
    }

    isInitialized = true;
    notifyListeners();

    try {
      await checkUsageAccess();
    } catch (e, st) {
      debugPrint('Kadd: usage access initialization failed: $e\n$st');
    }

    try {
      await _syncLockedPackages();
    } catch (e, st) {
      debugPrint('Kadd: initial lock sync failed: $e\n$st');
    }

    unawaited(refreshPrayerTimes());
    unawaited(loadAvailableApps());
  }

  Future<void> checkUsageAccess() async {
    hasUsageAccess = await _usageService.hasUsageAccess();
    notifyListeners();
  }

  Future<void> requestUsageAccess() => _usageService.requestUsageAccess();

  Future<void> loadAvailableApps({bool forceRefresh = false}) async {
    if (loadingAvailableApps) return;
    loadingAvailableApps = true;
    notifyListeners();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          availableApps = await _installedAppsService.getLaunchableApps(
            forceRefresh: forceRefresh || attempt > 0,
          );
          lastError = null;
          if (availableApps.isNotEmpty) break;
        } catch (e) {
          lastError = e;
        }
        if (attempt < 2) await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
      _appInfoCache
        ..clear()
        ..addEntries(availableApps.map((info) => MapEntry(info.packageName, info)));
      if (availableApps.isEmpty && lastError != null) debugPrint('Kadd: app discovery failed after retries: $lastError');
      debugPrint('Kadd: Flutter received ${availableApps.length} available apps');
    } finally {
      loadingAvailableApps = false;
      notifyListeners();
    }
  }

  String displayNameFor(String packageName) => _appInfoCache[packageName]?.name ?? packageName;
  Uint8List? iconFor(String packageName) => _appInfoCache[packageName]?.icon;

  Future<void> _syncLockedPackages() async {
    final validPackages = apps.where((a) => a.isEnabled && a.packageName.trim().isNotEmpty).map((a) => a.packageName.trim()).toSet().toList();
    await _usageService.syncLockedPackages(validPackages);
  }

  Future<void> addLockedApp(String packageName) async {
    final normalized = packageName.trim();
    if (normalized.isEmpty || apps.any((a) => a.packageName == normalized)) return;
    apps.add(LockedApp(packageName: normalized));
    notifyListeners();
    try {
      await _persistApps();
      await _syncLockedPackages();
    } catch (e) {
      apps.removeWhere((a) => a.packageName == normalized);
      notifyListeners();
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
      rethrow;
    }
  }

  Future<void> updateLockedAppConfig(LockedApp app, {required int reps, required int minutes}) async {
    final previousReps = app.baseReps;
    final previousMinutes = app.minutesGranted;
    app.configure(reps: reps, minutes: minutes);
    notifyListeners();
    try {
      await _persistApps();
    } catch (e) {
      app.configure(reps: previousReps, minutes: previousMinutes);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    final difficultyIndex = prefs.getInt('difficulty') ?? Difficulty.medium.index;
    difficulty = Difficulty.values[difficultyIndex.clamp(0, Difficulty.values.length - 1)];
    delayMinutesAfterAthan = (prefs.getInt('delayMinutes') ?? 5).clamp(0, 60);
    repsThisWeek = prefs.getInt('repsThisWeek') ?? 0;
    totalReps = prefs.getInt('totalReps') ?? 0;
    totalMinutesEarned = prefs.getInt('totalMinutesEarned') ?? 0;
    prayerUnlocks = prefs.getInt('prayerUnlocks') ?? 0;

    final weekKey = _weekKey(DateTime.now());
    if (prefs.getString('repsWeekKey') != weekKey) repsThisWeek = 0;
    final todayKey = _dayKey(DateTime.now());
    minutesEarnedToday = prefs.getString('statsDayKey') == todayKey ? (prefs.getInt('minutesEarnedToday') ?? 0) : 0;

    _activityDates
      ..clear()
      ..addAll((prefs.getStringList('activityDates') ?? const <String>[]).where(_isValidDayKey));
    _pruneActivityDates();
    _rebuildStreak();

    final historyJson = prefs.getString('appUsageHistory');
    if (historyJson != null) {
      try {
        final decoded = jsonDecode(historyJson);
        if (decoded is Map) {
          _appUsage
            ..clear()
            ..addEntries(decoded.entries.where((e) => e.key is String && e.value is Map).map((e) => MapEntry(e.key as String, AppUsageSummary.fromJson(Map<String, dynamic>.from(e.value as Map)))));
        }
      } catch (e) {
        debugPrint('Failed to decode app usage history: $e');
      }
    }

    final cityName = prefs.getString('selectedCity');
    if (cityName != null) selectedCity = moroccanCities.firstWhere((c) => c.aladhanName == cityName, orElse: () => moroccanCities.first);

    final appsJson = prefs.getString('lockedApps');
    if (appsJson != null) {
      try {
        final decoded = jsonDecode(appsJson) as List;
        apps = decoded.whereType<Map>().map((j) => LockedApp.fromJson(Map<String, dynamic>.from(j))).where((a) => a.packageName.trim().isNotEmpty).toList();
      } catch (e) {
        debugPrint('Failed to decode saved locked apps: $e');
      }
    }

    final enabledPrayerNames = prefs.getStringList('enabledPrayerNames');
    if (enabledPrayerNames != null) for (final p in prayers) p.enabled = enabledPrayerNames.contains(p.name.name);
  }

  Future<void> _persistApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lockedApps', jsonEncode(apps.map((a) => a.toJson()).toList()));
  }

  Future<void> _persistEnabledPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabledPrayerNames', prayers.where((p) => p.enabled).map((p) => p.name.name).toList());
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool('onboardingComplete', true);
  }

  Future<void> resetAllData() async {
    await _usageService.clearAllLockState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    apps = [];
    difficulty = Difficulty.medium;
    prayers = defaultPrayerSettings();
    delayMinutesAfterAthan = 5;
    selectedCity = moroccanCities.first;
    repsThisWeek = 0;
    minutesEarnedToday = 0;
    streakDays = 0;
    totalReps = 0;
    totalMinutesEarned = 0;
    prayerUnlocks = 0;
    _activityDates.clear();
    _appUsage.clear();
    onboardingComplete = false;
    await _usageService.syncLockedPackages(const []);
    notifyListeners();
  }

  Future<void> setCity(MoroccanCity city) async {
    selectedCity = city;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString('selectedCity', city.aladhanName);
    await refreshPrayerTimes();
  }

  Future<void> refreshPrayerTimes() async {
    try {
      final result = await _prayerTimesService.fetchTodayTimings(selectedCity);
      for (final p in prayers) p.timeToday = result.timings[p.name.aladhanKey];
      await _usageService.scheduleAthanLocks(prayers.where((p) => p.enabled && p.timeToday != null).toList(), delayMinutesAfterAthan, cityName: selectedCity.aladhanName);
      notifyListeners();
    } catch (e) {
      debugPrint('Prayer time fetch failed: $e');
      notifyListeners();
    }
  }

  Future<void> setDifficulty(Difficulty d) async {
    difficulty = d;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setInt('difficulty', d.index);
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
    await (await SharedPreferences.getInstance()).setInt('delayMinutes', delayMinutesAfterAthan);
    await refreshPrayerTimes();
  }

  Future<void> onRepsVerified(LockedApp app) async {
    await refreshCalendarState();
    final reps = app.repsFor(difficulty);
    await _usageService.grantTemporaryUnlock(app.packageName, app.minutesGranted);
    repsThisWeek += reps;
    minutesEarnedToday += app.minutesGranted;
    totalReps += reps;
    totalMinutesEarned += app.minutesGranted;
    final summary = _appUsage.putIfAbsent(app.packageName, () => AppUsageSummary());
    summary
      ..reps += reps
      ..minutes += app.minutesGranted
      ..unlocks += 1
      ..lastUnlockDate = _dayKey(DateTime.now());
    _recordActivityToday();
    notifyListeners();
    await _persistStats();
    AdsService.instance.maybeShowInterstitialAfterUnlock();
  }

  /// Grants the prayer unlock only when the native side confirms that the
  /// exact prayer being verified is still the active prayer lock.
  Future<void> onRugVerified(PrayerName prayer) async {
    await refreshCalendarState();
    await _usageService.grantAthanUnlock(prayer);
    prayerUnlocks += 1;
    _recordActivityToday();
    notifyListeners();
    await _persistStats();
  }

  /// Reconciles in-memory daily/weekly counters with the current calendar.
  /// This is safe to call whenever the app returns from background and keeps
  /// a long-running app from carrying yesterday's daily or last-week's count.
  Future<void> refreshCalendarState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final weekKey = _weekKey(now);
    var changed = false;

    if (prefs.getString('statsDayKey') != todayKey) {
      minutesEarnedToday = 0;
      await prefs.setInt('minutesEarnedToday', 0);
      await prefs.setString('statsDayKey', todayKey);
      changed = true;
    }

    if (prefs.getString('repsWeekKey') != weekKey) {
      repsThisWeek = 0;
      await prefs.setInt('repsThisWeek', 0);
      await prefs.setString('repsWeekKey', weekKey);
      changed = true;
    }

    final beforePrune = _activityDates.length;
    _pruneActivityDates();
    _rebuildStreak();
    if (_activityDates.length != beforePrune) {
      await prefs.setStringList('activityDates', _activityDates.toList()..sort());
      changed = true;
    }

    if (changed) notifyListeners();
  }

  void _recordActivityToday() {
    _activityDates.add(_dayKey(DateTime.now()));
    _rebuildStreak();
  }

  void _rebuildStreak() {
    final today = DateTime.now();
    final todayKey = _dayKey(today);
    final days = List<bool>.generate(7, (index) => _activityDates.contains(_dayKey(today.subtract(Duration(days: index)))));
    last7Days
      ..clear()
      ..addAll(days.reversed);
    var streak = 0;
    for (var i = 0; i < 91; i++) {
      if (!_activityDates.contains(_dayKey(today.subtract(Duration(days: i))))) break;
      streak++;
    }
    streakDays = _activityDates.contains(todayKey) ? streak : 0;
  }

  String _dayKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
    return _dayKey(monday);
  }

  bool _isValidDayKey(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed != null && _dayKey(parsed) == value;
  }

  void _pruneActivityDates() {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _activityDates.removeWhere((key) {
      final date = DateTime.tryParse(key);
      return date == null || date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
    });
  }

  Future<void> _persistStats() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(DateTime.now());
    await prefs.setInt('repsThisWeek', repsThisWeek);
    await prefs.setString('repsWeekKey', _weekKey(DateTime.now()));
    await prefs.setInt('minutesEarnedToday', minutesEarnedToday);
    await prefs.setString('statsDayKey', todayKey);
    await prefs.setInt('totalReps', totalReps);
    await prefs.setInt('totalMinutesEarned', totalMinutesEarned);
    await prefs.setInt('prayerUnlocks', prayerUnlocks);
    await prefs.setStringList('activityDates', _activityDates.toList()..sort());
    await prefs.setString('appUsageHistory', jsonEncode(_appUsage.map((key, value) => MapEntry(key, value.toJson()))));
  }
}