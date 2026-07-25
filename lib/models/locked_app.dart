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

class LockedApp {
  final String packageName; // e.g. com.zhiliaoapp.musically (TikTok)
  final String nameAr;
  final String emoji;
  final int baseReps; // reps required at "medium" difficulty
  final int minutesGranted; // screen-time minutes unlocked per verified session
  bool isEnabled;

  LockedApp({
    required this.packageName,
    required this.nameAr,
    required this.emoji,
    required this.baseReps,
    required this.minutesGranted,
    this.isEnabled = true,
  });

  int repsFor(Difficulty d) => (baseReps * d.multiplier).round();

  factory LockedApp.fromJson(Map<String, dynamic> j) => LockedApp(
        packageName: j['packageName'],
        nameAr: j['nameAr'],
        emoji: j['emoji'],
        baseReps: j['baseReps'],
        minutesGranted: j['minutesGranted'],
        isEnabled: j['isEnabled'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'nameAr': nameAr,
        'emoji': emoji,
        'baseReps': baseReps,
        'minutesGranted': minutesGranted,
        'isEnabled': isEnabled,
      };
}

/// Default catalogue — package names are the real Android package IDs so the
/// usage-stats/lock service can match foreground apps directly.
final defaultLockedApps = <LockedApp>[
  LockedApp(packageName: 'com.zhiliaoapp.musically', nameAr: 'تيك توك', emoji: '🎵', baseReps: 20, minutesGranted: 15),
  LockedApp(packageName: 'com.instagram.android', nameAr: 'إنستغرام', emoji: '📷', baseReps: 15, minutesGranted: 10),
  LockedApp(packageName: 'com.google.android.youtube', nameAr: 'يوتيوب', emoji: '▶️', baseReps: 25, minutesGranted: 20),
  LockedApp(packageName: 'com.snapchat.android', nameAr: 'سناب شات', emoji: '👻', baseReps: 20, minutesGranted: 15, isEnabled: false),
  LockedApp(packageName: 'com.whatsapp', nameAr: 'واتساب', emoji: '💬', baseReps: 0, minutesGranted: 0, isEnabled: false),
];
