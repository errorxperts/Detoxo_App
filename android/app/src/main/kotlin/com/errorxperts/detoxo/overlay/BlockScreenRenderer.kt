package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.engine.UsageQuery
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.accessibility.AccessibilityNodeInfo
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.widget.WidgetBitmapRenderer
import com.errorxperts.detoxo.widget.blend
import org.json.JSONObject
import kotlin.math.floor
import kotlin.math.roundToInt

// ── Wire shapes (file-level so the JVM test never touches an Android initializer) ──

/**
 * What the wall says. Built natively at the four trigger sites and parsed from
 * the `showBlockScreen` channel arm; [sanitised] is applied on both paths.
 *
 * `plan` carries the wire token verbatim (`CURIOUS`) and only picks the
 * reason line ([WallCopy.reason]); the token itself never reaches the screen.
 * `todayCount` / `allowanceLeft` / `bankMs` use -1 for "not applicable" so a
 * line is skipped, never printed as 0.
 */
data class BlockScreenPayload(
    val referenceType: String,        // REEL | APP | WEBSITE
    val referenceId: String,          // platformId | package | host
    val displayName: String,          // "Instagram Reels" / app label / host
    val appLabel: String = "",        // the app under the wall ("Back to Instagram")
    val packageName: String = "",     // the app under the wall (EVO-027's opens count)
    val blockReason: String,          // PLAN | APP_BLOCK | WEB_RULE | ADULT | DAILY_LIMIT | SCHEDULE
    val plan: String = "",            // BLOCK_ALL | CURIOUS | ONE_REEL | "" — picks the reason line
    val allowance: Int = 1,           // the armed One Reel / Unblock count
    val todayCount: Int = -1,
    val allowanceLeft: Int = -1,
    val bankMs: Long = -1L,
    val opensToday: Int = -1,         // foreground transitions since midnight; filled late by the overlay
    val unlocksAtMs: Long = -1L,      // EVO-028: when the rule window covering this block closes
    val offersOpenApp: Boolean = true,
    val offersUnblock: Boolean = false,
) {
    /**
     * EVO-018: an adult-list hit is never named and never one tap from being
     * lifted. The plan only explains a block the plan made — app/web rules
     * fire during a Pause too, when the plan token would lie.
     */
    fun sanitised(): BlockScreenPayload {
        var p = this
        if (p.blockReason == REASON_ADULT) {
            p = p.copy(displayName = "", referenceId = "", offersUnblock = false)
        }
        if (p.blockReason != REASON_PLAN) p = p.copy(plan = "")
        return p
    }

    companion object {
        const val TYPE_REEL = "REEL"
        const val TYPE_APP = "APP"
        const val TYPE_WEBSITE = "WEBSITE"
        const val REASON_PLAN = "PLAN"
        const val REASON_APP_BLOCK = "APP_BLOCK"
        const val REASON_WEB_RULE = "WEB_RULE"
        const val REASON_ADULT = "ADULT"
        const val REASON_DAILY_LIMIT = "DAILY_LIMIT"
        const val REASON_SCHEDULE = "SCHEDULE"

        /** Null when the two fields nothing can default are missing. */
        fun fromMap(m: Map<*, *>?): BlockScreenPayload? {
            if (m == null) return null
            val type = m["referenceType"] as? String ?: return null
            val reason = m["blockReason"] as? String ?: return null
            return BlockScreenPayload(
                referenceType = type,
                referenceId = m["referenceId"] as? String ?: "",
                displayName = m["displayName"] as? String ?: "",
                appLabel = m["appLabel"] as? String ?: "",
                packageName = m["packageName"] as? String ?: "",
                blockReason = reason,
                plan = m["plan"] as? String ?: "",
                allowance = (m["allowance"] as? Number)?.toInt() ?: 1,
                todayCount = (m["todayCount"] as? Number)?.toInt() ?: -1,
                allowanceLeft = (m["allowanceLeft"] as? Number)?.toInt() ?: -1,
                bankMs = (m["bankMs"] as? Number)?.toLong() ?: -1L,
                opensToday = (m["opensToday"] as? Number)?.toInt() ?: -1,
                unlocksAtMs = (m["unlocksAtMs"] as? Number)?.toLong() ?: -1L,
                offersOpenApp = m["offersOpenApp"] as? Boolean ?: true,
                offersUnblock = m["offersUnblock"] as? Boolean ?: false,
            )
        }
    }
}

