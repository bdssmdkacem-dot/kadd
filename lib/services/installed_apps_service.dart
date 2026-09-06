import 'package:installed_apps/installed_apps.dart';

import '../models/installed_app.dart';

/// Discovers user-facing Android apps that Kadd can lock.
class InstalledAppsService {
  List<InstalledApp>? _cache;
  Object? lastError;

  Future<List<InstalledApp>> getLaunchableApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    try {
      final rawApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );

      final apps = rawApps
          .where((app) => app.packageName.isNotEmpty && app.name.trim().isNotEmpty)
          .map(
            (app) => InstalledApp(
              name: app.name.trim(),
              packageName: app.packageName,
              icon: app.icon,
              isSystemApp: false,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _cache = apps;
      lastError = apps.isEmpty
          ? StateError('No launchable applications were returned by installed_apps')
          : null;
      return apps;
    } catch (e) {
      lastError = e;
      _cache = <InstalledApp>[];
      return _cache!;
    }
  }
}
