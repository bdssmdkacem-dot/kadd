package com.comptaflow.kadd

import android.content.Context
import java.util.concurrent.TimeUnit

/**
 * Single source of truth for "what's locked right now", read by
 * LockForegroundService on every poll tick and written to by MainActivity's
 * method channel handlers. Kept deliberately simple (SharedPreferences, not
 * a database) since the working set is small: a handful of package names
 * and a handful of timestamps.
 */
object LockPrefs {
    private const val PREFS = "kadd_lock_prefs"
    private const val KEY_LOCKED_PACKAGES = "locked_packages"
    private const val KEY_ATHAN_LOCK_ACTIVE = "athan_lock_active"
    private const val KEY_ACTIVE_PRAYER_NAME = "active_prayer_name"

    fun setLockedPackages(context: Context, packages: List<String>) {
        prefs(context).edit().putStringSet(KEY_LOCKED_PACKAGES, packages.toSet()).apply()
    }

    fun getLockedPackages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_LOCKED_PACKAGES, emptySet()) ?: emptySet()

    /** Per-package temporary unlock windows, e.g. "unlocked until epoch millis X". */
    fun grantUnlockUntil(context: Context, packageName: String, minutes: Int) {
        val until = System.currentTimeMillis() + TimeUnit.MINUTES.toMillis(minutes.toLong())
        prefs(context).edit().putLong("unlock_until_$packageName", until).apply()
    }

    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean {
        val until = prefs(context).getLong("unlock_until_$packageName", 0L)
        return System.currentTimeMillis() < until || isAthanLockLifted(context)
    }

    /** Set by AthanAlarmScheduler's receiver when the lock window begins. */
    fun activateAthanLock(context: Context, prayerName: String) {
        prefs(context).edit()
            .putBoolean(KEY_ATHAN_LOCK_ACTIVE, true)
            .putString(KEY_ACTIVE_PRAYER_NAME, prayerName)
            .apply()
    }

    fun isAthanLockActive(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ATHAN_LOCK_ACTIVE, false)

    fun getActivePrayerName(context: Context): String? =
        prefs(context).getString(KEY_ACTIVE_PRAYER_NAME, null)

    fun grantAthanUnlockForCurrentWindow(context: Context) {
        prefs(context).edit().putBoolean(KEY_ATHAN_LOCK_ACTIVE, false).apply()
    }

    private fun isAthanLockLifted(context: Context): Boolean = !isAthanLockActive(context)

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