/**
 * Wall appearance parsed from the JSON persisted by the Dart `BlockScreenStyle`
 * (`block_screen_style` in `detoxo_engine_prefs`). `enabled` is the wall's own
 * switch: off → the trigger sites fall back to the toast + BACK/HOME they
 * always had. The look itself is not here: it follows the app theme
 * ([wallIsDark], `ContentCounterStore.brand`), so a map persisted before that
 * (with `theme`, `background`, `design`, `accentByUsage`) parses with those
 * keys ignored. Malformed JSON → defaults, never a crash.
 */
data class BlockScreenStyleSpec(
    val enabled: Boolean = true,
    val showCount: Boolean = true,
    val showOpens: Boolean = true,         // EVO-027: "Instagram opened 7 times today"
    val backDelaySec: Int = 5,             // EVO-025: 0 = the ghost exit unlocks at once
) {
    companion object {
        fun fromJson(json: String?): BlockScreenStyleSpec {
            if (json.isNullOrEmpty()) return BlockScreenStyleSpec()
            return try {
                val o = JSONObject(json)
                BlockScreenStyleSpec(
                    enabled = o.optBoolean("enabled", true),
                    showCount = o.optBoolean("showCount", true),
                    showOpens = o.optBoolean("showOpens", true),
                    backDelaySec = o.optInt("backDelaySec", 5).coerceIn(0, 60),
                )
            } catch (_: Throwable) {
                BlockScreenStyleSpec()
            }
        }
    }
}

/**
 * Wire token → the label the user knows. `CURIOUS` is the legacy wire for
 * Conscious and must never reach the screen; `ONE_REEL` is two user-facing
 * plans depending on the armed [allowance] (dashboard: "One Reel" for 1,
 * "Unblock" for 2+). Unknown / blank → "" (no label).
 */
internal fun planLabel(token: String, allowance: Int): String = when (token) {
    "CURIOUS" -> "Conscious"
    "ONE_REEL" -> if (allowance <= 1) "One Reel" else "Unblock"
    "BLOCK_ALL" -> "Block All"
    "PAUSED" -> "Paused"
    else -> ""
}

/** Navy — the primary button's text on a light fill; white takes the dark ones. */
private const val ON_ACCENT = 0xFF0B1326.toInt()

/**
 * Text colour for a button filled with [fill]: navy where it reads best, white
 * otherwise. The theme's deep primaries (Magenta, Rose, Indigo) drop navy
 * under 3.6:1 — white is above 5:1 there. Pure; pinned by the JVM test.
 */
internal fun onColorFor(fill: Int): Int =
    if (contrastRatio(ON_ACCENT, fill) >= contrastRatio(0xFFFFFFFF.toInt(), fill)) ON_ACCENT else 0xFFFFFFFF.toInt()

/**
 * [fill], darkened toward navy in 3 % steps until [onColorFor] reads at
 * ≥ 4.5:1 — the primary button's fill now that the accent is the app theme's
 * primary. Only Sky (`#2F6BFF`, white 4.499:1) needs it; every other theme
 * primary and the fallback brand come back unchanged. Pure; the Dart
 * `legibleFill` mirrors it.
 */
internal fun legibleFill(fill: Int): Int {
    var f = fill
    var i = 0
    while (i++ < 40 && contrastRatio(onColorFor(f), f) < 4.5) f = blend(f, ON_ACCENT, 0.97f)
    return f
}

