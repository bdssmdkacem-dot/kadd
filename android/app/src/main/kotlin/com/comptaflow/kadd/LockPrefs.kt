package com.comptaflow.kadd

import android.content.Context
import java.util.concurrent.TimeUnit

/** Persistent source of truth for Kadd's native lock state. */
object LockPrefs {
    private const val PREFS = "kadd_lock_prefs"
    private const val KEY_LOCKED_PACKAGES = "locked_packages"
    private const val KEY_ATHAN_LOCK_ACTIVE = "athan_lock_active"
    private const val KEY_ACTIVE_PRAYER_NAME = "active_prayer_name"
    private const val KEY_ATHAN_LOCK_STARTED_AT = "athan_lock_started_at"
    private const val MAX_ATHAN_LOCK_AGE_MS = 24L * 60L * 60L * 1000L

    fun setLockedPackages(context: Context, packages: List<String>) {
        val cleaned = packages.asSequence().map(String::trim).filter(String::isNotEmpty).toSet()
        prefs(context).edit().putStringSet(KEY_LOCKED_PACKAGES, cleaned).apply()
    }

    fun getLockedPackages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_LOCKED_PACKAGES, emptySet())?.toSet() ?: emptySet()

    fun grantUnlockUntil(context: Context, packageName: String, minutes: Int) {
        val safeMinutes = minutes.coerceAtLeast(0)
        val until = System.currentTimeMillis() + TimeUnit.MINUTES.toMillis(safeMinutes.toLong())
        prefs(context).edit().putLong("unlock_until_$packageName", until).apply()
    }

    /** Returns true only while the persisted exercise unlock deadline is future. */
    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean {
        val key = "unlock_until_$packageName"
        val until = prefs(context).getLong(key, 0L)
        val active = System.currentTimeMillis() < until
        if (!active && until != 0L) prefs(context).edit().remove(key).apply()
        return active
    }

    fun activateAthanLock(context: Context, prayerName: String) {
        prefs(context).edit()
            .putBoolean(KEY_ATHAN_LOCK_ACTIVE, true)
            .putString(KEY_ACTIVE_PRAYER_NAME, prayerName)
            .putLong(KEY_ATHAN_LOCK_STARTED_AT, System.currentTimeMillis())
            .apply()
    }

    fun isAthanLockActive(context: Context): Boolean {
        val preferences = prefs(context)
        if (!preferences.getBoolean(KEY_ATHAN_LOCK_ACTIVE, false)) return false
        val startedAt = preferences.getLong(KEY_ATHAN_LOCK_STARTED_AT, 0L)
        if (startedAt <= 0L || System.currentTimeMillis() - startedAt >= MAX_ATHAN_LOCK_AGE_MS) {
            clearAthanLock(context)
            return false
        }
        return true
    }

    fun getActivePrayerName(context: Context): String? =
        if (isAthanLockActive(context)) prefs(context).getString(KEY_ACTIVE_PRAYER_NAME, null) else null

    fun grantAthanUnlockForCurrentWindow(context: Context) = clearAthanLock(context)

    /** Clears every persisted native lock/unlock flag during a full app reset. */
    fun clearAllLockState(context: Context) {
        prefs(context).edit().clear().apply()
    }

    private fun clearAthanLock(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_ATHAN_LOCK_ACTIVE, false)
            .remove(KEY_ACTIVE_PRAYER_NAME)
            .remove(KEY_ATHAN_LOCK_STARTED_AT)
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
