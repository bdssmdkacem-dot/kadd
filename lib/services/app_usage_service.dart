import 'package:flutter/services.dart';
import '../models/prayer.dart';

/// Bridges to the native Android side (see android_additions/) which owns:
///  - checking/requesting the special "usage access" permission
///  - a foreground service that polls UsageStatsManager for the current
///    foreground app and shows a full-screen lock Activity when a locked,
///    unverified package comes to the front
///  - AlarmManager entries for each enabled prayer's "lock at Athan + delay"
///
/// NOTE ON APPROACH: we deliberately use UsageStatsManager polling + a
/// foreground service instead of AccessibilityService. Google Play's policy
/// on the Accessibility API restricts it to genuine accessibility use cases,
/// and app-blocking apps have had listings rejected/removed for using it as
/// a workaround. UsageStatsManager + SYSTEM_ALERT_WINDOW (or a full-screen
/// Activity, which needs no overlay permission) is the same approach used by
/// most compliant screen-time apps.
class AppUsageService {
  static const _channel = MethodChannel('com.comptaflow.kadd/lock');

  Future<bool> hasUsageAccess() async {
    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  Future<void> requestUsageAccess() async {
    await _channel.invokeMethod('requestUsageAccess');
  }

  /// Pushes the current list of package names that should be locked when
  /// foregrounded (and not currently within an active unlock window).
  Future<void> syncLockedPackages(List<String> packages) async {
    await _channel.invokeMethod('syncLockedPackages', {'packages': packages});
  }

  /// Grants `minutes` of unlocked access to a single package, starting now.
  Future<void> grantTemporaryUnlock(String packageName, int minutes) async {
    await _channel.invokeMethod('grantTemporaryUnlock', {
      'packageName': packageName,
      'minutes': minutes,
    });
  }

  /// Lifts the post-Athan lock across all locked apps for the current
  /// prayer window, after a successful rug scan.
  Future<void> grantAthanUnlock() async {
    await _channel.invokeMethod('grantAthanUnlock');
  }

  /// Schedules native alarms so the lock engages `delayMinutes` after each
  /// enabled prayer's Athan time, even if the app isn't running.
  Future<void> scheduleAthanLocks(List<PrayerSetting> enabledPrayers, int delayMinutes) async {
    await _channel.invokeMethod('scheduleAthanLocks', {
      'prayers': enabledPrayers
          .map((p) => {
                'name': p.name.name,
                'epochMillis': p.timeToday!.millisecondsSinceEpoch,
              })
          .toList(),
      'delayMinutes': delayMinutes,
    });
  }
}
