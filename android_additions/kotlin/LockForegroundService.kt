package com.comptaflow.kadd

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Watches the real foreground package and opens LockActivity whenever a
 * protected package becomes visible without a valid temporary unlock.
 *
 * We intentionally do NOT depend only on MOVE_TO_FOREGROUND events: on some
 * Android/OEM builds those events are not emitted during a short polling
 * window. queryUsageStats() gives us the package that was most recently used.
 */
class LockForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 750)
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
        val locked = LockPrefs.getLockedPackages(this)
        if (locked.isEmpty()) return

        val foreground = findForegroundPackage() ?: return
        if (foreground == packageName) return
        if (foreground !in locked) return
        if (LockPrefs.isCurrentlyUnlocked(this, foreground)) return

        // Launching the lock screen is the actual enforcement point. Do not
        // cache the package: the same app must be lockable again immediately
        // after its temporary unlock window expires.
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
            // Some OEMs briefly reject activity launches while changing tasks.
            // The next poll retries automatically.
        }
    }

    private fun findForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()

        // Primary method: latest lastTimeUsed in a short window.
        val stats: List<UsageStats> = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            end - 15_000L,
            end
        ) ?: emptyList()
        val latest = stats
            .asSequence()
            .filter { it.packageName.isNotBlank() }
            .maxByOrNull { it.lastTimeUsed }
            ?.packageName
        if (latest != null) return latest

        // Fallback for devices where queryUsageStats is sparse.
        val events = usm.queryEvents(end - 15_000L, end)
        val event = android.app.usage.UsageEvents.Event()
        var foreground: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                foreground = event.packageName
            }
        }
        return foreground
    }

    private fun buildNotification(): android.app.Notification {
        val channelId = "kadd_lock_service"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "حماية كدّ نشطة",
                NotificationManager.IMPORTANCE_MIN
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("كدّ يراقب تطبيقاتك المقفلة")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val NOTIF_ID = 1001

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
