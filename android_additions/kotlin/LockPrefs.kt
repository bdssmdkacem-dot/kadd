package com.comptaflow.kadd

import android.content.Context
import java.util.concurrent.TimeUnit

/**
 * Persistent source of truth for Kadd's native lock state.
 * SharedPreferences is sufficient because the working set is small.
 */
object LockPrefs {
    private const val PREFS = "kadd_lock_prefs"
    private const val KEY_LOCKED_PACKAGES = "locked_packages"
    private const val KEY_ATHAN_LOCK_ACTIVE = "athan_lock_active"
    private const val KEY_ACTIVE_PRAYER_NAME = "active_prayer_name"

    fun setLockedPackages(context: Context, packages: List<String>) {
        val cleaned = packages.asSequence()
            .map(String::trim)
            .filter(String::isNotEmpty)
            .toSet()
        prefs(context).edit().putStringSet(KEY_LOCKED_PACKAGES, cleaned).apply()
    }

    fun getLockedPackages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_LOCKED_PACKAGES, emptySet())?.toSet() ?: emptySet()

    /** Grants a package a temporary unlock window starting now. */
    fun grantUnlockUntil(context: Context, packageName: String, minutes: Int) {
        val safeMinutes = minutes.coerceAtLeast(0)
        val until = System.currentTimeMillis() + TimeUnit.MINUTES.toMillis(safeMinutes.toLong())
        prefs(context).edit().putLong("unlock_until_$packageName", until).apply()
    }

    /** Returns true only while the persisted unlock deadline is still in the future. */
    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean {
        val key = "unlock_until_$packageName"
        val until = prefs(context).getLong(key, 0L)
        val active = System.currentTimeMillis() < until
        if (!active && until != 0L) {
            prefs(context).edit().remove(key).apply()
        }
        return active
    }

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
        prefs(context).edit()
            .putBoolean(KEY_ATHAN_LOCK_ACTIVE, false)
            .remove(KEY_ACTIVE_PRAYER_NAME)
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