/**
 * [color], blended toward [ink] in 3 % steps until it reads at ≥ 4.5:1 on
 * [ground] — the accent as text or glyph on the wall: Home's icon and the ghost
 * labels on the bare ground, a chip's label on its own fill ([outlinedFill]).
 * On the bare light ground it deepens Sky, Teal and Rose a little; on the dark
 * one it lifts only the never-pushed fallback navy. A colour that already
 * reads comes back unchanged. Pure; the Dart `legibleOn` mirrors it.
 */
internal fun legibleOn(color: Int, ground: Int, ink: Int): Int {
    var c = color
    var i = 0
    while (i++ < 40 && contrastRatio(c, ground) < 4.5) c = blend(c, ink, 0.97f)
    return c
}

/**
 * The wall's brightness: the APP's theme choice ([appTheme], pushed as
 * `themeMode`) — Face Down when Detoxo is light, Spotlight when it is dark.
 * Only an app on "Match system", or one that never pushed, falls through to
 * the device's night mode. The Flutter preview reads the app theme's
 * brightness, so the two agree. Pure.
 */
internal fun wallIsDark(appTheme: String, systemDark: Boolean): Boolean = when (appTheme) {
    "LIGHT" -> false
    "DARK" -> true
    else -> systemDark
}

// ── Renderer ─────────────────────────────────────────────────────────────────

/**
 * Builds the wall: the Canvas-drawn [QuoteWallView] (Face Down on a light
 * wall, Spotlight on a dark one) with real buttons over its foot — the app's
 * own, drawn natively by [WallButtons] — so TalkBack gets one focusable target
 * per action. Colours come from [wallPalette] and the app theme's primary,
 * which the Flutter preview mirrors.
 *
 * ponytail: content renders on a Canvas, so the wall cannot reuse the Flutter
 * design system. Upgrade path = a Flutter-rendered wall, which costs a second
 * engine and is blocked by the single-process invariant.
 */
object BlockScreenRenderer {

    const val ACTION_GO_HOME = "GO_HOME"
    const val ACTION_OPEN_APP = "OPEN_APP"
    const val ACTION_DISMISS = "DISMISS"
    const val ACTION_UNBLOCK = "UNBLOCK"

    /**
     * EVO-050: `"UNBLOCK_15"` — the chip the user actually picked, so the
     * duration never has to survive a process hop. [ACTION_UNBLOCK] itself now
     * only reveals the row (and is still posted, so analytics keeps counting
     * the intent separately from the choice).
     */
    const val ACTION_UNBLOCK_PREFIX = "UNBLOCK_"

    /** Mirrors Dart's `unblockDurationMinutes` — one duration vocabulary. */
    val UNBLOCK_MINUTES = intArrayOf(5, 15, 30, 60)

    /** View tags the overlay uses to reach the two views it updates after build. */
    const val TAG_WALL = "wall"
    const val TAG_BACK = "back"

