package com.comptaflow.kadd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Removes an app from Kadd's native lock set as soon as Android fully uninstalls it. */
class PackageRemovedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) return
        val removedPackage = intent.data?.schemeSpecificPart?.trim().orEmpty()
        if (removedPackage.isEmpty()) return

        val locked = LockPrefs.getLockedPackages(context)
        if (removedPackage !in locked) return

        val remaining = locked.filterNot { it == removedPackage }
        LockPrefs.setLockedPackages(context, remaining)
        if (remaining.isNotEmpty()) {
            LockForegroundService.ensureRunning(context)
        }
    }
}
