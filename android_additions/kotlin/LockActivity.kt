package com.comptaflow.kadd

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * Full-screen verification activity launched by the native lock service.
 * Back navigation is deliberately disabled: leaving this activity must not
 * become an alternate path around the verification requirement.
 */
class LockActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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

    /** Refresh the lock route when a new lock intent reaches an existing activity. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }

    /** Do not allow Android Back to dismiss an active verification screen. */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Verification must succeed before the user can leave this screen.
    }

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
}
