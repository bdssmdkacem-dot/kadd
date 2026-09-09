package com.comptaflow.kadd

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.concurrent.TimeUnit

/** Persists the next prayer alarms so Android can restore them after reboot. */
object AthanAlarmScheduler {
    private const val PREFS = "kadd_prayer_alarms"
    private const val KEY_ALARMS = "alarms"
    private const val SEPARATOR = "|"

    fun schedule(context: Context, prayers: List<Map<String, Any>>, delayMinutes: Int) {
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

            scheduleOne(context, alarmManager, name, triggerAt)
            persisted += "$name$SEPARATOR$triggerAt"
        }
        save(context, persisted)
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
            if (triggerAt > now) {
                scheduleOne(context, alarmManager, name, triggerAt)
                remaining += entry
            }
        }
        save(context, remaining)
    }

    private fun scheduleOne(context: Context, alarmManager: AlarmManager, name: String, triggerAt: Long) {
        val intent = Intent(context, AthanLockReceiver::class.java).apply { putExtra("prayerName", name) }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            stableRequestCode(name),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) return
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
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

    private fun stableRequestCode(name: String): Int = name.hashCode()

    private fun load(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet(KEY_ALARMS, emptySet()) ?: emptySet()

    private fun save(context: Context, entries: List<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putStringSet(KEY_ALARMS, entries.toSet()).apply()
    }
}

class AthanLockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra("prayerName") ?: "dhuhr"
        LockPrefs.activateAthanLock(context, prayerName)
        LockForegroundService.ensureRunning(context)
    }
}
