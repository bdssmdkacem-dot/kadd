package com.comptaflow.kadd

import android.app.AppOpsManager
import android.content.Intent
import android.content.Context
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.comptaflow.kadd/lock"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "requestUsageAccess" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                "syncLockedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    LockPrefs.setLockedPackages(this, packages)
                    LockForegroundService.ensureRunning(this)
                    result.success(null)
                }
                "grantTemporaryUnlock" -> {
                    LockPrefs.grantUnlockUntil(this, call.argument<String>("packageName")!!, call.argument<Int>("minutes")!!); result.success(null)
                }
                "grantAthanUnlock" -> { LockPrefs.grantAthanUnlockForCurrentWindow(this); result.success(null) }
                "scheduleAthanLocks" -> {
                    @Suppress("UNCHECKED_CAST") val prayers = call.argument<List<Map<String, Any>>>("prayers") ?: emptyList()
                    AthanAlarmScheduler.schedule(this, prayers, call.argument<Int>("delayMinutes") ?: 5); result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }
}
