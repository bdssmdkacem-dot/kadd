import 'dart:typed_data';

/// A launchable application discovered from Android's PackageManager.
///
/// We intentionally keep this model independent from the `installed_apps`
/// Flutter plugin. Kadd needs a reliable list of launchable apps on Android
/// 11+, and querying PackageManager directly avoids plugin-side filtering
/// differences between Android vendors.
class InstalledApp {
  final String name;
  final String packageName;
  final Uint8List? icon;
  final bool isSystemApp;

  const InstalledApp({
    required this.name,
    required this.packageName,
    this.icon,
    this.isSystemApp = false,
  });
}
