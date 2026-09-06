package com.comptaflow.kadd

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
import androidx.core.app.NotificationCompat

/**
 * Owns the Android-side enforcement loop for Kadd app locks.
 *
 * UsageEvents is preferred because it represents foreground transitions. The
 * UsageStats query is only a fallback for devices/OEMs where events are sparse.
 * No AccessibilityService is used.
 */
class LockForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
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
        if (locked.isEmpty()) {
            stopSelf()
            return
        }

        val foreground = findForegroundPackage() ?: return
        if (foreground == packageName || foreground !in locked) return
        if (LockPrefs.isCurrentlyUnlocked(this, foreground)) return

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
            // The next poll retries if Android/OEM task policy temporarily
            // rejects the launch while the foreground task is changing.
        }
    }

    private fun findForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - LOOKBACK_MS

        // Prefer actual foreground transitions. ACTIVITY_RESUMED is the modern
        // signal; MOVE_TO_FOREGROUND covers older Android releases.
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

        // Fallback for OEMs that expose stats but not recent events.
        val stats: List<UsageStats> = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            start,
            end
        ) ?: emptyList()
        return stats
            .asSequence()
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
