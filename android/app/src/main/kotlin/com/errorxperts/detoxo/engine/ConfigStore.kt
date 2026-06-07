package com.errorxperts.detoxo.engine

import android.content.Context
import android.content.SharedPreferences

/**
 * Single source of truth for the native engine's configuration and settings.
 *
 * Dart pushes the platforms-config JSON and the user's settings here; the
 * AccessibilityService reads them. Backed by ordinary SharedPreferences (the
 * service runs in the main process, so no multi-process mode is required).
 */
class ConfigStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var platformsConfigJson: String?
        get() = prefs.getString(KEY_CONFIG, null)
        set(value) = prefs.edit().putString(KEY_CONFIG, value).apply()

    var activePlan: String
        get() = prefs.getString(KEY_PLAN, "BLOCK_ALL") ?: "BLOCK_ALL"
        set(value) = prefs.edit().putString(KEY_PLAN, value).apply()

    var defaultBlockMode: String
        get() = prefs.getString(KEY_BLOCK_MODE, "PRESS_BACK") ?: "PRESS_BACK"
        set(value) = prefs.edit().putString(KEY_BLOCK_MODE, value).apply()

    /** Set of enabled platformIds (e.g. "ig_reel", "yt_shorts"). */
    var enabledPlatforms: Set<String>
        get() = prefs.getStringSet(KEY_ENABLED, emptySet()) ?: emptySet()
        set(value) = prefs.edit().putStringSet(KEY_ENABLED, value).apply()

    var vibrationEnabled: Boolean
        get() = prefs.getBoolean(KEY_VIBRATION, true)
        set(value) = prefs.edit().putBoolean(KEY_VIBRATION, value).apply()

    var masterEnabled: Boolean
        get() = prefs.getBoolean(KEY_MASTER, true)
        set(value) = prefs.edit().putBoolean(KEY_MASTER, value).apply()

    /** Epoch millis until which blocking is paused (0 = not paused). */
    var pauseUntil: Long
        get() = prefs.getLong(KEY_PAUSE_UNTIL, 0L)
        set(value) = prefs.edit().putLong(KEY_PAUSE_UNTIL, value).apply()

    fun recordBlock(dateKey: String) {
        val storedDate = prefs.getString(KEY_BLOCK_DATE, "")
        val todayCount = if (storedDate == dateKey) prefs.getInt(KEY_BLOCK_TODAY, 0) else 0
        prefs.edit()
            .putString(KEY_BLOCK_DATE, dateKey)
            .putInt(KEY_BLOCK_TODAY, todayCount + 1)
            .putInt(KEY_BLOCK_TOTAL, prefs.getInt(KEY_BLOCK_TOTAL, 0) + 1)
            .apply()
    }

    fun blockStats(): Triple<Int, Int, String> = Triple(
        prefs.getInt(KEY_BLOCK_TODAY, 0),
        prefs.getInt(KEY_BLOCK_TOTAL, 0),
        prefs.getString(KEY_BLOCK_DATE, "") ?: "",
    )

    companion object {
        private const val PREFS = "detoxo_engine_prefs"
        private const val KEY_CONFIG = "platforms_config_json"
        private const val KEY_PLAN = "active_plan"
        private const val KEY_BLOCK_MODE = "default_block_mode"
        private const val KEY_ENABLED = "enabled_platforms"
        private const val KEY_VIBRATION = "vibration_enabled"
        private const val KEY_MASTER = "master_enabled"
        private const val KEY_PAUSE_UNTIL = "pause_until"
        private const val KEY_BLOCK_DATE = "block_date"
        private const val KEY_BLOCK_TODAY = "block_today"
        private const val KEY_BLOCK_TOTAL = "block_total"
    }
}
