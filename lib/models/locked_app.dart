enum Difficulty { easy, medium, hard }

extension DifficultyMultiplier on Difficulty {
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
  final String packageName;
  int baseReps;
  int minutesGranted;
  bool isEnabled;

  LockedApp({
    required this.packageName,
    int baseReps = 20,
    int minutesGranted = 15,
    this.isEnabled = true,
  })  : baseReps = baseReps.clamp(1, 500),
        minutesGranted = minutesGranted.clamp(1, 180);

  int repsFor(Difficulty d) => (baseReps * d.multiplier).round().clamp(1, 500);

  void configure({int? reps, int? minutes}) {
    if (reps != null) baseReps = reps.clamp(1, 500);
    if (minutes != null) minutesGranted = minutes.clamp(1, 180);
  }

  factory LockedApp.fromJson(Map<String, dynamic> j) => LockedApp(
        packageName: (j['packageName'] ?? '').toString(),
        baseReps: _asInt(j['baseReps'], 20),
        minutesGranted: _asInt(j['minutesGranted'], 15),
        isEnabled: j['isEnabled'] != false,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'baseReps': baseReps,
        'minutesGranted': minutesGranted,
        'isEnabled': isEnabled,
      };

  static int _asInt(dynamic value, int fallback) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