    /**
     * [animateIn] is a newly raised wall: it fades in (220 ms) while its
     * buttons rise 16 dp (280 ms), and its quote fades up. An in-place rebuild
     * (a newer payload for the same block, a style edit) passes false, so
     * nothing flashes.
     */
    internal fun build(
        context: Context,
        payload: BlockScreenPayload,
        spec: BlockScreenStyleSpec,
        appTheme: String,
        quote: Quote,
        animateIn: Boolean,
        onAction: (String) -> Unit,
    ): View {
        val dark = wallIsDark(appTheme, WidgetBitmapRenderer.isSystemDark(context))
        // The app theme's primary for this brightness (Dart pushes both as brandLight / brandDark).
        val accent = ContentCounterStore(context).brand(dark)
        val palette = wallPalette(dark, accent)
        val copy = WallCopy.from(context, payload, spec)

        // Nothing in the stack clips, so the primary's shadow can fall outside its 48 dp box.
        val root = FrameLayout(context).apply {
            clipChildren = false
            clipToPadding = false
        }
        val wall = QuoteWallView(context, copy, quote, palette, accent, dark, fadeIn = animateIn)
        wall.tag = TAG_WALL
        root.addView(
            wall,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        val actions = buildActions(context, payload, WallButtons(context, palette, accent, dark), onAction)
        root.addView(
            actions,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )
        // The text block must clear the button column at any font scale: the
        // column's laid-out height is what the backdrop reserves.
        actions.addOnLayoutChangeListener { v, _, _, _, _, _, _, _, _ -> wall.reservedBottom = v.height }
        // The window draws under the system bars (setFitInsetsTypes(0)), so the
        // button column pads itself clear of the navigation bar / gesture area.
        val side = dp(context, 24f)
        actions.setPadding(side, 0, side, dp(context, 20f))
        root.setOnApplyWindowInsetsListener { _, insets ->
            val bottom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(WindowInsets.Type.systemBars()).bottom
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetBottom
            }
            actions.setPadding(side, 0, side, bottom + dp(context, 20f))
            insets
        }
        if (animateIn) {
            // "Remove animations" scales both to 0 ms: the wall simply appears.
            // ponytail: the fade composites the whole wall through one offscreen
            // layer per frame for its 220 ms. Upgrade path = fade the window's
            // own alpha if a low-end trace ever shows it.
            val ease = DecelerateInterpolator()
            root.alpha = 0f
            root.animate().alpha(1f).setDuration(220L).setInterpolator(ease)
            actions.translationY = dp(context, 16f).toFloat()
            actions.animate().translationY(0f).setDuration(280L).setInterpolator(ease)
        }
        return root
    }

