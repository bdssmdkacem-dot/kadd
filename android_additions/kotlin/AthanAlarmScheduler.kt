package com.comptaflow.kadd

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

object AthanAlarmScheduler {
    private const val PREFS = "kadd_prayer_alarms"
    private const val KEY_ALARMS = "alarms"
    private const val KEY_CITY = "city"
    private const val KEY_ENABLED = "enabled_prayers"
    private const val KEY_DELAY = "delay_minutes"
    private const val SEPARATOR = "|"
    private const val COUNTRY = "Morocco"
    private const val METHOD = 21
    private const val TIME_ZONE = "Africa/Casablanca"
    private const val REFRESH_REQUEST_CODE = 0x4B414444
    private val VALID_PRAYERS = setOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    fun schedule(
        context: Context,
        prayers: List<Map<String, Any>>,
        delayMinutes: Int,
        cityName: String? = null,
        enabledPrayerNames: List<String> = prayers.mapNotNull { it["name"] as? String },
    ) {
        val enabled = normalizeEnabled(enabledPrayerNames)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_CITY, cityName?.trim().orEmpty())
            .putStringSet(KEY_ENABLED, enabled)
            .putInt(KEY_DELAY, delayMinutes.coerceIn(0, 60))
            .apply()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelPersisted(context, alarmManager)
        val now = System.currentTimeMillis()
        val persisted = mutableListOf<String>()
        prayers.forEach { prayer ->
            val name = normalizePrayer((prayer["name"] as? String).orEmpty())
            val epochMillis = (prayer["epochMillis"] as? Number)?.toLong() ?: return@forEach
            if (name !in enabled || name !in VALID_PRAYERS) return@forEach
            val triggerAt = epochMillis + TimeUnit.MINUTES.toMillis(delayMinutes.coerceIn(0, 60).toLong())
            if (triggerAt <= now) return@forEach
            if (scheduleOne(context, alarmManager, name, triggerAt)) persisted += entry(name, triggerAt)
        }
        save(context, persisted)
        scheduleRefresh(context, alarmManager)
    }

    fun restore(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val enabled = loadEnabled(context)
        val remaining = mutableListOf<String>()
        load(context).forEach { rawEntry ->
            val parsed = parseEntry(rawEntry) ?: return@forEach
            if (parsed.name !in enabled || parsed.name !in VALID_PRAYERS) return@forEach
            if (parsed.triggerAt > now && scheduleOne(context, alarmManager, parsed.name, parsed.triggerAt)) {
                remaining += entry(parsed.name, parsed.triggerAt)
            }
        }
        save(context, remaining)
        scheduleRefresh(context, alarmManager)
    }

    private data class AlarmEntry(val name: String, val triggerAt: Long)

    private fun entry(name: String, triggerAt: Long): String = "$name$SEPARATOR$triggerAt"

    private fun parseEntry(raw: String): AlarmEntry? {
        val separator = raw.lastIndexOf(SEPARATOR)
        if (separator <= 0 || separator >= raw.lastIndex) return null
        val name = normalizePrayer(raw.substring(0, separator))
        val triggerAt = raw.substring(separator + 1).toLongOrNull() ?: return null
        return if (name in VALID_PRAYERS && triggerAt > 0L) AlarmEntry(name, triggerAt) else null
    }

    private fun scheduleOne(context: Context, alarmManager: AlarmManager, name: String, triggerAt: Long): Boolean {
        if (!canScheduleExact(alarmManager) || name !in VALID_PRAYERS) return false
        val intent = Intent(context, AthanLockReceiver::class.java).apply {
            putExtra("prayerName", name)
            putExtra("triggerAt", triggerAt)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            stableRequestCode(name, triggerAt),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        return true
    }

    private fun scheduleRefresh(context: Context, alarmManager: AlarmManager) {
        if (!canScheduleExact(alarmManager)) return
        val city = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_CITY, "").orEmpty()
        if (city.isBlank()) return
        val calendar = Calendar.getInstance(TimeZone.getTimeZone(TIME_ZONE)).apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REFRESH_REQUEST_CODE,
            Intent(context, PrayerScheduleRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
    }

    private fun cancelPersisted(context: Context, alarmManager: AlarmManager) {
        load(context).forEach { rawEntry ->
            val parsed = parseEntry(rawEntry) ?: return@forEach
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                stableRequestCode(parsed.name, parsed.triggerAt),
                Intent(context, AthanLockReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
            val legacyIntent = PendingIntent.getBroadcast(
                context,
                parsed.name.lowercase(Locale.US).hashCode(),
                Intent(context, AthanLockReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(legacyIntent)
        }
    }

    private fun canScheduleExact(alarmManager: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    private fun stableRequestCode(name: String, triggerAt: Long): Int =
        "${name.lowercase(Locale.US)}:$triggerAt".hashCode()

    private fun load(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_ALARMS, emptySet())?.toSet() ?: emptySet()

    private fun loadEnabled(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_ENABLED, emptySet())?.map { normalizePrayer(it) }
            ?.filter(VALID_PRAYERS::contains)?.toSet() ?: emptySet()

    private fun normalizePrayer(name: String): String = name.trim().lowercase(Locale.US)

    private fun normalizeEnabled(names: List<String>): Set<String> =
        names.map(::normalizePrayer).filter(VALID_PRAYERS::contains).toSet()

    private fun save(context: Context, entries: Collection<String>) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putStringSet(KEY_ALARMS, entries.toSet()).apply()

    private fun appendFutureAlarms(
        context: Context,
        prayers: List<Map<String, Any>>,
        delayMinutes: Int,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val enabled = loadEnabled(context)
        val merged = load(context).mapNotNull { raw ->
            parseEntry(raw)?.takeIf { it.triggerAt > now && it.name in enabled }
        }.toMutableList()

        prayers.forEach { prayer ->
            val name = normalizePrayer((prayer["name"] as? String).orEmpty())
            val epochMillis = (prayer["epochMillis"] as? Number)?.toLong() ?: return@forEach
            if (name !in enabled || name !in VALID_PRAYERS) return@forEach
            val triggerAt = epochMillis + TimeUnit.MINUTES.toMillis(delayMinutes.coerceIn(0, 60).toLong())
            if (triggerAt <= now) return@forEach
            if (scheduleOne(context, alarmManager, name, triggerAt)) {
                merged.removeAll { it.name == name && it.triggerAt == triggerAt }
                merged += AlarmEntry(name, triggerAt)
            }
        }
        save(context, merged.map { entry(it.name, it.triggerAt) })
        scheduleRefresh(context, alarmManager)
    }

    private fun fetchTimingsForDate(context: Context, city: String, enabled: Set<String>, calendar: Calendar): List<Map<String, Any>> {
        val tz = TimeZone.getTimeZone(TIME_ZONE)
        val date = SimpleDateFormat("dd-MM-yyyy", Locale.US).apply { timeZone = tz }.format(calendar.time)
        val encodedCity = URLEncoder.encode(city, "UTF-8")
        val connection = (URL("https://api.aladhan.com/v1/timingsByCity?date=$date&city=$encodedCity&country=$COUNTRY&method=$METHOD").openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 8000
            readTimeout = 8000
        }
        try {
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return emptyList()
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val timings = JSONObject(body).getJSONObject("data").getJSONObject("timings")
            val result = mutableListOf<Map<String, Any>>()
            enabled.forEach { name ->
                val key = when (name) {
                    "fajr" -> "Fajr"
                    "dhuhr" -> "Dhuhr"
                    "asr" -> "Asr"
                    "maghrib" -> "Maghrib"
                    "isha" -> "Isha"
                    else -> null
                } ?: return@forEach
                val hm = timings.optString(key, "").substringBefore(" ").split(":")
                if (hm.size != 2) return@forEach
                val hour = hm[0].toIntOrNull() ?: return@forEach
                val minute = hm[1].toIntOrNull() ?: return@forEach
                val prayerCalendar = calendar.clone() as Calendar
                prayerCalendar.set(Calendar.HOUR_OF_DAY, hour)
                prayerCalendar.set(Calendar.MINUTE, minute)
                prayerCalendar.set(Calendar.SECOND, 0)
                prayerCalendar.set(Calendar.MILLISECOND, 0)
                result += mapOf("name" to name, "epochMillis" to prayerCalendar.timeInMillis)
            }
            return result
        } finally {
            connection.disconnect()
        }
    }

    private fun fetchTomorrowAndSchedule(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val city = prefs.getString(KEY_CITY, "").orEmpty()
        val enabled = loadEnabled(context)
        val delay = prefs.getInt(KEY_DELAY, 5).coerceIn(0, 60)
        if (city.isBlank() || enabled.isEmpty()) {
            scheduleRefresh(context, context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            return
        }

        val tomorrow = Calendar.getInstance(TimeZone.getTimeZone(TIME_ZONE)).apply { add(Calendar.DAY_OF_YEAR, 1) }
        val next = fetchTimingsForDate(context, city, enabled, tomorrow)
        if (next.isNotEmpty()) appendFutureAlarms(context, next, delay)
        else scheduleRefresh(context, context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
    }

    fun refreshTodayAndTomorrow(context: Context) = Thread {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val city = prefs.getString(KEY_CITY, "").orEmpty()
        val enabled = loadEnabled(context)
        val delay = prefs.getInt(KEY_DELAY, 5).coerceIn(0, 60)
        if (city.isBlank() || enabled.isEmpty()) return@Thread

        val tz = TimeZone.getTimeZone(TIME_ZONE)
        val today = Calendar.getInstance(tz)
        val tomorrow = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
        val rebuilt = mutableListOf<Map<String, Any>>()
        rebuilt += fetchTimingsForDate(context, city, enabled, today)
        rebuilt += fetchTimingsForDate(context, city, enabled, tomorrow)
        if (rebuilt.isNotEmpty()) schedule(context, rebuilt, delay, city, enabled.toList())
        else restore(context)
    }.start()

    fun refreshNextDay(context: Context) = Thread { fetchTomorrowAndSchedule(context) }.start()
}

class AthanLockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra("prayerName")?.trim()?.lowercase(Locale.US).orEmpty()
        val triggerAt = intent.getLongExtra("triggerAt", 0L)
        val prefs = context.getSharedPreferences("kadd_prayer_alarms", Context.MODE_PRIVATE)
        val enabled = prefs.getStringSet("enabled_prayers", emptySet())
            ?.map { it.trim().lowercase(Locale.US) }?.toSet().orEmpty()
        val valid = setOf("fajr", "dhuhr", "asr", "maghrib", "isha")
        if (prayerName !in valid || prayerName !in enabled) return
        if (triggerAt > 0L) {
            val expected = "$prayerName|$triggerAt"
            val scheduled = prefs.getStringSet("alarms", emptySet())?.contains(expected) == true
            if (!scheduled) return
        }
        LockPrefs.activateAthanLock(context, prayerName)
        LockForegroundService.ensureRunning(context)
    }
}

class PrayerScheduleRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AthanAlarmScheduler.refreshNextDay(context)
    }
}
