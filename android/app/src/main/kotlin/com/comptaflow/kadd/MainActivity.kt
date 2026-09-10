package com.comptaflow.kadd

import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "com.comptaflow.kadd/lock"
    private val maxExerciseUnlockMinutes = 180
    private val supportedPrayerNames = setOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "requestUsageAccess" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                "requestExactAlarmAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply { data = android.net.Uri.parse("package:$packageName") })
                    result.success(null)
                }
                "isAthanLockActive" -> result.success(LockPrefs.isAthanLockActive(this))
                "activePrayerName" -> result.success(LockPrefs.getActivePrayerName(this))
                "getLaunchableApps" -> try { result.success(discoverApps()) } catch (e: Exception) { android.util.Log.e("Kadd", "App discovery failed", e); result.error("APP_LIST_ERROR", e.message ?: "Unable to discover apps", null) }
                "getAppDiscoveryDiagnostics" -> try { result.success(discoveryDiagnostics()) } catch (e: Exception) { android.util.Log.e("Kadd", "App discovery diagnostics failed", e); result.error("APP_DIAGNOSTICS_ERROR", e.message ?: "Unable to inspect installed apps", null) }
                "syncLockedPackages" -> {
                    val requested = call.argument<List<String>>("packages") ?: emptyList()
                    val packages = sanitizeLockedPackages(requested)
                    LockPrefs.setLockedPackages(this, packages)
                    if (packages.isEmpty()) stopService(Intent(this, LockForegroundService::class.java)) else LockForegroundService.ensureRunning(this)
                    result.success(null)
                }
                "clearAllLockState" -> { PrayerAlarmResetter.clear(this); LockPrefs.clearAllLockState(this); stopService(Intent(this, LockForegroundService::class.java)); result.success(null) }
                "grantTemporaryUnlock" -> {
                    val packageName = call.argument<String>("packageName")?.trim()
                    val minutes = call.argument<Int>("minutes")
                    when {
                        packageName.isNullOrEmpty() || minutes == null || minutes <= 0 || minutes > maxExerciseUnlockMinutes -> result.error("INVALID_UNLOCK", "packageName and minutes between 1 and $maxExerciseUnlockMinutes are required", null)
                        !LockPrefs.getLockedPackages(this).contains(packageName) -> result.error("APP_NOT_LOCKED", "The requested package is not currently configured as locked", null)
                        !isLaunchablePackage(packageName) -> result.error("APP_NOT_AVAILABLE", "The requested app is no longer available on this device", null)
                        LockPrefs.isAthanLockActive(this) -> result.error("PRAYER_LOCK_ACTIVE", "Exercise unlock is unavailable during the active prayer lock", null)
                        else -> { LockPrefs.grantUnlockUntil(this, packageName, minutes); result.success(null) }
                    }
                }
                "grantAthanUnlock" -> {
                    val requestedPrayer = call.argument<String>("prayer")?.trim()?.lowercase(Locale.US)
                    val activePrayer = LockPrefs.getActivePrayerName(this)?.lowercase(Locale.US)
                    if (requestedPrayer.isNullOrEmpty() || requestedPrayer !in supportedPrayerNames || activePrayer == null || requestedPrayer != activePrayer) result.success(false)
                    else { LockPrefs.grantAthanUnlockForCurrentWindow(this); result.success(true) }
                }
                "scheduleAthanLocks" -> {
                    @Suppress("UNCHECKED_CAST")
                    val prayers = call.argument<List<Map<String, Any>>>("prayers") ?: emptyList()
                    val enabled = (call.argument<List<String>>("enabledPrayerNames") ?: prayers.mapNotNull { it["name"] as? String }).map { it.trim().lowercase(Locale.US) }.filter { it in supportedPrayerNames }.distinct()
                    val safePrayers = prayers.filter { prayer -> val name = (prayer["name"] as? String)?.trim()?.lowercase(Locale.US); val epochMillis = (prayer["epochMillis"] as? Number)?.toLong(); name in supportedPrayerNames && epochMillis != null && epochMillis > 0L }
                    AthanAlarmScheduler.schedule(this, safePrayers, call.argument<Int>("delayMinutes") ?: 5, call.argument<String>("cityName"), enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canScheduleExactAlarms(): Boolean { if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true; return (getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms() }
    private fun sanitizeLockedPackages(requested: List<String>): List<String> = requested.asSequence().map { it.trim() }.filter { it.isNotEmpty() && it != applicationContext.packageName }.filter(::isLaunchablePackage).distinct().toList()
    private fun isLaunchablePackage(packageName: String): Boolean = try { packageName.isNotBlank() && packageManager.getLaunchIntentForPackage(packageName) != null } catch (_: Exception) { false }

    private fun discoverySnapshot(): Pair<List<Map<String, Any?>>, Map<String, Int>> {
        val byPackage = linkedMapOf<String, Map<String, Any?>>()
        val ownPackage = applicationContext.packageName
        var launcherCount = 0
        var installedCount = 0

        val launcherIntent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        try {
            val launcherActivities = packageManager.queryIntentActivities(launcherIntent, PackageManager.MATCH_ALL)
            launcherCount = launcherActivities.size
            launcherActivities.forEach { info ->
                val appInfo = info.activityInfo?.applicationInfo ?: return@forEach
                if (appInfo.packageName != ownPackage && isInstalled(appInfo)) addApp(byPackage, appInfo)
            }
        } catch (e: Exception) { android.util.Log.w("Kadd", "Launcher query failed", e) }

        try {
            @Suppress("DEPRECATION")
            val packages = packageManager.getInstalledPackages(PackageManager.GET_ACTIVITIES or PackageManager.MATCH_ALL)
            installedCount = packages.size
            packages.forEach { pkg ->
                val appInfo = pkg.applicationInfo ?: return@forEach
                if (appInfo.packageName == ownPackage || !isInstalled(appInfo)) return@forEach
                val hasLauncherActivity = pkg.activities.orEmpty().any { activity ->
                    activity.enabled && activity.exported && activity.intentFilters?.any { filter -> filter.hasAction(Intent.ACTION_MAIN) && filter.hasCategory(Intent.CATEGORY_LAUNCHER) } == true
                }
                if (hasLauncherActivity) addApp(byPackage, appInfo)
            }
        } catch (e: Exception) { android.util.Log.w("Kadd", "Installed-package activity query failed", e) }

        if (byPackage.isEmpty()) {
            try {
                @Suppress("DEPRECATION")
                val installed = packageManager.getInstalledApplications(PackageManager.MATCH_ALL)
                installedCount = maxOf(installedCount, installed.size)
                installed.forEach { appInfo -> if (appInfo.packageName != ownPackage && isInstalled(appInfo) && isLaunchablePackage(appInfo.packageName)) addApp(byPackage, appInfo) }
            } catch (e: Exception) { android.util.Log.w("Kadd", "Application fallback query failed", e) }
        }

        val apps = byPackage.values.sortedBy { (it["name"] as String).lowercase(Locale.getDefault()) }
        return Pair(apps, mapOf("launcherCount" to launcherCount, "installedCount" to installedCount, "launchableCount" to apps.size))
    }

    private fun isInstalled(appInfo: ApplicationInfo): Boolean = (appInfo.flags and ApplicationInfo.FLAG_INSTALLED) != 0
    private fun discoverApps(): List<Map<String, Any?>> = discoverySnapshot().first
    private fun discoveryDiagnostics(): Map<String, Any> { val snapshot = discoverySnapshot(); return mapOf("launcherCount" to (snapshot.second["launcherCount"] ?: 0), "installedCount" to (snapshot.second["installedCount"] ?: 0), "launchableCount" to (snapshot.second["launchableCount"] ?: 0), "ownPackage" to applicationContext.packageName, "queryAllPackagesDeclared" to true) }

    private fun addApp(destination: MutableMap<String, Map<String, Any?>>, appInfo: ApplicationInfo) {
        val packageName = appInfo.packageName
        if (destination.containsKey(packageName)) return
        val label = try { appInfo.loadLabel(packageManager)?.toString()?.trim().orEmpty() } catch (_: Exception) { "" }
        destination[packageName] = mapOf("name" to if (label.isEmpty()) packageName else label, "packageName" to packageName, "icon" to try { drawableToPng(appInfo.loadIcon(packageManager)) } catch (_: Exception) { null }, "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0))
    }

    private fun drawableToPng(drawable: android.graphics.drawable.Drawable): ByteArray? = try { val size = 96; val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888); val canvas = Canvas(bitmap); drawable.setBounds(0, 0, size, size); drawable.draw(canvas); ByteArrayOutputStream().use { output -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, output); bitmap.recycle(); output.toByteArray() } } catch (_: Exception) { null }
    private fun hasUsageAccess(): Boolean { val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager; return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED }
}
