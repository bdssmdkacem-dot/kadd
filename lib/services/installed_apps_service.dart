import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/installed_app.dart';

/// Discovers launchable Android apps through PackageManager.
///
/// The previous implementation delegated the complete list to the
/// `installed_apps` plugin. On some Android 11+ devices that combination of
/// package-visibility and plugin-side filtering returned an empty list even
/// though the launcher showed installed apps. Kadd only needs launchable apps,
/// so we query Android's launcher intent directly instead.
class InstalledAppsService {
  static const MethodChannel _channel = MethodChannel('com.comptaflow.kadd/lock');

  List<InstalledApp>? _cache;
  Object? lastError;

  Future<List<InstalledApp>> getLaunchableApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

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
      lastError = null;
      debugPrint('Kadd: discovered ${apps.length} launchable apps');
      return apps;
    } catch (e, st) {
      lastError = e;
      debugPrint('InstalledAppsService.getLaunchableApps failed: $e\n$st');
      return [];
    }
  }
}
