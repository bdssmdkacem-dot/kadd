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

/**
 * Owns exact prayer alarms and the small daily refresh alarm that keeps the
 * next day's schedule alive even when Flutter has never been opened that day.
 */
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

    fun schedule(context: Context, prayers: List<Map<String, Any>>, delayMinutes: Int, cityName: String? = null, enabledPrayerNames: List<String> = prayers.mapNotNull { it["name"] as? String }) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_CITY, cityName?.trim().orEmpty())
            .putStringSet(KEY_ENABLED, enabledPrayerNames.map(String::trim).filter(String::isNotEmpty).toSet())
            .putInt(KEY_DELAY, delayMinutes.coerceIn(0, 60))
            .apply()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelPersisted(context, alarmManager)

        val now = System.currentTimeMillis()
        val persisted = mutableListOf<String>()
        prayers.forEach { prayer ->
            val name = (prayer["name"] as? String)?.trim().orEmpty()
            val epochMillis = (prayer["epochMillis"] as? Number)?.toLong() ?: return@forEach
            if (name.isEmpty()) return@forEach

            val triggerAt = epochMillis + TimeUnit.MINUTES.toMillis(delayMinutes.coerceIn(0, 60).toLong())
            if (triggerAt <= now) return@forEach

            if (scheduleOne(context, alarmManager, name, triggerAt)) {
                persisted += "$name$SEPARATOR$triggerAt"
            }
        }
        save(context, persisted)
        scheduleRefresh(context, alarmManager)
    }

    fun restore(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val remaining = mutableListOf<String>()

        load(context).forEach { entry ->
            val parts = entry.split(SEPARATOR)
            if (parts.size != 2) return@forEach
            val name = parts[0]
            val triggerAt = parts[1].toLongOrNull() ?: return@forEach
            if (triggerAt > now && scheduleOne(context, alarmManager, name, triggerAt)) {
                remaining += entry
            }
        }
        save(context, remaining)
        scheduleRefresh(context, alarmManager)
    }

    private fun scheduleOne(context: Context, alarmManager: AlarmManager, name: String, triggerAt: Long): Boolean {
        if (!canScheduleExact(alarmManager)) return false
        val intent = Intent(context, AthanLockReceiver::class.java).apply { putExtra("prayerName", name) }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            stableRequestCode(name),
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

        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val intent = Intent(context, PrayerScheduleRefreshReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REFRESH_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
    }

    private fun cancelPersisted(context: Context, alarmManager: AlarmManager) {
        load(context).forEach { entry ->
            val name = entry.substringBefore(SEPARATOR)
            if (name.isEmpty()) return@forEach
            val intent = Intent(context, AthanLockReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                stableRequestCode(name),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
        }
    }

    private fun canScheduleExact(alarmManager: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    private fun stableRequestCode(name: String): Int = name.hashCode()
    private const val REFRESH_REQUEST_CODE = 0x4B414444

    private fun load(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet(KEY_ALARMS, emptySet())?.toSet() ?: emptySet()

    private fun save(context: Context, entries: List<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putStringSet(KEY_ALARMS, entries.toSet()).apply()
    }

    private fun fetchTomorrowAndSchedule(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val city = prefs.getString(KEY_CITY, "").orEmpty()
        if (city.isBlank()) return
        val enabled = prefs.getStringSet(KEY_ENABLED, emptySet()) ?: emptySet()
        val delay = prefs.getInt(KEY_DELAY, 5).coerceIn(0, 60)
        if (enabled.isEmpty()) return

        val date = SimpleDateFormat("dd-MM-yyyy", Locale.US).format(Calendar.getInstance(TimeZone.getTimeZone(TIME_ZONE)).apply { add(Calendar.DAY_OF_YEAR, 1) }.time)
        val encodedCity = URLEncoder.encode(city, "UTF-8")
        val url = URL("https://api.aladhan.com/v1/timingsByCity?date=$date&city=$encodedCity&country=$COUNTRY&method=$METHOD")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 8000
            readTimeout = 8000
        }

        try {
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val timings = JSONObject(JSONObject(body).getJSONObject("data").getJSONObject("timings"))
            val calendar = Calendar.getInstance(TimeZone.getTimeZone(TIME_ZONE))
            calendar.timeInMillis = System.currentTimeMillis()
            calendar.add(Calendar.DAY_OF_YEAR, 1)
            val next = mutableListOf<Map<String, Any>>()
            enabled.forEach { name ->
                val key = when (name) {
                    "fajr" -> "Fajr"
                    "dhuhr" -> "Dhuhr"
                    "asr" -> "Asr"
                    "maghrib" -> "Maghrib"
                    "isha" -> "Isha"
                    else -> null
                } ?: return@forEach
                val raw = timings.optString(key, "")
                val hm = raw.substringBefore(" ").split(":")
                if (hm.size != 2) return@forEach
                calendar.set(Calendar.HOUR_OF_DAY, hm[0].toIntOrNull() ?: return@forEach)
                calendar.set(Calendar.MINUTE, hm[1].toIntOrNull() ?: return@forEach)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                next += mapOf("name" to name, "epochMillis" to calendar.timeInMillis)
            }
            schedule(context, next, delay, city, enabled.toList())
        } finally {
            connection.disconnect()
        }
    }

    fun refreshNextDay(context: Context) {
        Thread { fetchTomorrowAndSchedule(context) }.start()
    }
}

class AthanLockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra("prayerName") ?: "dhuhr"
        LockPrefs.activateAthanLock(context, prayerName)
        LockForegroundService.ensureRunning(context)
    }
}

class PrayerScheduleRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AthanAlarmScheduler.refreshNextDay(context)
    }
}
