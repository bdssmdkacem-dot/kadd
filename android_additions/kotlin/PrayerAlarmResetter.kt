package com.comptaflow.kadd

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Locale

/** Cancels every persisted prayer alarm when the user performs a full reset. */
object PrayerAlarmResetter {
    private const val PREFS = "kadd_prayer_alarms"
    private const val KEY_ALARMS = "alarms"
    private const val SEPARATOR = "|"
    private const val REFRESH_REQUEST_CODE = 0x4B414444

    fun clear(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        prefs.getStringSet(KEY_ALARMS, emptySet()).orEmpty().forEach { raw ->
            val separator = raw.lastIndexOf(SEPARATOR)
            if (separator <= 0 || separator >= raw.lastIndex) return@forEach
            val name = raw.substring(0, separator).trim()
            val triggerAt = raw.substring(separator + 1).toLongOrNull() ?: return@forEach
            if (name.isEmpty()) return@forEach

            val currentIntent = PendingIntent.getBroadcast(
                context,
                "${name.lowercase(Locale.US)}:$triggerAt".hashCode(),
                Intent(context, AthanLockReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(currentIntent)

            val legacyIntent = PendingIntent.getBroadcast(
                context,
                name.lowercase(Locale.US).hashCode(),
                Intent(context, AthanLockReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(legacyIntent)
        }

        val refreshIntent = PendingIntent.getBroadcast(
            context,
            REFRESH_REQUEST_CODE,
            Intent(context, PrayerScheduleRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(refreshIntent)
        prefs.edit().clear().apply()
    }
}
