import 'package:flutter/foundation.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

/// Wraps the installed_apps plugin. This is the piece that needed
/// QUERY_ALL_PACKAGES (see android_additions/manifest_permissions.xml) —
/// without it, Android 11+'s package visibility restrictions mean the app
/// simply can't see what else is installed, which is why the previous
/// hardcoded 5-app list existed in the first place. A real lock app has to
/// see the user's actual apps to be useful.
class InstalledAppsService {
  List<AppInfo>? _cache;

  /// Set whenever [getLaunchableApps] fails, so the UI/logs can show *why*
  /// the picker came up empty instead of a generic "no apps found". Cleared
  /// on a successful fetch.
  Object? lastError;

  /// Fetches every launchable, non-system app on the device, with icons.
  /// Cached after first call — call [refresh] to force a re-fetch (e.g. if
  /// the user installs something new while the picker is open).
  Future<List<AppInfo>> getLaunchableApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _cache = apps;
      lastError = null;
      return apps;
    } catch (e, st) {
      // Fails closed to an empty list rather than crashing the settings
      // screen — the picker will just show "no apps found" with a retry —
      // but the real cause (missing permission, plugin/platform-channel
      // error, etc.) is now logged instead of silently disappearing, since
      // that silence is exactly what made this bug hard to diagnose before.
      lastError = e;
      debugPrint('InstalledAppsService.getLaunchableApps failed: $e\n$st');
      return [];
    }
  }

  Future<AppInfo?> getApp(String packageName) async {
    try {
      return await InstalledApps.getAppInfo(packageName);
    } catch (e) {
      return null;
    }
  }
}
