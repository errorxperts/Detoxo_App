package com.errorxperts.detoxo.channels

import android.app.Activity
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import com.errorxperts.detoxo.accessibility.DetoxoAccessibilityService
import com.errorxperts.detoxo.admin.DetoxoDeviceAdminReceiver
import com.errorxperts.detoxo.engine.ConfigStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles Dart -> native commands: config/settings push, permission queries and
 * launches, and direct block actions used for testing and PIN/overlay screens.
 */
class CommandHandler(
    private val context: Context,
    private var activity: Activity?,
) : MethodChannel.MethodCallHandler {

    private val store = ConfigStore(context)

    fun attachActivity(activity: Activity?) {
        this.activity = activity
    }

    private companion object {
        /** Conscious plan token (shares the legacy "CURIOUS" wire). */
        const val PLAN_CONSCIOUS = "CURIOUS"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushConfig" -> {
                store.platformsConfigJson = call.argument<String>("json")
                DetoxoAccessibilityService.instance?.reload()
                result.success(true)
            }
            "pushSettings" -> {
                call.argument<String>("activePlan")?.let { plan ->
                    // Freshly switching into Conscious starts a new, empty bank.
                    if (plan == PLAN_CONSCIOUS && store.activePlan != PLAN_CONSCIOUS) {
                        store.resetConsciousBank(System.currentTimeMillis())
                    }
                    store.activePlan = plan
                }
                call.argument<String>("defaultBlockMode")?.let { store.defaultBlockMode = it }
                call.argument<List<String>>("enabledPlatforms")?.let {
                    store.enabledPlatforms = it.toSet()
                }
                call.argument<Boolean>("vibration")?.let { store.vibrationEnabled = it }
                call.argument<Boolean>("masterEnabled")?.let { store.masterEnabled = it }
                call.argument<Number>("pauseUntil")?.let { store.pauseUntil = it.toLong() }
                call.argument<Number>("consciousEarnDivisor")?.let {
                    store.consciousEarnDivisor = it.toInt()
                }
                call.argument<Number>("consciousMaxBankMs")?.let {
                    store.consciousMaxBankMs = it.toLong()
                }
                DetoxoAccessibilityService.instance?.reload()
                result.success(true)
            }
            "consciousState" -> result.success(
                DetoxoAccessibilityService.instance?.consciousSnapshot() ?: mapOf(
                    "bankMs" to store.consciousBankMs,
                    "maxBankMs" to store.consciousMaxBankMs,
                    "watching" to false,
                    "blocked" to (store.activePlan == PLAN_CONSCIOUS && store.consciousBankMs <= 0L),
                    "active" to (store.activePlan == PLAN_CONSCIOUS),
                ),
            )
            "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
            "openAccessibilitySettings" ->
                result.success(launch(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)))
            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(context))
            "requestOverlayPermission" -> result.success(
                launch(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}"),
                    ),
                ),
            )
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccessSettings" ->
                result.success(launch(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)))
            "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBattery())
            "requestIgnoreBatteryOptimizations" -> result.success(
                launch(
                    Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:${context.packageName}"),
                    ),
                ),
            )
            "isDeviceAdminActive" -> result.success(isDeviceAdminActive())
            "requestDeviceAdmin" -> result.success(requestDeviceAdmin())
            "removeDeviceAdmin" -> {
                removeDeviceAdmin()
                result.success(true)
            }
            "performBack" -> {
                DetoxoAccessibilityService.instance?.performBackPublic()
                result.success(true)
            }
            "killApp" -> {
                val pkg = call.argument<String>("package")
                if (pkg != null) DetoxoAccessibilityService.instance?.killApp(pkg)
                result.success(true)
            }
            "lockScreen" -> {
                DetoxoAccessibilityService.instance?.lockScreen()
                result.success(true)
            }
            "blockStats" -> {
                val (today, total, date) = store.blockStats()
                result.success(mapOf("today" to today, "total" to total, "date" to date))
            }
            "deviceInfo" -> result.success(deviceInfo())
            else -> result.notImplemented()
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(
            context, DetoxoAccessibilityService::class.java,
        ).flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            false
        }
    }

    private fun isIgnoringBattery(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(ComponentName(context, DetoxoDeviceAdminReceiver::class.java))
    }

    private fun requestDeviceAdmin(): Boolean {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(
                DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                ComponentName(context, DetoxoDeviceAdminReceiver::class.java),
            )
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Enable to protect Detoxo from being uninstalled while active.",
            )
        }
        return launch(intent)
    }

    private fun removeDeviceAdmin() {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.removeActiveAdmin(ComponentName(context, DetoxoDeviceAdminReceiver::class.java))
        } catch (_: Throwable) {
        }
    }

    private fun deviceInfo(): Map<String, Any?> = mapOf(
        "brand" to Build.BRAND,
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "sdkInt" to Build.VERSION.SDK_INT,
    )

    private fun launch(intent: Intent): Boolean {
        return try {
            val host = activity
            if (host != null) {
                host.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }
}
