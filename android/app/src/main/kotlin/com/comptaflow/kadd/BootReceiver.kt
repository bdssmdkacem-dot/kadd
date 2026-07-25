package com.comptaflow.kadd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts LockForegroundService after a reboot, so app-lock (reps-based)
 * keeps working without the user having to reopen Kadd first.
 *
 * LIMITATION — Athan-based locks are NOT rescheduled here. Rebuilding
 * today's prayer alarms needs a fresh Aladhan API call (network) plus a GPS
 * fix, which isn't something a plain BroadcastReceiver can reliably wait on
 * within its short execution window. Two ways to close this gap properly:
 *   1. Enqueue a WorkManager one-off task here with a network constraint,
 *      that runs PrayerTimesService's fetch + AthanAlarmScheduler once
 *      connectivity is back.
 *   2. Accept the gap and rely on the user opening the app at least once
 *      during the day (main.dart's AppState.init() already re-fetches and
 *      re-schedules on every app launch) — reasonable for a first release,
 *      since most people open their phone well before Dhuhr anyway.
 * Shipping with (2) for now; revisit if reboot timing near a prayer time
 * turns out to be a real complaint in testing.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            if (LockPrefs.getLockedPackages(context).isNotEmpty()) {
                LockForegroundService.ensureRunning(context)
            }
        }
    }
}
