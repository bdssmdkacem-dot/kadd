enum Difficulty { easy, medium, hard }

extension DifficultyMultiplier on Difficulty {
  /// Multiplies each app's base rep cost.
  double get multiplier {
    switch (this) {
      case Difficulty.easy:
        return 0.6;
      case Difficulty.medium:
        return 1.0;
      case Difficulty.hard:
        return 1.6;
    }
  }

  String get labelAr {
    switch (this) {
      case Difficulty.easy:
        return 'سهل';
      case Difficulty.medium:
        return 'متوسط';
      case Difficulty.hard:
        return 'صعب';
    }
  }
}

/// A user-chosen app to lock, picked from their actual installed apps (see
/// InstalledAppsService) rather than a fixed catalogue. Display info (name,
/// icon) is deliberately NOT stored here — it's resolved live from the
/// device each time, via AppState's app-info cache, so it always reflects
/// reality even if the app is updated, renamed, or uninstalled later.
class LockedApp {
  final String packageName;
  final int baseReps;
  final int minutesGranted;
  bool isEnabled;

  LockedApp({
    required this.packageName,
    this.baseReps = 20,
    this.minutesGranted = 15,
    this.isEnabled = true,
  });

  int repsFor(Difficulty d) => (baseReps * d.multiplier).round();

  factory LockedApp.fromJson(Map<String, dynamic> j) => LockedApp(
        packageName: j['packageName'],
        baseReps: j['baseReps'] ?? 20,
        minutesGranted: j['minutesGranted'] ?? 15,
        isEnabled: j['isEnabled'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'baseReps': baseReps,
        'minutesGranted': minutesGranted,
        'isEnabled': isEnabled,
      };
}
