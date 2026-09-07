import 'package:flutter/services.dart';
import '../models/prayer.dart';

/// Bridges to the native Android side which owns usage access, app discovery,
/// lock enforcement and prayer scheduling.
class AppUsageService {
  static const _channel = MethodChannel('com.comptaflow.kadd/lock');

  Future<bool> hasUsageAccess() async {
    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  Future<void> requestUsageAccess() async {
    await _channel.invokeMethod('requestUsageAccess');
  }

  Future<List<Map<String, dynamic>>> getLaunchableApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getLaunchableApps');
    if (raw == null) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
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

  Future<void> grantAthanUnlock() async {
    await _channel.invokeMethod('grantAthanUnlock');
  }

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