    /**
     * The exits, top to bottom: a row of Home (an icon) and Open Detoxo (the
     * primary), then "Back to {app}" — the ghost exit the overlay counts down
     * and relabels — then "Allow for a while" when offered. An app wall has no
     * way back into the app, so no ghost exit there. The text exits sit 6 dp
     * under the row and flush with each other: each 48 dp view carries its own
     * air.
     */
    private fun buildActions(
        context: Context,
        p: BlockScreenPayload,
        kit: WallButtons,
        onAction: (String) -> Unit,
    ): LinearLayout {
        val res = context.resources
        val h = dp(context, 48f)
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            clipChildren = false
            clipToPadding = false
        }
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            clipChildren = false
            clipToPadding = false
        }
        row.addView(kit.home { onAction(ACTION_GO_HOME) }, LinearLayout.LayoutParams(h, h))
        if (p.offersOpenApp) {
            row.addView(
                kit.primary(res.getString(R.string.wall_open_app)) { onAction(ACTION_OPEN_APP) },
                LinearLayout.LayoutParams(0, h, 1f).apply { marginStart = dp(context, 10f) },
            )
        }
        column.addView(row, slot(context, 0))
        var top = dp(context, 6f)
        if (p.referenceType != BlockScreenPayload.TYPE_APP) {
            // Detoxo blocks reels, not apps: the way back into the app's other
            // screens (DMs, the previous tab) is a first-class exit. Tagged for
            // the overlay, which counts it down (EVO-025) and relabels it (EVO-026).
            val label = p.appLabel.ifBlank { p.displayName }.ifBlank { res.getString(R.string.wall_this_app) }
            val back = kit.ghost(res.getString(R.string.wall_back_to, label)) { onAction(ACTION_DISMISS) }
            back.tag = TAG_BACK
            column.addView(back, slot(context, top))
            top = 0
        }
        if (p.offersUnblock) addUnblock(context, column, kit, top, onAction)
        return column
    }

    /**
     * EVO-050: "Allow for a while", asked HERE, not after a launch into
     * Detoxo. Pressing a button on a wall that is blocking Instagram used to
     * take the user out of Instagram and into another app — the outcome the
     * wall was already trying to produce — and every defect on that hand-off
     * path (a key with no TTL, a tap eaten by the PIN screen, a sheet with no
     * Navigator) existed only because the question was asked somewhere other
     * than where it was raised.
     */
    private fun addUnblock(
        context: Context,
        column: LinearLayout,
        kit: WallButtons,
        top: Int,
        onAction: (String) -> Unit,
    ) {
        val res = context.resources
        val chips = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            visibility = View.GONE
        }
        // A double tap's second half lands on a chip still fading in under the
        // finger: ignore taps for a double-tap timeout, or the wall would grant
        // a duration nobody picked.
        var shownAt = 0L
        for (m in UNBLOCK_MINUTES) {
            chips.addView(
                kit.chip(res.getString(R.string.wall_unblock_minutes, m)) {
                    if (SystemClock.uptimeMillis() - shownAt >= ViewConfiguration.getDoubleTapTimeout()) {
                        onAction("$ACTION_UNBLOCK_PREFIX$m")
                    }
                },
                LinearLayout.LayoutParams(0, dp(context, 48f), 1f).apply {
                    if (chips.childCount > 0) marginStart = dp(context, 8f)
                },
            )
        }
        // The chips take the trigger's slot (same height, same margin) rather
        // than pushing the exits around, which would move a button under a
        // finger already travelling towards it. `lateinit` so the trigger can
        // hide itself.
        lateinit var trigger: View
        trigger = kit.ghost(res.getString(R.string.wall_unblock)) {
            shownAt = SystemClock.uptimeMillis()
            fitChips(chips, column.width - column.paddingLeft - column.paddingRight, dp(context, 8f))
            trigger.visibility = View.GONE
            chips.alpha = 0f
            chips.visibility = View.VISIBLE
            chips.animate().alpha(1f).setDuration(200L)
            // TalkBack's focus went with the trigger: hand it to the first chip.
            chips.post {
                chips.getChildAt(0)?.performAccessibilityAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS, null)
            }
            onAction(ACTION_UNBLOCK)
        }
        column.addView(trigger, slot(context, top))
        column.addView(chips, slot(context, top))
    }

    /**
     * A big font scale can overflow a quarter-width chip ("60 min" needs 82 dp
     * at 2× where a 360 dp phone gives its label 64): shrink all four alike so
     * every label stays whole. [inner] is the row's width, [gap] the space
     * between chips.
     */
    private fun fitChips(chips: LinearLayout, inner: Int, gap: Int) {
        val n = chips.childCount
        if (n == 0 || inner <= 0) return
        val each = (inner - gap * (n - 1)) / n
        var scale = 1f
        for (i in 0 until n) {
            val b = chips.getChildAt(i) as TextView
            val want = b.paint.measureText(b.text.toString())
            val room = each - b.paddingLeft - b.paddingRight
            if (want > room) scale = minOf(scale, room / want)
        }
        if (scale < 1f) {
            for (i in 0 until n) {
                val b = chips.getChildAt(i) as TextView
                b.setTextSize(TypedValue.COMPLEX_UNIT_PX, floor(b.textSize * scale))
            }
        }
    }

    /** A full-width 48 dp slot in the column, [top] px under what it already holds. */
    private fun slot(context: Context, top: Int) =
        LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(context, 48f)).apply { topMargin = top }

    private fun dp(context: Context, v: Float): Int =
        (v * context.resources.displayMetrics.density).roundToInt()
}

/**
 * The wall's resolved strings — computed once, drawn by [QuoteWallView]: the
 * reason and the stats as its meta line, [headline] only in the TalkBack
 * summary.
 */
