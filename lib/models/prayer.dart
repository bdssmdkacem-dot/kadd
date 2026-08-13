enum PrayerName { fajr, dhuhr, asr, maghrib, isha }

extension PrayerLabel on PrayerName {
  String get labelAr {
    switch (this) {
      case PrayerName.fajr:
        return 'الفجر';
      case PrayerName.dhuhr:
        return 'الظهر';
      case PrayerName.asr:
        return 'العصر';
      case PrayerName.maghrib:
        return 'المغرب';
      case PrayerName.isha:
        return 'العشاء';
    }
  }

  String get emoji {
    switch (this) {
      case PrayerName.fajr:
        return '🌙';
      case PrayerName.dhuhr:
        return '☀️';
      case PrayerName.asr:
        return '🌤️';
      case PrayerName.maghrib:
        return '🌇';
      case PrayerName.isha:
        return '✨';
    }
  }

  /// Key used by the Aladhan API timings response.
  String get aladhanKey {
    switch (this) {
      case PrayerName.fajr:
        return 'Fajr';
      case PrayerName.dhuhr:
        return 'Dhuhr';
      case PrayerName.asr:
        return 'Asr';
      case PrayerName.maghrib:
        return 'Maghrib';
      case PrayerName.isha:
        return 'Isha';
    }
  }
}

class PrayerSetting {
  final PrayerName name;
  bool enabled;
  DateTime? timeToday;

  PrayerSetting({required this.name, this.enabled = false, this.timeToday});
}

/// Default: dhuhr, asr, maghrib enabled (matches the settings mockup),
/// fajr/isha off until the user opts in.
List<PrayerSetting> defaultPrayerSettings() => [
      PrayerSetting(name: PrayerName.fajr, enabled: false),
      PrayerSetting(name: PrayerName.dhuhr, enabled: true),
      PrayerSetting(name: PrayerName.asr, enabled: true),
      PrayerSetting(name: PrayerName.maghrib, enabled: true),
      PrayerSetting(name: PrayerName.isha, enabled: false),
    ];
