package com.errorxperts.detoxo.engine

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Persistence for the short-video / reel awareness counter.
 *
 * Shares the same `detoxo_engine_prefs` SharedPreferences file as [ConfigStore]
 * so the AccessibilityService, [com.errorxperts.detoxo.channels.CommandHandler]
 * and the home-screen widget all read one source of truth. SRP: storage only —
 * the decision of WHEN to count lives in [ContentCounter].
 *
 * Counts are kept two ways: a per-day "today" bucket (reset on date rollover)
 * and an all-time "total". Each is split per package (JSON `{pkg: count}`),
 * mirroring [ConfigStore.recordBlock]/[ConfigStore.blockStats].
 */
class ContentCounterStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Master on/off for the counter feature. Defaults on (awareness by default). */
    var enabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    /** Whether the floating bubble overlay may be shown (gated separately). */
    var bubbleEnabled: Boolean
        get() = prefs.getBoolean(KEY_BUBBLE, true)
        set(value) = prefs.edit().putBoolean(KEY_BUBBLE, value).apply()

    /** Last bubble X position in px (−1 = unset → snaps to the default edge). */
    var bubbleX: Int
        get() = prefs.getInt(KEY_BUBBLE_X, -1)
        set(value) = prefs.edit().putInt(KEY_BUBBLE_X, value).apply()

    /** Last bubble Y position in px (−1 = unset → default offset from top). */
    var bubbleY: Int
        get() = prefs.getInt(KEY_BUBBLE_Y, -1)
        set(value) = prefs.edit().putInt(KEY_BUBBLE_Y, value).apply()

    /**
     * Bubble appearance as a JSON string (see Dart `BubbleStyle.toWire`). Empty =
     * unset → the native renderer falls back to its defaults. Pushed from Dart via
     * the `setCounterStyle` command.
     */
    var bubbleStyleJson: String
        get() = prefs.getString(KEY_BUBBLE_STYLE, "") ?: ""
        set(value) = prefs.edit().putString(KEY_BUBBLE_STYLE, value).apply()

    /** Home-widget appearance as a JSON string (see Dart `WidgetStyle.toWire`). */
    var widgetStyleJson: String
        get() = prefs.getString(KEY_WIDGET_STYLE, "") ?: ""
        set(value) = prefs.edit().putString(KEY_WIDGET_STYLE, value).apply()

    /**
     * Records one counted reel for [pkg]. Resets the today buckets first when the
     * stored day differs from [dateKey] (midnight rollover), then increments the
     * today + total totals and their per-app maps in a single edit.
     */
    fun recordCount(pkg: String, dateKey: String) {
        val storedDate = prefs.getString(KEY_DATE, "")
        val rollover = storedDate != dateKey

        val todayTotal = if (rollover) 0 else prefs.getInt(KEY_TODAY, 0)
        val perAppToday = if (rollover) JSONObject() else readMap(KEY_PER_APP_TODAY)
        val perAppTotal = readMap(KEY_PER_APP_TOTAL)

        perAppToday.put(pkg, perAppToday.optInt(pkg, 0) + 1)
        perAppTotal.put(pkg, perAppTotal.optInt(pkg, 0) + 1)

        prefs.edit()
            .putString(KEY_DATE, dateKey)
            .putInt(KEY_TODAY, todayTotal + 1)
            .putInt(KEY_TOTAL, prefs.getInt(KEY_TOTAL, 0) + 1)
            .putString(KEY_PER_APP_TODAY, perAppToday.toString())
            .putString(KEY_PER_APP_TOTAL, perAppTotal.toString())
            .apply()
    }

    /**
     * Current counter snapshot for [dateKey]. Applies a read-time rollover (when
     * the stored day is stale the today values read as 0 WITHOUT writing — the
     * next [recordCount] performs the durable reset), so a snapshot pulled just
     * after midnight is correct even before the day's first reel.
     */
    fun snapshot(dateKey: String): Map<String, Any?> {
        val storedDate = prefs.getString(KEY_DATE, "") ?: ""
        val fresh = storedDate == dateKey
        return mapOf(
            "enabled" to enabled,
            "bubbleEnabled" to bubbleEnabled,
            "today" to if (fresh) prefs.getInt(KEY_TODAY, 0) else 0,
            "total" to prefs.getInt(KEY_TOTAL, 0),
            "date" to dateKey,
            "perAppToday" to if (fresh) readMap(KEY_PER_APP_TODAY).toIntMap() else emptyMap(),
            "perAppTotal" to readMap(KEY_PER_APP_TOTAL).toIntMap(),
            // Persisted appearance (JSON strings); the Dart cubit hydrates from these.
            "bubbleStyle" to bubbleStyleJson,
            "widgetStyle" to widgetStyleJson,
        )
    }

    /** Today's running total for [dateKey] (0 after a rollover). Cheap path for the bubble. */
    fun todayCount(dateKey: String): Int =
        if (prefs.getString(KEY_DATE, "") == dateKey) prefs.getInt(KEY_TODAY, 0) else 0

    private fun readMap(key: String): JSONObject =
        try {
            JSONObject(prefs.getString(key, "{}") ?: "{}")
        } catch (_: Throwable) {
            JSONObject()
        }

    private fun JSONObject.toIntMap(): Map<String, Int> {
        val out = HashMap<String, Int>(length())
        val it = keys()
        while (it.hasNext()) {
            val k = it.next()
            out[k] = optInt(k, 0)
        }
        return out
    }

    companion object {
        private const val PREFS = "detoxo_engine_prefs"
        private const val KEY_ENABLED = "cc_enabled"
        private const val KEY_BUBBLE = "cc_bubble_enabled"
        private const val KEY_BUBBLE_X = "cc_bubble_x"
        private const val KEY_BUBBLE_Y = "cc_bubble_y"
        private const val KEY_DATE = "cc_date"
        private const val KEY_TODAY = "cc_today"
        private const val KEY_TOTAL = "cc_total"
        private const val KEY_PER_APP_TODAY = "cc_per_app_today"
        private const val KEY_PER_APP_TOTAL = "cc_per_app_total"
        private const val KEY_BUBBLE_STYLE = "cc_bubble_style"
        private const val KEY_WIDGET_STYLE = "cc_widget_style"
    }
}