internal data class WallCopy(
    val headline: String,
    val reason: String,
    val stats: List<String>,
    /** Who the sub-line names ("Instagram can wait"). */
    val name: String,
) {
    companion object {
        fun from(context: Context, p: BlockScreenPayload, spec: BlockScreenStyleSpec): WallCopy {
            val res = context.resources
            val adult = p.blockReason == BlockScreenPayload.REASON_ADULT
            val name = p.displayName.ifBlank { res.getString(R.string.wall_this_app) }
            val headline = if (adult) {
                res.getString(R.string.toast_blocked_adult)
            } else {
                res.getString(R.string.toast_blocked, name)
            }
            val reason = when (p.blockReason) {
                BlockScreenPayload.REASON_PLAN -> when (p.plan) {
                    "CURIOUS" -> res.getString(R.string.wall_reason_conscious)
                    "ONE_REEL" -> if (p.allowance <= 1) {
                        res.getString(R.string.wall_reason_one_reel)
                    } else {
                        res.getString(R.string.wall_reason_unblock, p.allowance)
                    }
                    else -> res.getString(R.string.wall_reason_block_all)
                }
                BlockScreenPayload.REASON_APP_BLOCK -> res.getString(R.string.wall_reason_app_block)
                BlockScreenPayload.REASON_WEB_RULE -> res.getString(R.string.wall_reason_web_rule)
                BlockScreenPayload.REASON_ADULT -> res.getString(R.string.wall_reason_adult)
                // EVO-028: a rule wall names its own release time when it has
                // one, so the wall is a decision ("come back after work") and
                // not a dead end. `unlocksAtMs` is -1 / 0 when there is nothing
                // to name — the daily reel meter has no edge.
                BlockScreenPayload.REASON_DAILY_LIMIT -> if (p.unlocksAtMs > 0L) {
                    res.getString(R.string.wall_reason_daily_limit_until, clockAt(context, p.unlocksAtMs))
                } else {
                    res.getString(R.string.wall_reason_daily_limit)
                }
                BlockScreenPayload.REASON_SCHEDULE -> if (p.unlocksAtMs > 0L) {
                    res.getString(R.string.wall_reason_schedule_until, clockAt(context, p.unlocksAtMs))
                } else {
                    res.getString(R.string.wall_reason_schedule)
                }
                else -> ""
            }
            val stats = ArrayList<String>(2)
            if (spec.showCount && p.todayCount >= 0 && p.referenceType == BlockScreenPayload.TYPE_REEL) {
                stats += res.getQuantityString(R.plurals.wall_count_today, p.todayCount, p.todayCount)
            }
            if (p.bankMs >= 0L) {
                stats += res.getString(R.string.wall_bank, mmss(p.bankMs))
            } else if (p.allowanceLeft >= 0) {
                stats += res.getQuantityString(R.plurals.wall_allowance_left, p.allowanceLeft, p.allowanceLeft)
            }
            // A payload that already carries the opens count (the editor's
            // preview) renders it here; a live wall gets it late via
            // QuoteWallView.extraStats once the usage queries return (EVO-027, EVO-034).
            if (spec.showOpens && p.opensToday >= 0 && p.appLabel.isNotBlank()) {
                stats += opensLine(context, p.appLabel, p.opensToday)
            }
            // The app for reel and app walls, the host for a website — and the
            // browser for an adult hit, which is never named.
            val subject = when {
                adult -> p.appLabel
                p.referenceType == BlockScreenPayload.TYPE_WEBSITE -> p.displayName
                else -> p.appLabel.ifBlank { p.displayName }
            }.ifBlank { res.getString(R.string.wall_this_app) }
            return WallCopy(
                headline = headline,
                reason = reason,
                stats = stats,
                name = subject,
            )
        }

        /** "1h 10m today in Instagram" (EVO-034) — what the reach cost. */
        fun timeTodayLine(context: Context, appLabel: String, ms: Long): String =
            context.resources.getString(
                R.string.wall_time_today, UsageQuery.formatHm(ms), appLabel,
            )

        /** "Instagram opened 7 times today". */
        fun opensLine(context: Context, appLabel: String, opens: Int): String =
            context.resources.getQuantityString(R.plurals.wall_opens_today, opens, appLabel, opens)

        private fun mmss(ms: Long): String {
            val total = (ms / 1000L).coerceAtLeast(0L)
            return "%d:%02d".format(total / 60L, total % 60L)
        }

        /**
         * Wall clock for [ms] in the DEVICE's 12/24-hour setting — the same
         * promise the Dart side keeps (`core/utils/clock_format.dart`), so a
         * rule picked as "5:30 PM" is never read back as "17:30".
         */
        private fun clockAt(context: Context, ms: Long): String =
            android.text.format.DateFormat.getTimeFormat(context).format(java.util.Date(ms))
    }
}
