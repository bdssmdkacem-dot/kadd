package com.comptaflow.kadd

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
            Intent.ACTION_DATE_CHANGED -> {
                AthanAlarmScheduler.restore(context)
                AthanAlarmScheduler.refreshTodayAndTomorrow(context)

                if (LockPrefs.getLockedPackages(context).isNotEmpty() || LockPrefs.isAthanLockActive(context)) {
                    LockForegroundService.ensureRunning(context)
                }
            }
        }
    }
}
