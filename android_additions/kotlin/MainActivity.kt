package com.comptaflow.kadd

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
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
                        android.util.Log.e("Kadd", "App discovery failed", e)
                        result.error("APP_LIST_ERROR", e.message ?: "Unable to discover apps", null)
                    }
                }
                "syncLockedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    LockPrefs.setLockedPackages(this, packages)
                    if (packages.isEmpty()) stopService(Intent(this, LockForegroundService::class.java))
                    else LockForegroundService.ensureRunning(this)
                    result.success(null)
                }
                "grantTemporaryUnlock" -> {
                    val packageName = call.argument<String>("packageName")
                    val minutes = call.argument<Int>("minutes")
                    if (packageName.isNullOrBlank() || minutes == null || minutes <= 0) {
                        result.error("INVALID_UNLOCK", "packageName and positive minutes are required", null)
                    } else {
                        LockPrefs.grantUnlockUntil(this, packageName, minutes)
                        result.success(null)
                    }
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

    /**
     * Source of truth for the picker: every installed package for which
     * Android can resolve a launchable activity. We intentionally combine
     * launcher-query and installed-package discovery because OEM Android
     * builds differ in what they expose through CATEGORY_LAUNCHER.
     */
    private fun discoverApps(): List<Map<String, Any?>> {
        val byPackage = linkedMapOf<String, Map<String, Any?>>()
        val ownPackage = applicationContext.packageName

        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launcherFlags = if (Build.VERSION.SDK_INT >= 23) PackageManager.MATCH_ALL else 0
        val launcherActivities = packageManager.queryIntentActivities(launcherIntent, launcherFlags)
        android.util.Log.d("Kadd", "Launcher activities returned: ${launcherActivities.size}")

        launcherActivities.forEach { resolveInfo ->
            val appInfo = resolveInfo.activityInfo?.applicationInfo ?: return@forEach
            if (appInfo.packageName != ownPackage) addApp(byPackage, appInfo)
        }

        val installed = if (Build.VERSION.SDK_INT >= 33) {
            packageManager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(
                PackageManager.MATCH_ALL.toLong()
            ))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledApplications(PackageManager.MATCH_ALL)
        }
        android.util.Log.d("Kadd", "Installed applications returned: ${installed.size}")

        installed.forEach { appInfo ->
            if (appInfo.packageName == ownPackage) return@forEach
            val launchIntent = packageManager.getLaunchIntentForPackage(appInfo.packageName)
            if (launchIntent != null) addApp(byPackage, appInfo)
        }

        val apps = byPackage.values.sortedBy {
            (it["name"] as String).lowercase(Locale.getDefault())
        }
        android.util.Log.d("Kadd", "Kadd discovered ${apps.size} launchable installed apps")
        return apps
    }

    private fun addApp(
        destination: MutableMap<String, Map<String, Any?>>,
        appInfo: ApplicationInfo,
    ) {
        val packageName = appInfo.packageName
        if (destination.containsKey(packageName)) return

        val label = try {
            appInfo.loadLabel(packageManager)?.toString()?.trim().orEmpty()
        } catch (_: Exception) {
            ""
        }
        if (label.isEmpty()) return

        destination[packageName] = mapOf(
            "name" to label,
            "packageName" to packageName,
            "icon" to drawableToPng(appInfo.loadIcon(packageManager)),
            "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
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
