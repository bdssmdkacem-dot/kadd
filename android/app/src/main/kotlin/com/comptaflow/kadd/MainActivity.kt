package com.comptaflow.kadd

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "com.comptaflow.kadd/lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "requestUsageAccess" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "getLaunchableApps" -> {
                    try {
                        result.success(getLaunchableApps())
                    } catch (e: Exception) {
                        result.error("APP_LIST_ERROR", e.message, null)
                    }
                }
                "syncLockedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    LockPrefs.setLockedPackages(this, packages)
                    LockForegroundService.ensureRunning(this)
                    result.success(null)
                }
                "grantTemporaryUnlock" -> {
                    LockPrefs.grantUnlockUntil(this, call.argument<String>("packageName")!!, call.argument<Int>("minutes")!!)
                    result.success(null)
                }
                "grantAthanUnlock" -> {
                    LockPrefs.grantAthanUnlockForCurrentWindow(this)
                    result.success(null)
                }
                "scheduleAthanLocks" -> {
                    @Suppress("UNCHECKED_CAST")
                    val prayers = call.argument<List<Map<String, Any>>>("prayers") ?: emptyList()
                    AthanAlarmScheduler.schedule(this, prayers, call.argument<Int>("delayMinutes") ?: 5)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getLaunchableApps(): List<Map<String, Any?>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolved = packageManager.queryIntentActivities(
            launcherIntent,
            android.content.pm.PackageManager.MATCH_ALL
        )

        val all = resolved.mapNotNull { info ->
            val appInfo = info.activityInfo?.applicationInfo ?: return@mapNotNull null
            if (appInfo.packageName == applicationContext.packageName) return@mapNotNull null
            val label = appInfo.loadLabel(packageManager)?.toString()?.trim().orEmpty()
            if (label.isEmpty()) return@mapNotNull null
            val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
            mapOf<String, Any?>(
                "name" to label,
                "packageName" to appInfo.packageName,
                "icon" to drawableToPng(appInfo.loadIcon(packageManager)),
                "isSystemApp" to isSystem,
            )
        }.distinctBy { it["packageName"] as String }

        val userApps = all.filter { it["isSystemApp"] != true }
        val result = if (userApps.isNotEmpty()) userApps else all
        return result.sortedBy { (it["name"] as String).lowercase(Locale.getDefault()) }
    }

    private fun drawableToPng(drawable: android.graphics.drawable.Drawable): ByteArray? {
        return try {
            val size = 96
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            ByteArrayOutputStream().use { output ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                bitmap.recycle()
                output.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        ) == AppOpsManager.MODE_ALLOWED
    }
}
