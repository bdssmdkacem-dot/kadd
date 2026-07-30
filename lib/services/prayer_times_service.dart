import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/city.dart';

class PrayerTimesResult {
  final Map<String, DateTime> timings; // keys: Fajr, Dhuhr, Asr, Maghrib, Isha
  PrayerTimesResult({required this.timings});
}

/// Fetches today's prayer times from the Aladhan API by city name — no
/// coordinates, no location permission. method=21 is Aladhan's calculation
/// preset for Morocco (Ministère des Habous et des Affaires Islamiques).
/// See: https://aladhan.com/calculation-methods
///
/// This replaces an earlier GPS-based version: the app has no other genuine
/// need for the user's precise location, and removing it drops a sensitive
/// permission (and a Play Store justification requirement) for a feature
/// that works just as well with a manually-picked city.
class PrayerTimesService {
  static const _baseUrl = 'https://api.aladhan.com/v1/timingsByCity';
  static const _calculationMethod = 21; // Morocco (Awqaf)
  static const _country = 'Morocco';

  Future<PrayerTimesResult> fetchTodayTimings(MoroccanCity city) async {
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'date': today,
      'city': city.aladhanName,
      'country': _country,
      'method': '$_calculationMethod',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Aladhan API error: ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    final Map<String, dynamic> raw = body['data']['timings'];
    final timings = <String, DateTime>{};
    final now = DateTime.now();

    for (final key in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final parts = (raw[key] as String).split(' ').first.split(':'); // "HH:mm (TZ)" -> "HH:mm"
      timings[key] = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }

    return PrayerTimesResult(timings: timings);
  }
}
