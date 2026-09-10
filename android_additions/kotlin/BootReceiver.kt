package com.comptaflow.kadd

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores enforcement and rebuilds prayer alarms after lifecycle/clock events. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                AthanAlarmScheduler.restore(context)
                if (canScheduleExactAlarms(context)) {
                    AthanAlarmScheduler.refreshTodayAndTomorrow(context)
                }

                if (LockPrefs.getLockedPackages(context).isNotEmpty() || LockPrefs.isAthanLockActive(context)) {
                    LockForegroundService.ensureRunning(context)
                }
            }
        }
    }

    private fun canScheduleExactAlarms(context: Context): Boolean {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }
}
