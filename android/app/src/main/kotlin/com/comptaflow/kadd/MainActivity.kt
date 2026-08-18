package com.comptaflow.kadd

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
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
                        result.success(discoverApps())
                    } catch (e: Exception) {
                        result.error("APP_LIST_ERROR", e.stackTraceToString(), null)
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

    private fun discoverApps(): List<Map<String, Any?>> {
        val byPackage = linkedMapOf<String, Map<String, Any?>>()
        val ownPackage = applicationContext.packageName

        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launcherFlags = if (android.os.Build.VERSION.SDK_INT >= 23) PackageManager.MATCH_ALL else 0

        try {
            packageManager.queryIntentActivities(launcherIntent, launcherFlags).forEach { info ->
                val appInfo = info.activityInfo?.applicationInfo ?: return@forEach
                if (appInfo.packageName == ownPackage) return@forEach
                addApp(byPackage, appInfo)
            }
        } catch (e: Exception) {
            android.util.Log.w("Kadd", "Launcher query failed: ${e.message}")
        }

        // Vendor-ROM fallback: enumerate installed packages and keep packages
        // that Android itself says can be launched.
        if (byPackage.isEmpty()) {
            val installed = if (android.os.Build.VERSION.SDK_INT >= 33) {
                packageManager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstalledApplications(0)
            }
            installed.forEach { appInfo ->
                if (appInfo.packageName == ownPackage) return@forEach
                if (packageManager.getLaunchIntentForPackage(appInfo.packageName) != null) {
                    addApp(byPackage, appInfo)
                }
            }
        }

        val all = byPackage.values.toList()
        val userApps = all.filter { it["isSystemApp"] != true }
        val chosen = if (userApps.isNotEmpty()) userApps else all
        return chosen.sortedBy { (it["name"] as String).lowercase(Locale.getDefault()) }
    }

    private fun addApp(destination: MutableMap<String, Map<String, Any?>>, appInfo: ApplicationInfo) {
        val packageName = appInfo.packageName
        if (destination.containsKey(packageName)) return
        val label = appInfo.loadLabel(packageManager)?.toString()?.trim().orEmpty()
        if (label.isEmpty()) return
        val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        destination[packageName] = mapOf(
            "name" to label,
            "packageName" to packageName,
            "icon" to drawableToPng(appInfo.loadIcon(packageManager)),
            "isSystemApp" to isSystem,
        )
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
