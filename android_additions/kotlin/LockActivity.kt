package com.comptaflow.kadd

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * A separate FlutterActivity that boots straight into the RepCameraScreen
 * or PrayerLockScreen route (never RootNav) via Flutter's initial-route
 * mechanism — see lib/main.dart's onGenerateRoute for the Dart side of this
 * contract. LockForegroundService starts this Activity full-screen the
 * moment a locked, unverified package is foregrounded.
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
