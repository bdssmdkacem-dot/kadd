package com.comptaflow.kadd

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.concurrent.TimeUnit

/**
 * Schedules one exact alarm per enabled prayer, firing `delayMinutes` after
 * that prayer's Athan time. When it fires, AthanLockReceiver flips the
 * "Athan lock active" flag that LockForegroundService checks.
 *
 * Uses setExactAndAllowWhileIdle so the lock still engages even if the
 * phone is dozing — worth re-testing on OEM skins (Xiaomi/Huawei/Samsung)
 * known for aggressive background-alarm throttling, common in the Moroccan
 * Android install base.
 */
object AthanAlarmScheduler {
    fun schedule(context: Context, prayers: List<Map<String, Any>>, delayMinutes: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        prayers.forEach { prayer ->
            val name = prayer["name"] as String
            val epochMillis = (prayer["epochMillis"] as Number).toLong()
            val triggerAt = epochMillis + TimeUnit.MINUTES.toMillis(delayMinutes.toLong())

            val intent = Intent(context, AthanLockReceiver::class.java).apply {
                putExtra("prayerName", name)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                name.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (triggerAt > System.currentTimeMillis()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }
    }
}

class AthanLockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra("prayerName") ?: "dhuhr"
        LockPrefs.activateAthanLock(context, prayerName)
        LockForegroundService.ensureRunning(context)
    }
}
