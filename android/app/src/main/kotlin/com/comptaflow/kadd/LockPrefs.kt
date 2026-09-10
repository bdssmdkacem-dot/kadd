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
    private val VALID_PRAYERS = setOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    fun setLockedPackages(context: Context, packages: List<String>) {
        val cleaned = packages.asSequence().map(String::trim).filter(String::isNotEmpty).toSet()
        prefs(context).edit().putStringSet(KEY_LOCKED_PACKAGES, cleaned).apply()
    }

    fun getLockedPackages(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_LOCKED_PACKAGES, emptySet())?.toSet() ?: emptySet()

    fun grantUnlockUntil(context: Context, packageName: String, minutes: Int) {
        val safePackage = packageName.trim()
        val safeMinutes = minutes.coerceAtLeast(0)
        if (safePackage.isEmpty() || safeMinutes <= 0) return
        val until = System.currentTimeMillis() + TimeUnit.MINUTES.toMillis(safeMinutes.toLong())
        prefs(context).edit().putLong("unlock_until_$safePackage", until).apply()
    }

    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean {
        val safePackage = packageName.trim()
        if (safePackage.isEmpty()) return false
        val key = "unlock_until_$safePackage"
        val until = prefs(context).getLong(key, 0L)
        val prayerLockActive = isAthanLockActive(context)
        val active = !prayerLockActive && System.currentTimeMillis() < until
        if (!active && until != 0L && !prayerLockActive) prefs(context).edit().remove(key).apply()
        return active
    }

    /** Removes expired or orphaned exercise unlock deadlines. */
    fun pruneExpiredUnlocks(context: Context) {
        if (isAthanLockActive(context)) return
        val now = System.currentTimeMillis()
        val locked = getLockedPackages(context)
        val editor = prefs(context).edit()
        var changed = false
        prefs(context).all.forEach { (key, value) ->
            if (!key.startsWith("unlock_until_")) return@forEach
            val packageName = key.removePrefix("unlock_until_")
            val expired = value is Long && value <= now
            val orphaned = packageName.isBlank() || packageName !in locked
            if (expired || orphaned) {
                editor.remove(key)
                changed = true
            }
        }
        if (changed) editor.apply()
    }

    fun activateAthanLock(context: Context, prayerName: String) {
        val normalized = prayerName.trim().lowercase(java.util.Locale.US)
        if (normalized !in VALID_PRAYERS) return
        val editor = prefs(context).edit()
        prefs(context).all.keys.filter { it.startsWith("unlock_until_") }.forEach(editor::remove)
        editor.putBoolean(KEY_ATHAN_LOCK_ACTIVE, true)
            .putString(KEY_ACTIVE_PRAYER_NAME, normalized)
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

    fun grantAthanUnlockForPrayer(context: Context, prayerName: String): Boolean {
        val normalized = prayerName.trim().lowercase(java.util.Locale.US)
        if (normalized !in VALID_PRAYERS || !isAthanLockActive(context)) return false
        if (getActivePrayerName(context)?.lowercase(java.util.Locale.US) != normalized) return false
        clearAthanLock(context)
        return true
    }

    fun grantAthanUnlockForCurrentWindow(context: Context) {
        if (isAthanLockActive(context)) clearAthanLock(context)
    }

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
