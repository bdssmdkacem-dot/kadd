import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PrayerTimesResult {
  final String cityLabel;
  final Map<String, DateTime> timings; // keys: Fajr, Dhuhr, Asr, Maghrib, Isha
  PrayerTimesResult({required this.cityLabel, required this.timings});
}

/// Fetches today's prayer times from the Aladhan API using the device's GPS
/// coordinates. method=21 is Aladhan's calculation preset for Morocco
/// (Ministère des Habous et des Affaires Islamiques). See:
/// https://aladhan.com/calculation-methods
///
/// This calls a public API on every refresh; for production, cache the
/// day's timings locally (they only need to be fetched once per day) and
/// only re-fetch on app open / date change / location change beyond a few km.
class PrayerTimesService {
  static const _baseUrl = 'https://api.aladhan.com/v1/timings';
  static const _calculationMethod = 21; // Morocco (Awqaf)

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location services disabled');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
  }

  Future<PrayerTimesResult> fetchTodayTimings() async {
    final pos = await _getPosition();
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final uri = Uri.parse(
      '$_baseUrl/$today?latitude=${pos.latitude}&longitude=${pos.longitude}&method=$_calculationMethod',
    );
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

    // Reverse-geocoding for a nice city label is a separate call
    // (e.g. geocoding package or Aladhan's own address lookup) — omitted
    // here to keep this service to a single API dependency. Placeholder:
    final cityLabel = 'موقعك الحالي (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})';

    return PrayerTimesResult(cityLabel: cityLabel, timings: timings);
  }
}
