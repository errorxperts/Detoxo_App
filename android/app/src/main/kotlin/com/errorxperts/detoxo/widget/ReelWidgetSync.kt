package com.errorxperts.detoxo.widget

import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import android.text.format.DateFormat
import com.errorxperts.detoxo.accessibility.DetoxoAccessibilityService
import com.errorxperts.detoxo.engine.AccessibilityCheck
import com.errorxperts.detoxo.engine.ConfigStore
import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.engine.DateKeys
import com.errorxperts.detoxo.engine.RuleEngine

/**
 * The one writer of the home-widget payload (IM-01): builds it from the
 * counter's store, writes `widget_payload`, and redraws the pinned widgets
 * only when what they show changed (IM-03). Every face and the in-app
 * preview read what this wrote; nothing else computes the tier.
 */
object ReelWidgetSync {

    /**
     * Why a push happened (docs/code_docs/17-content-counter.md §5.2). HEARTBEAT
     * and PLAN may reuse the stored payload instead of building one.
     */
    enum class Reason { COUNT, BACKGROUND, MIDNIGHT, SETTINGS, REFRESH, HEARTBEAT, PLAN }

    /** Pushes on the widget worker; [onDone] runs there afterwards, whatever happened (a job's `jobFinished`). */
    fun push(ctx: Context, reason: Reason, onDone: () -> Unit = {}) {
        val app = ctx.applicationContext
        HomeWidgets.run {
            try {
                pushNow(app, reason)
            } finally {
                onDone()
            }
        }
    }

    /**
     * `pushRules`: mirror the snapshot's reel limits (a value that is not a
     * JSON array keeps the old mirror), then push SETTINGS when the soonest
     * limit now differs from the one the widget shows.
     */
    fun onRules(ctx: Context, rulesJson: String) {
        val app = ctx.applicationContext
        HomeWidgets.run {
            val store = ContentCounterStore(app)
            store.setReelLimits(rulesJson)
            val minutes = limitMinutes(store.reelLimits(), System.currentTimeMillis())
            if (minutes != stored(app)?.limitMinutes) pushNow(app, Reason.SETTINGS)
        }
    }

