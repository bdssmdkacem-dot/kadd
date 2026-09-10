package com.comptaflow.kadd

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Full-screen verification activity launched by the native lock service. */
class LockActivity : FlutterActivity() {
    private val channelName = "com.comptaflow.kadd/lock"
    private val handler = Handler(Looper.getMainLooper())
    private var prayerVerification = false

    private val completionCheck = object : Runnable {
        override fun run() {
            if (isFinishing || isDestroyedCompat()) return

            // Prayer lock has higher priority than an exercise unlock. If the
            // prayer window starts while the user is already verifying an app,
            // switch this same native task to the prayer verification route.
            if (!prayerVerification && LockPrefs.isAthanLockActive(this@LockActivity)) {
                prayerVerification = true
                recreate()
                return
            }

            if (verificationCompleted()) {
                finishAndRemoveTask()
                return
            }
            LockPrefs.heartbeatLockActivity(this@LockActivity)
            handler.postDelayed(this, COMPLETION_CHECK_MS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prayerVerification = LockPrefs.isAthanLockActive(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "finishLockActivity" -> {
                    result.success(null)
                    finishAndRemoveTask()
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        LockPrefs.markLockActivityResumed(this, intent.getStringExtra("packageName"))
        handler.removeCallbacks(completionCheck)
        handler.post(completionCheck)
    }

    override fun onPause() {
        handler.removeCallbacks(completionCheck)
        LockPrefs.markLockActivityPaused(this)
        super.onPause()
    }

    override fun onDestroy() {
        handler.removeCallbacks(completionCheck)
        LockPrefs.markLockActivityDestroyed(this)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        prayerVerification = LockPrefs.isAthanLockActive(this)
        recreate()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Verification must succeed before the user can leave this screen.
    }

    private fun verificationCompleted(): Boolean {
        if (prayerVerification) return !LockPrefs.isAthanLockActive(this)
        val packageName = intent.getStringExtra("packageName")?.trim().orEmpty()
        if (packageName.isEmpty()) return false
        return LockPrefs.isCurrentlyUnlocked(this, packageName)
    }

    private fun isDestroyedCompat(): Boolean = Build.VERSION.SDK_INT >= 17 && isDestroyed

    override fun getInitialRoute(): String {
        return if (LockPrefs.isAthanLockActive(this)) {
            val prayer = LockPrefs.getActivePrayerName(this) ?: "dhuhr"
            "/lock/prayer?prayer=$prayer"
        } else {
            val packageName = intent.getStringExtra("packageName") ?: ""
            "/lock/rep?package=$packageName"
        }
    }

    override fun getCachedEngineId(): String? = null

    companion object {
        private const val COMPLETION_CHECK_MS = 250L
    }
}
