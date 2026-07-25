package com.comptaflow.kadd

import io.flutter.embedding.android.FlutterActivity

/**
 * A separate FlutterActivity that boots straight into the RepCameraScreen
 * or PrayerLockScreen route (never RootNav) via Flutter's initial-route
 * mechanism — see lib/main.dart's onGenerateRoute for the Dart side of this
 * contract. LockForegroundService starts this Activity full-screen the
 * moment a locked, unverified package is foregrounded.
 */
class LockActivity : FlutterActivity() {
    override fun getInitialRoute(): String {
        return if (LockPrefs.isAthanLockActive(this)) {
            val prayer = LockPrefs.getActivePrayerName(this) ?: "dhuhr"
            "/lock/prayer?prayer=$prayer"
        } else {
            val packageName = intent.getStringExtra("packageName") ?: ""
            "/lock/rep?package=$packageName"
        }
    }

    // Each locked-app launch gets its own fresh engine rather than a shared
    // cached one — simpler to reason about for a screen that's shown for a
    // few seconds at a time, at the cost of a slightly slower cold start.
    // Worth revisiting with a cached/pre-warmed engine if that startup lag
    // is noticeable in practice.
    override fun getCachedEngineId(): String? = null
}