    /**
     * A fresh payload, not written. [demo] true / false forces the demo /
     * the live day; null shows the demo until the first reel is ever counted.
     *
     * ponytail: reads the store, not the live counter, so the ≤ 5 s of usage
     * the counter has not flushed yet is left out (a COUNT push carries it;
     * the faces show whole minutes). Reading the counter itself would race
     * its main-thread state.
     */
    fun build(ctx: Context, demo: Boolean? = false): WidgetPayload {
        val app = ctx.applicationContext
        val now = System.currentTimeMillis()
        return compose(
            ContentCounterStore(app).widgetSource(DateKeys.today(now)),
            now,
            Settings.Global.getFloat(app.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f,
            AccessibilityCheck.isEnabled(app),
            demo,
        )
    }

    /** What the widgets draw: the stored payload, or a freshly built and written one before the first push. */
    fun current(ctx: Context): WidgetPayload {
        val app = ctx.applicationContext
        return stored(app) ?: build(app).also { write(app, it) }
    }

    /**
     * The Plan widget's source (EVO-073): the engine's plan as stored right
     * now, never a payload key. Any thread (SharedPreferences reads).
     */
    fun plan(ctx: Context): PlanState {
        val store = ConfigStore(ctx.applicationContext)
        return PlanState(
            plan = store.activePlan,
            pauseUntil = store.pauseUntil,
            reelAllowance = store.reelAllowance,
            reelsConsumed = store.reelsConsumed,
            blockingOn = store.masterEnabled,
            serviceOn = DetoxoAccessibilityService.isRunning(),
        )
    }

    /**
     * The payload of [source] at [nowMs] (IM-02), and the only place the
     * tier is computed (IM-01). A new day's [source] reads as zeros (the
     * store rolls the day over at read time), so at midnight this is the
     * new day's Empty with the limit, theme and flags kept (IM-04). Pure.
     */
    internal fun compose(
        source: ContentCounterStore.WidgetSource,
        nowMs: Long,
        reduceMotion: Boolean,
        accessibilityOn: Boolean,
        demo: Boolean?,
    ): WidgetPayload {
        val limit = limitMinutes(source.reelLimits, nowMs)
        if (demo ?: (source.total == 0)) return WidgetPayload.demo(limit, source.theme, reduceMotion, nowMs)
        return WidgetPayload(
            reelCount = source.today,
            watchSeconds = (source.timeTodayMs / 1000L).toInt(),
            reelTier = WidgetPayload.tierOf(source.today),
            hourlySeconds = source.hourlySeconds,
            limitMinutes = limit,
            theme = source.theme,
            reduceMotion = reduceMotion,
            updatedAt = nowMs,
            trackingEnabled = tracking(source.enabled, accessibilityOn),
        )
    }

    /**
     * The soonest reel limit in force at [nowMs] in whole minutes, rounded
     * down and capped at a day, like the payload's parse; 0 = none. Clamped
     * as a Long, so a huge limit never wraps the Int.
     */
    internal fun limitMinutes(entries: List<RuleEngine.Entry>, nowMs: Long): Int =
        (RuleEngine.soonestReelLimitMs(entries, nowMs) / MINUTE_MS)
            .coerceIn(0L, WidgetTokens.MAX_LIMIT_MINUTES.toLong())
            .toInt()

    /** The tracking flag: the counter on AND the accessibility service enabled. */
    private fun tracking(counterOn: Boolean, accessibilityOn: Boolean): Boolean = counterOn && accessibilityOn

    /**
     * Worker only: build (or reuse), write, then redraw if the visible frame
     * changed. With no widget pinned it only writes the payload ([current]
     * reads it): no midnight job, no key, no render.
     */
    private fun pushNow(app: Context, reason: Reason) {
        val now = System.currentTimeMillis()
        val payload = when (reason) {
            // With the tracker connected the data is live, so a fresh build
            // keeps `updated_at` current. Without it nothing can refresh the
            // data: the stored payload ages into the Stale state.
            // ponytail: Stale shows 60–75 min after the last refresh (the
            // watchdog's 15 min cadence). The tracking flag is re-read even
            // then: a service the OS turned off while the process was dead
            // never ran onUnbind, and "Turn on tracking" outranks Stale.
            Reason.HEARTBEAT -> if (DetoxoAccessibilityService.isRunning()) {
                build(app)
            } else {
                stored(app)?.copy(
                    trackingEnabled = tracking(ContentCounterStore(app).enabled, AccessibilityCheck.isEnabled(app)),
                ) ?: build(app)
            }
            // EVO-073: the plan changed, not the reel data — keep `updated_at`, so Stale stays honest.
            Reason.PLAN -> stored(app) ?: build(app)
            // MIDNIGHT too: the store rolls the day over at read time, so a
            // build is the new day's Empty only when the day really changed
            // (a clock set back keeps today), with the limit and flags re-read.
            else -> build(app)
        }
        write(app, payload)
        val key = WidgetPayload.visibleKey(
            payload,
            now,
            HomeWidgets.zoneOffsetMin(now),
            DateFormat.is24HourFormat(app),
            WidgetBitmapRenderer.isSystemDark(app),
            updatedZoneOffsetMin = HomeWidgets.zoneOffsetMin(payload.updatedAt),
            plan = plan(app),
        )
        val prefs = prefs(app)
        // An unchanged frame costs no AppWidgetManager call, pinned or not.
        val rendered = prefs.getString(KEY_RENDERED, null)
        if (isDrawn(rendered, key)) return
        val pinned = HomeWidgets.pinned(app)
        if (pinned.isEmpty()) {
            // Nothing to draw or to turn over at midnight. A widget pinned
            // later draws this payload in onUpdate, which the marker matches.
            prefs.edit().putString(KEY_RENDERED, NONE_PINNED + key).apply()
            return
        }
        // EVO-073: only a Plan instance shows the plan, so with none pinned a
        // change in the plan alone redraws nothing; the key is still recorded.
        // ponytail: that costs one pinned() binder call per plan change (≈ 1/min
        // in a Pause); keep a per-family key if a profile shows it.
        if (planOnlyChange(rendered, key, planPinned = pinned.any { it.first == WidgetFamily.PLAN })) {
            prefs.edit().putString(KEY_RENDERED, key).apply()
            return
        }
        MidnightJobService.schedule(app)
        // Only once every instance drew: a failed render retries on the next push.
        if (HomeWidgets.renderAll(app, pinned, payload)) prefs.edit().putString(KEY_RENDERED, key).apply()
    }

    /**
     * Whether the frame [key] is already on screen per [rendered], the
     * stored `widget_rendered_key`: drawn on every pinned instance, or
     * written with nothing pinned (so a later pin's onUpdate drew it). Pure.
     */
    internal fun isDrawn(rendered: String?, key: String): Boolean =
        rendered == key || rendered == NONE_PINNED + key

    /**
     * Whether [key] differs from [rendered], the stored `widget_rendered_key`,
     * in the Plan strings alone: the visible key's last field
     * ([WidgetModel.planKey]). Only a pinned Plan instance shows those. Pure.
     */
    internal fun onlyPlanDiffers(rendered: String?, key: String): Boolean =
        rendered != null && rendered.substringBeforeLast('|') == key.substringBeforeLast('|')

    /**
     * Whether [key] can be recorded without drawing: only the Plan strings
     * changed and no Plan instance is pinned to show them ([planPinned]).
     * A pinned Plan widget always redraws on a plan change. Pure.
     */
    internal fun planOnlyChange(rendered: String?, key: String, planPinned: Boolean): Boolean =
        !planPinned && onlyPlanDiffers(rendered, key)

    /** The written payload; null before the first write. */
    private fun stored(app: Context): WidgetPayload? =
        prefs(app).getString(KEY_PAYLOAD, null)?.let(WidgetPayload::parse)

    private fun write(app: Context, payload: WidgetPayload) {
        prefs(app).edit().putString(KEY_PAYLOAD, payload.toJson()).apply()
    }

    /** `detoxo_engine_prefs`, shared with the counter's store — one file for everything the widgets read. */
    internal fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private const val PREFS = "detoxo_engine_prefs"
    private const val KEY_PAYLOAD = "widget_payload"
    private const val KEY_RENDERED = "widget_rendered_key"
    /** Prefixes the key written while nothing is pinned. */
    internal const val NONE_PINNED = "none|"
    private const val MINUTE_MS = 60_000L
}
