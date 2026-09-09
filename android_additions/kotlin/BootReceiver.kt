package com.comptaflow.kadd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores all persisted native enforcement state after Android reboot. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        // AlarmManager clears alarms on reboot. The scheduler keeps the next
        // known prayer epochs locally, so no network or Flutter startup is
        // required here to restore a still-future prayer lock.
        AthanAlarmScheduler.restore(context)

        if (LockPrefs.getLockedPackages(context).isNotEmpty() || LockPrefs.isAthanLockActive(context)) {
            LockForegroundService.ensureRunning(context)
        }
    }
}
