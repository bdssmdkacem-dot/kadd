import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';

import '../models/installed_app.dart';

/// Discovers user-facing Android apps that Kadd can lock.
///
/// The plugin is used as the primary source because it handles Android's
/// package-visibility rules and launchability filtering. The native channel
/// remains as a fallback so an OEM-specific plugin failure does not leave the
/// picker permanently empty.
class InstalledAppsService {
  static const MethodChannel _channel = MethodChannel('com.comptaflow.kadd/lock');

  List<InstalledApp>? _cache;
  Object? lastError;

  Future<List<InstalledApp>> getLaunchableApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    Object? pluginError;
    try {
      final rawApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
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

      if (apps.isNotEmpty) {
        _cache = apps;
        lastError = null;
        debugPrint('Kadd: installed_apps discovered ${apps.length} launchable apps');
        return apps;
      }

      pluginError = StateError('installed_apps returned no launchable applications');
    } catch (e, st) {
      pluginError = e;
      debugPrint('Kadd: installed_apps discovery failed: $e\n$st');
    }

    // Fallback to Kadd's native PackageManager implementation. This is useful
    // on vendor ROMs where the plugin may fail to enumerate launchable apps.
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getLaunchableApps');
      final apps = <InstalledApp>[];

      for (final item in raw ?? const <dynamic>[]) {
        if (item is! Map) continue;
        final map = Map<Object?, Object?>.from(item);
        final name = map['name']?.toString().trim() ?? '';
        final packageName = map['packageName']?.toString().trim() ?? '';
        if (name.isEmpty || packageName.isEmpty) continue;

        Uint8List? icon;
        final rawIcon = map['icon'];
        if (rawIcon is Uint8List) {
          icon = rawIcon;
        } else if (rawIcon is List) {
          icon = Uint8List.fromList(rawIcon.whereType<int>().toList());
        }

        apps.add(
          InstalledApp(
            name: name,
            packageName: packageName,
            icon: icon,
            isSystemApp: map['isSystemApp'] == true,
          ),
        );
      }

      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _cache = apps;
      lastError = apps.isEmpty ? (pluginError ?? StateError('No launchable apps found')) : null;
      debugPrint('Kadd: native fallback discovered ${apps.length} launchable apps');
      return apps;
    } catch (e, st) {
      lastError = e;
      debugPrint('Kadd: native app discovery fallback failed: $e\n$st');
      return [];
    }
  }
}
