package com.comptaflow.kadd

import android.content.Context
import java.util.concurrent.TimeUnit

object LockPrefs {
    private const val PREFS = "kadd_lock_prefs"
    private const val KEY_LOCKED_PACKAGES = "locked_packages"
    private const val KEY_ATHAN_LOCK_ACTIVE = "athan_lock_active"
    private const val KEY_ACTIVE_PRAYER_NAME = "active_prayer_name"
    fun setLockedPackages(context: Context, packages: List<String>) { prefs(context).edit().putStringSet(KEY_LOCKED_PACKAGES, packages.toSet()).apply() }
    fun getLockedPackages(context: Context): Set<String> = prefs(context).getStringSet(KEY_LOCKED_PACKAGES, emptySet()) ?: emptySet()
    fun grantUnlockUntil(context: Context, packageName: String, minutes: Int) { prefs(context).edit().putLong("unlock_until_$packageName", System.currentTimeMillis() + TimeUnit.MINUTES.toMillis(minutes.toLong())).apply() }
    fun isCurrentlyUnlocked(context: Context, packageName: String): Boolean = System.currentTimeMillis() < prefs(context).getLong("unlock_until_$packageName", 0L) || !isAthanLockActive(context)
    fun activateAthanLock(context: Context, prayerName: String) { prefs(context).edit().putBoolean(KEY_ATHAN_LOCK_ACTIVE, true).putString(KEY_ACTIVE_PRAYER_NAME, prayerName).apply() }
    fun isAthanLockActive(context: Context): Boolean = prefs(context).getBoolean(KEY_ATHAN_LOCK_ACTIVE, false)
    fun getActivePrayerName(context: Context): String? = prefs(context).getString(KEY_ACTIVE_PRAYER_NAME, null)
    fun grantAthanUnlockForCurrentWindow(context: Context) { prefs(context).edit().putBoolean(KEY_ATHAN_LOCK_ACTIVE, false).apply() }
    private fun isAthanLockActive(context: Context) = prefs(context).getBoolean(KEY_ATHAN_LOCK_ACTIVE, false)
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
