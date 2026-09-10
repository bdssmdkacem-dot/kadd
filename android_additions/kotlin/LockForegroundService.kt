package com.comptaflow.kadd

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Owns Android-side enforcement for Kadd's configured app locks.
 *
 * The service is deliberately idempotent: every poll reads the persisted
 * source of truth, ignores Kadd itself, ignores active unlock windows, and
 * launches at most the single LockActivity task needed for the current
 * foreground package. No AccessibilityService is used.
 */
class LockForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                checkForegroundApp()
            } catch (t: Throwable) {
                // UsageStats/OEM task APIs can fail transiently. Keep the
                // enforcement loop alive instead of losing protection until
                // Android happens to recreate the service.
                Log.w(TAG, "Lock enforcement poll failed; retrying", t)
            } finally {
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIF_ID, buildNotification())
        handler.post(pollRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundApp() {
        if (!hasUsageAccess()) {
            stopSelf()
            return
        }

        LockPrefs.pruneExpiredUnlocks(this)

        val persisted = LockPrefs.getLockedPackages(this)
        if (persisted.isEmpty()) {
            stopSelf()
            return
        }

        // Package removal can happen while Kadd is not running. Prune only
        // packages that Android definitively no longer knows about; a temporary
        // discovery failure must never erase a user's configuration.
        val installed = persisted.filterTo(mutableSetOf()) { isInstalled(it) }
        if (installed.size != persisted.size) {
            LockPrefs.setLockedPackages(this, installed.toList())
        }
        if (installed.isEmpty()) {
            stopSelf()
            return
        }

        val foreground = findForegroundPackage() ?: return
        if (foreground == packageName || foreground !in installed) return
        if (LockPrefs.isCurrentlyUnlocked(this, foreground)) return

        // A lock screen may already be visible for this exact foreground app.
        // Do not send another intent every 750 ms: doing so would trigger
        // onNewIntent()/recreate() repeatedly and could interrupt verification.
        if (LockPrefs.isLockActivityResumedFor(this, foreground)) return

        val lockIntent = Intent(this, LockActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra("packageName", foreground)
        }
        try {
            startActivity(lockIntent)
        } catch (_: Exception) {
            // OEM task restrictions are transient; the next poll retries.
        }
    }

    private fun isInstalled(packageName: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            packageManager.getApplicationInfo(
                packageName,
                android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION") packageManager.getApplicationInfo(packageName, 0)
        }
        true
    } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
        false
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun findForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - LOOKBACK_MS

        val events = usm.queryEvents(start, end)
        val event = UsageEvents.Event()
        var foreground: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            ) {
                if (event.packageName.isNotBlank()) foreground = event.packageName
            }
        }
        if (foreground != null) return foreground

        val stats: List<UsageStats> = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            start,
            end,
        ) ?: emptyList()
        return stats.asSequence()
            .filter { it.packageName.isNotBlank() }
            .maxByOrNull { it.lastTimeUsed }
            ?.packageName
    }

    private fun buildNotification(): android.app.Notification {
        val channelId = "kadd_lock_service"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "حماية كدّ نشطة",
                NotificationManager.IMPORTANCE_MIN,
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("كدّ يراقب تطبيقاتك المقفلة")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val TAG = "KaddLock"
        private const val NOTIF_ID = 1001
        private const val POLL_INTERVAL_MS = 750L
        private const val LOOKBACK_MS = 15_000L

        fun ensureRunning(context: Context) {
            val intent = Intent(context, LockForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
