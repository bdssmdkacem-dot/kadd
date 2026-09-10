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
    private const val KEY_ATHAN_LOCK_STARTED_AT = "athan_lock_started_at"
    private const val MAX_ATHAN_LOCK_AGE_MS = 24L * 60L * 60L * 1000L

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

    /** Returns true only while the persisted exercise unlock deadline is future and no prayer lock is active. */
    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean {
        val key = "unlock_until_$packageName"
        val until = prefs(context).getLong(key, 0L)
        val prayerLockActive = isAthanLockActive(context)
        val active = !prayerLockActive && System.currentTimeMillis() < until
        if (!active && until != 0L && !prayerLockActive) {
            prefs(context).edit().remove(key).apply()
        }
        return active
    }

    /**
     * Activating a prayer lock invalidates all exercise unlock windows so they
     * cannot bypass the prayer requirement. A later prayer unlock therefore
     * returns the selected apps to their normal locked state.
     */
    fun activateAthanLock(context: Context, prayerName: String) {
        val editor = prefs(context).edit()
        prefs(context).all.keys
            .filter { it.startsWith("unlock_until_") }
            .forEach { key -> editor.remove(key) }
        editor
            .putBoolean(KEY_ATHAN_LOCK_ACTIVE, true)
            .putString(KEY_ACTIVE_PRAYER_NAME, prayerName)
            .putLong(KEY_ATHAN_LOCK_STARTED_AT, System.currentTimeMillis())
            .apply()
    }

    /**
     * A prayer lock is valid for at most 24 hours. This prevents a stale
     * boolean surviving a missed alarm, date rollover, or corrupted recovery.
     */
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

    fun grantAthanUnlockForCurrentWindow(context: Context) {
        clearAthanLock(context)
    }

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
