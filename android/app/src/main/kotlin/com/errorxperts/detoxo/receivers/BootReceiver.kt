package com.errorxperts.detoxo.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Logs boot / package-replaced so the user can be nudged to re-enable the
 * service if needed. An AccessibilityService is re-bound by the OS automatically
 * once it has been enabled, so no manual restart is required here.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.i("DetoxoBoot", "received ${intent?.action}")
    }
}
