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
    private const val KEY_LOCK_ACTIVITY_ACTIVE = "lock_activity_active"
    private const val KEY_LOCK_ACTIVITY_RESUMED = "lock_activity_resumed"
    private const val KEY_LOCK_ACTIVITY_PACKAGE = "lock_activity_package"
    private const val KEY_LOCK_ACTIVITY_HEARTBEAT = "lock_activity_heartbeat"
    private const val LOCK_ACTIVITY_HEARTBEAT_TIMEOUT_MS = 8_000L
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

    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean {
        val key = "unlock_until_$packageName"
        val until = prefs(context).getLong(key, 0L)
        val prayerLockActive = isAthanLockActive(context)
        val active = !prayerLockActive && System.currentTimeMillis() < until
        if (!active && until != 0L && !prayerLockActive) prefs(context).edit().remove(key).apply()
        return active
    }

    fun activateAthanLock(context: Context, prayerName: String) {
        val editor = prefs(context).edit()
        prefs(context).all.keys.filter { it.startsWith("unlock_until_") }.forEach(editor::remove)
        editor.putBoolean(KEY_ATHAN_LOCK_ACTIVE, true)
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

    /** Marks the verification Activity alive and starts its recovery heartbeat. */
    fun markLockActivityResumed(context: Context, packageName: String?) {
        prefs(context).edit()
            .putBoolean(KEY_LOCK_ACTIVITY_ACTIVE, true)
            .putBoolean(KEY_LOCK_ACTIVITY_RESUMED, true)
            .putString(KEY_LOCK_ACTIVITY_PACKAGE, packageName?.trim().orEmpty())
            .putLong(KEY_LOCK_ACTIVITY_HEARTBEAT, System.currentTimeMillis())
            .apply()
    }

    fun heartbeatLockActivity(context: Context) {
        val preferences = prefs(context)
        if (!preferences.getBoolean(KEY_LOCK_ACTIVITY_ACTIVE, false)) return
        preferences.edit()
            .putBoolean(KEY_LOCK_ACTIVITY_RESUMED, true)
            .putLong(KEY_LOCK_ACTIVITY_HEARTBEAT, System.currentTimeMillis())
            .apply()
    }

    fun markLockActivityPaused(context: Context) {
        // Keep ACTIVE during transient system/UI pauses; heartbeat expiry handles process death.
        prefs(context).edit().putBoolean(KEY_LOCK_ACTIVITY_RESUMED, false).apply()
    }

    fun markLockActivityDestroyed(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_LOCK_ACTIVITY_ACTIVE, false)
            .putBoolean(KEY_LOCK_ACTIVITY_RESUMED, false)
            .remove(KEY_LOCK_ACTIVITY_PACKAGE)
            .remove(KEY_LOCK_ACTIVITY_HEARTBEAT)
            .apply()
    }

    fun isLockActivityAliveFor(context: Context, packageName: String): Boolean {
        val preferences = prefs(context)
        if (!preferences.getBoolean(KEY_LOCK_ACTIVITY_ACTIVE, false)) return false
        if (preferences.getString(KEY_LOCK_ACTIVITY_PACKAGE, "") != packageName) return false
        val heartbeat = preferences.getLong(KEY_LOCK_ACTIVITY_HEARTBEAT, 0L)
        if (heartbeat <= 0L || System.currentTimeMillis() - heartbeat > LOCK_ACTIVITY_HEARTBEAT_TIMEOUT_MS) {
            preferences.edit()
                .putBoolean(KEY_LOCK_ACTIVITY_ACTIVE, false)
                .putBoolean(KEY_LOCK_ACTIVITY_RESUMED, false)
                .remove(KEY_LOCK_ACTIVITY_PACKAGE)
                .remove(KEY_LOCK_ACTIVITY_HEARTBEAT)
                .apply()
            return false
        }
        return true
    }

    fun isLockActivityResumedFor(context: Context, packageName: String): Boolean =
        isLockActivityAliveFor(context, packageName)

    fun clearAllLockState(context: Context) = prefs(context).edit().clear().apply()

    private fun clearAthanLock(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_ATHAN_LOCK_ACTIVE, false)
            .remove(KEY_ACTIVE_PRAYER_NAME)
            .remove(KEY_ATHAN_LOCK_STARTED_AT)
            .apply()
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
