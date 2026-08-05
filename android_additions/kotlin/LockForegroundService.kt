package com.comptaflow.kadd

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Polls the foreground app roughly once a second via UsageStatsManager and,
 * if it's a locked package with no active unlock window, launches
 * LockActivity (a thin native Activity that hosts the Flutter
 * RepCameraScreen / PrayerLockScreen route) full-screen on top of it.
 *
 * Chosen over AccessibilityService deliberately — see AppUsageService's
 * Dart-side doc comment for the Play Store policy reasoning. The tradeoff:
 * polling has up to ~1s latency and a small battery cost, both acceptable
 * for this use case.
 */
class LockForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastForegroundPackage: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 1000)
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
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val begin = end - 2000
        val events = usm.queryEvents(begin, end)
        var foreground: String? = null
        val event = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                foreground = event.packageName
            }
        }
        if (foreground == null || foreground == lastForegroundPackage) return
        lastForegroundPackage = foreground

        val locked = LockPrefs.getLockedPackages(this)
        if (foreground in locked && !LockPrefs.isCurrentlyUnlocked(this, foreground)) {
            val lockIntent = Intent(this, LockActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("packageName", foreground)
            }
            startActivity(lockIntent)
        }
    }

    private fun buildNotification(): android.app.Notification {
        val channelId = "kadd_lock_service"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "حماية كدّ نشطة", NotificationManager.IMPORTANCE_MIN)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
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
