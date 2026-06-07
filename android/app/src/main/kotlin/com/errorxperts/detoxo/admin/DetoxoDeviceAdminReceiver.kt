package com.errorxperts.detoxo.admin

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Optional uninstall protection. Enabling this admin lets [lockNow] work and
 *  prevents removal of the app while active. */
class DetoxoDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        Log.i("DetoxoAdmin", "device admin enabled")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Log.i("DetoxoAdmin", "device admin disabled")
    }
}
