import 'dart:typed_data';

import '../models/installed_app.dart';
import 'app_usage_service.dart';

/// Discovers user-facing Android apps through Kadd's native PackageManager
/// bridge so package visibility and the lock service use the same inventory.
class InstalledAppsService {
  InstalledAppsService({AppUsageService? usageService})
      : _usageService = usageService ?? AppUsageService();

  final AppUsageService _usageService;
  List<InstalledApp>? _cache;
  Object? lastError;

  Future<List<InstalledApp>> getLaunchableApps({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    try {
      final rawApps = await _usageService.getLaunchableApps();
      final apps = rawApps
          .map(_toInstalledApp)
          .whereType<InstalledApp>()
          .where((app) => app.packageName.isNotEmpty && app.name.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _cache = apps;
      lastError = apps.isEmpty
          ? StateError('Android returned no installed launchable applications')
          : null;
      return apps;
    } catch (e) {
      lastError = e;
      _cache = <InstalledApp>[];
      return _cache!;
    }
  }

  InstalledApp? _toInstalledApp(Map<String, dynamic> raw) {
    final name = raw['name']?.toString().trim() ?? '';
    final packageName = raw['packageName']?.toString() ?? '';
    final icon = raw['icon'];

    Uint8List? iconBytes;
    if (icon is Uint8List) {
      iconBytes = icon;
    } else if (icon is List<int>) {
      iconBytes = Uint8List.fromList(icon);
    }

    if (name.isEmpty || packageName.isEmpty) return null;

    return InstalledApp(
      name: name,
      packageName: packageName,
      icon: iconBytes,
      isSystemApp: raw['isSystemApp'] == true,
    );
  }
}
