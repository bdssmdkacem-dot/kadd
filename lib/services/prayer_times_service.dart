import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/city.dart';

class PrayerTimesResult {
  final Map<String, DateTime> timings;
  PrayerTimesResult({required this.timings});
}

/// Fetches Morocco prayer times by city without requesting precise location.
/// Successful results are cached locally for the same city and calendar day,
/// so a temporary network outage does not invalidate an already-known day.
class PrayerTimesService {
  static const _baseUrl = 'https://api.aladhan.com/v1/timingsByCity';
  static const _calculationMethod = 21;
  static const _country = 'Morocco';
  static const _cachePrefix = 'prayer_times_cache_v1_';

  Future<PrayerTimesResult> fetchTodayTimings(MoroccanCity city) async {
    final now = DateTime.now();
    final today = DateFormat('dd-MM-yyyy').format(now);
    final cacheKey = _cacheKey(city, today);

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'date': today,
        'city': city.aladhanName,
        'country': _country,
        'method': '$_calculationMethod',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('Aladhan API error: ${res.statusCode}');
      }

      final body = jsonDecode(res.body);
      final raw = body['data']['timings'];
      if (raw is! Map) throw const FormatException('Invalid prayer timings response');

      final timings = _parseTimings(Map<String, dynamic>.from(raw), now);
      if (timings.length != 5) throw const FormatException('Incomplete prayer timings response');
      await _saveCache(cacheKey, timings);
      return PrayerTimesResult(timings: timings);
    } catch (error) {
      final cached = await _loadCache(cacheKey, now);
      if (cached != null) return PrayerTimesResult(timings: cached);
      rethrow;
    }
  }

  Map<String, DateTime> _parseTimings(Map<String, dynamic> raw, DateTime now) {
    final timings = <String, DateTime>{};
    for (final key in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final value = raw[key];
      if (value is! String) continue;
      final parts = value.split(' ').first.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
      timings[key] = DateTime(now.year, now.month, now.day, hour, minute);
    }
    return timings;
  }

  String _cacheKey(MoroccanCity city, String date) =>
      '$_cachePrefix${city.aladhanName.toLowerCase()}_$date';

  Future<void> _saveCache(String key, Map<String, DateTime> timings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(timings.map((name, time) => MapEntry(name, time.toIso8601String()))),
    );
  }

  Future<Map<String, DateTime>?> _loadCache(String key, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(key);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final parsed = DateTime.tryParse(entry.value as String);
        if (parsed == null) continue;
        result[entry.key as String] = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      }
      return result.length == 5 ? result : null;
    } catch (_) {
      return null;
    }
  }
}
