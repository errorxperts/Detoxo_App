package com.errorxperts.detoxo.widget

import com.errorxperts.detoxo.channels.CommandHandler
import com.errorxperts.detoxo.engine.UsageQuery
import com.errorxperts.detoxo.overlay.planLabel
import kotlin.math.abs
import kotlin.math.ceil

/**
 * The seven widget families (DS-10): six about today's reels, and PLAN (EVO-073) about the blocking plan.
 * [wire] is the token on the channel, the tap intent and analytics; launcher names are
 * `res/values/strings.xml` `widget_label_*`.
 */
enum class WidgetFamily {
    COUNT,
    NEXT_COLOUR,
    TIME_LIMIT,
    RHYTHM,
    BONSAI,
    BENTO,
    PLAN,
    ;

    val wire: String get() = name

    companion object {
        fun fromWire(wire: String?): WidgetFamily? = entries.firstOrNull { it.wire == wire }
    }
}

/** The three size classes (DS-04) and their design boxes, in design units. */
enum class WidgetSize(val designWidth: Float, val designHeight: Float) {
    SMALL(WidgetTokens.WIDGET_S_W, WidgetTokens.WIDGET_S_H),
    MEDIUM(WidgetTokens.WIDGET_M_W, WidgetTokens.WIDGET_M_H),
    LARGE(WidgetTokens.WIDGET_L_W, WidgetTokens.WIDGET_L_H),
    ;

    val wire: String get() = name

    companion object {
        fun fromWire(wire: String?): WidgetSize? = entries.firstOrNull { it.wire == wire }

        /**
         * The class of a [wDp] × [hDp] instance on a screen whose short side is
         * [screenShortDp]: wide (w ≥ 1.15·h) is MEDIUM, else at least 55 % of
         * the screen wide is LARGE, else SMALL. A size the launcher has not
         * reported yet (0) is SMALL. Integer maths, so a cell exactly on a
         * threshold can't flip with rounding.
         */
        fun of(wDp: Int, hDp: Int, screenShortDp: Int): WidgetSize = when {
            wDp <= 0 || hDp <= 0 -> SMALL
            wDp * 100 >= hDp * 115 -> MEDIUM
            wDp * 100 >= screenShortDp * 55 -> LARGE
            else -> SMALL
        }
    }
}

/**
 * Every value a face shows, derived from one payload: pure, and mirrored by the
 * Dart `WidgetModel`. Both are tested against `test/fixtures/home_widget_cases.json`,
 * written by `tool/home_widget/ref_model.py` (rules: docs/code_docs/17-content-counter.md
 * §5.2), so the public fields are named after the fixture keys.
 *
 * It reads the tier, never computes it (IM-01), and a payload dated another
 * local day reads as Empty (IM-04) — its limit, theme and flags still apply.
 * [zoneOffsetMin] and [use24h] are the device's now; [updatedZoneOffsetMin] is
 * the device's UTC offset at `updated_at`, so across a DST change that
 * payload's day and "Updated" clock stay its own (defaults to [zoneOffsetMin]).
 */
class WidgetModel(
    val payload: WidgetPayload,
    nowMs: Long,
    zoneOffsetMin: Int,
    private val use24h: Boolean,
    updatedZoneOffsetMin: Int = zoneOffsetMin,
    /** The Plan face's source (EVO-073), read live by the caller; the demo plan when not given. */
    plan: PlanState = PlanState.DEMO,
) {

    private val sameDay = localDay(payload.updatedAt, updatedZoneOffsetMin) == localDay(nowMs, zoneOffsetMin)
    private val watch = if (sameDay) payload.watchSeconds else 0

    // Clamped here too: a payload built in code skips parse, and Int.MAX × 60 would wrap.
    private val limit = payload.limitMinutes.coerceIn(0, WidgetTokens.MAX_LIMIT_MINUTES) * 60

    /** Today's reels, uncapped (TalkBack reads the real number); 0 on another day. */
    val count: Int = if (sameDay) payload.reelCount else 0

    /** Today's watch seconds per local hour; zeros on another day. */
    val hourlySeconds: List<Int> = if (sameDay) payload.hourlySeconds else WidgetPayload.EMPTY.hourlySeconds

    val tier: Int = if (sameDay) payload.reelTier else 0
    val empty: Boolean = count == 0
    val final: Boolean = tier == WidgetPayload.MAX_TIER
    val hasLimit: Boolean = limit > 0
    val over: Boolean = hasLimit && watch > limit
    val stale: Boolean = payload.updatedAt > 0 && nowMs - payload.updatedAt > STALE_MS
    val trackingOff: Boolean = !payload.trackingEnabled

    val countText: String = capped(count)
    val time: String = hm(watch)
    val toNext: Int = (count / WidgetTokens.TIER_STEP + 1) * WidgetTokens.TIER_STEP - count
    val ringPct: Int = if (empty) 0 else if (final) 100 else count % WidgetTokens.TIER_STEP
    val segmentsOn: Int =
        if (hasLimit) ceil(watch.toDouble() / limit * SEGMENT_COUNT - 1e-6).toInt().coerceIn(0, SEGMENT_COUNT) else 0

    /** Bar heights 0.04..1 of the bar box; 30 minutes in an hour fills it. */
    val bars: List<Double> = hourlySeconds.map { (it / FULL_BAR_SECONDS).coerceIn(MIN_BAR, 1.0) }

    /** The first hour holding the most watch time; −1 before any. */
    val peakHour: Int = (hourlySeconds.maxOrNull() ?: 0).let { if (it > 0) hourlySeconds.indexOf(it) else -1 }
    val peakLabel: String = if (peakHour < 0) "No peak yet" else "Peak ${hourLabel(peakHour)}"
    val peakValue: String = if (peakHour < 0) "0m" else "${hourlySeconds[peakHour] / 60}m"

    val tierChip: String = if (tier == 0) "Empty" else "Tier $tier"
    val reelsChip: String = reels(count)
    val todayShort: String = if (empty) "No reels" else "Today"
    val todayLong: String = if (empty) "No reels yet" else "Reels today"
    val nextShort: String = when {
        empty -> "No reels yet"
        final -> "Final colour"
        else -> "$toNext to next"
    }
    val nextLong: String = when {
        empty -> "No reels yet"
        final -> "Final colour reached"
        else -> "${reels(toNext)} to next colour"
    }
    val nextLabel: String = when {
        empty -> "First reel starts tier 1"
        final -> "Final colour reached"
        else -> "Next colour in"
    }
    val nextValue: String = reels(if (final) count else toNext)

    // Time left of the limit, or past it when over; only read with a limit.
    private val gap = hm(abs(watch - limit))
    private val limitText = hm(limit)
    val leftBig: String = when {
        !hasLimit -> time
        over -> "+$gap"
        else -> gap
    }
    val limitLabel: String = when {
        !hasLimit -> "No daily limit"
        over -> "Over $limitText"
        else -> "Left of $limitText"
    }

    val bonsaiStage: String = STAGES[tier]
    val bonsaiHealth: Int = HEALTH[tier]
    val stageHealth: String = "$bonsaiStage · $bonsaiHealth%"

    val bentoNextLabel: String = when {
        empty -> "Starts at"
        final -> "Final colour"
        else -> "Next colour"
    }
    val bentoNextValue: String = when {
        empty -> "1 reel"
        final -> countText
        else -> reels(toNext)
    }

    private val updatedClock = clockLabel(payload.updatedAt, updatedZoneOffsetMin)

    /** DS-08: replaces the band label — tracking off beats stale; null in the normal states. */
    val note: String? = when {
        trackingOff -> "Turn on tracking"
        stale -> "Updated $updatedClock"
        else -> null
    }

    // ── Plan (EVO-073): the engine's plan, read live — not the payload ────

    // Clamped here too: a state built in code skips ConfigStore's 1..20.
    private val allowance = plan.reelAllowance.coerceIn(1, PlanState.MAX_ALLOWANCE)
    private val reelsLeft = allowance - plan.reelsConsumed.coerceIn(0, allowance)
    private val reelsSpent = reelsLeft == 0
    private val planKind: PlanKind = when {
        !plan.serviceOn -> PlanKind.SERVICE_OFF
        !plan.blockingOn -> PlanKind.BLOCKING_OFF
        nowMs < plan.pauseUntil -> PlanKind.PAUSED
        plan.plan == CommandHandler.PLAN_CONSCIOUS -> PlanKind.CONSCIOUS
        plan.plan == CommandHandler.PLAN_ONE_REEL -> if (allowance == 1) PlanKind.ONE_REEL else PlanKind.UNBLOCK
        // BLOCK_ALL, the legacy PAUSED token, anything unknown: the engine blocks every reel.
        else -> PlanKind.BLOCK_ALL
    }

    /** Whole minutes of a live Pause left: floored, so they agree with "Back on at", and never 0. */
    private val pauseMinutes =
        if (planKind == PlanKind.PAUSED) ((plan.pauseUntil - nowMs) / MINUTE_MS).toInt().coerceAtLeast(1) else 0
    private val pauseLeft = hm(pauseMinutes * 60)
    private val until = clockLabel(plan.pauseUntil, zoneOffsetMin)
    private val reelsLeftOf = "$reelsLeft of $allowance"
    private val counting = planKind == PlanKind.UNBLOCK && !reelsSpent

    /** The hero: the plan's name, "Paused" or "Off". */
    val planTitle: String = when (planKind) {
        PlanKind.SERVICE_OFF, PlanKind.BLOCKING_OFF -> "Off"
        PlanKind.PAUSED -> "Paused"
        PlanKind.BLOCK_ALL -> "Block All"
        // The one wire → label mapping: CURIOUS reads "Conscious"; ONE_REEL is One Reel / Unblock by allowance.
        PlanKind.CONSCIOUS, PlanKind.ONE_REEL, PlanKind.UNBLOCK -> planLabel(plan.plan, allowance)
    }

    /** The band label on Small. */
    val planLabelShort: String = when (planKind) {
        PlanKind.SERVICE_OFF -> "Turn on blocking"
        PlanKind.BLOCKING_OFF -> "Blocking off"
        PlanKind.PAUSED -> "Reels allowed"
        PlanKind.CONSCIOUS -> "Earn reel time"
        PlanKind.BLOCK_ALL -> "Reels blocked"
        PlanKind.ONE_REEL -> if (reelsSpent) "Reels blocked" else "1 reel allowed"
        PlanKind.UNBLOCK -> if (reelsSpent) "Reels blocked" else "Reels left"
    }

    /** The band label on Medium and Large. */
    val planLabelLong: String = when (planKind) {
        PlanKind.SERVICE_OFF -> "Turn on Accessibility to block"
        PlanKind.BLOCKING_OFF -> "Blocking is switched off"
        PlanKind.PAUSED -> "Back on at $until"
        PlanKind.CONSCIOUS -> "Earn reel time by staying off"
        PlanKind.BLOCK_ALL -> "Every reel is blocked"
        PlanKind.ONE_REEL -> if (reelsSpent) "Used, reels blocked again" else "1 reel allowed, then blocked"
        PlanKind.UNBLOCK -> if (reelsSpent) "Used, reels blocked again" else "Reels left, then blocked"
    }

    /** The band value on Small: a Pause's minutes left, or Unblock's "3 of 5"; else none. */
    val planValueShort: String = if (planKind == PlanKind.PAUSED) pauseLeft else if (counting) reelsLeftOf else ""

    /** The band value on Medium and Large: "4m left" after the clock, or "3 of 5". */
    val planValueLong: String = if (planKind == PlanKind.PAUSED) "$pauseLeft left" else if (counting) reelsLeftOf else ""

    /** The value is a countdown: Medium and Large lead it with the clock. */
    val planClock: Boolean = planKind == PlanKind.PAUSED

    /** Protection in force, 0..100: full when on, filling as an allowance is spent, empty while paused or off. */
    val planRingPct: Int = when (planKind) {
        PlanKind.BLOCK_ALL, PlanKind.CONSCIOUS -> 100
        PlanKind.ONE_REEL, PlanKind.UNBLOCK -> (allowance - reelsLeft) * 100 / allowance
        PlanKind.PAUSED, PlanKind.SERVICE_OFF, PlanKind.BLOCKING_OFF -> 0
    }

    /** Large's ring hole. */
    val planRingText: String = when (planKind) {
        PlanKind.BLOCK_ALL, PlanKind.CONSCIOUS -> "On"
        PlanKind.SERVICE_OFF, PlanKind.BLOCKING_OFF -> "Off"
        PlanKind.PAUSED -> pauseLeft
        PlanKind.ONE_REEL, PlanKind.UNBLOCK -> "$reelsLeft"
    }

    /** The Plan widget's TalkBack line, any size (DS-05). */
    val planDescription: String = when (planKind) {
        PlanKind.SERVICE_OFF -> "Blocking is off, turn on Accessibility for Detoxo"
        PlanKind.BLOCKING_OFF -> "Blocking is switched off"
        PlanKind.PAUSED -> "Paused, reels allowed for ${minutes(pauseMinutes)}, blocking returns at $until"
        PlanKind.CONSCIOUS -> "$planTitle is on, earn reel time by staying off"
        PlanKind.BLOCK_ALL -> "$planTitle is on, every reel is blocked"
        PlanKind.ONE_REEL, PlanKind.UNBLOCK -> when {
            reelsSpent -> "$planTitle used, reels are blocked again"
            planKind == PlanKind.ONE_REEL -> "$planTitle is on, 1 reel allowed, then blocked"
            else -> "$planTitle is on, $reelsLeftOf reels left"
        }
    }

    /**
     * Everything the Plan face draws, for the visible key (IM-03), whose last
     * field it is: joined with "/" and holding no "|" ([ReelWidgetSync.onlyPlanDiffers]).
     */
    internal val planKey: String =
        listOf(planTitle, planLabelShort, planLabelLong, planValueShort, planValueLong, planRingPct, planRingText)
            .joinToString("/")

    /** The TalkBack line for one instance: what it shows, then its state. */
    fun describe(family: WidgetFamily, size: WidgetSize): String {
        val countLine = "${spoken(count)} today, $time watched"
        val ringLine = if (final) {
            "${spoken(count)} today, final colour reached"
        } else {
            "${spoken(count)} today, ${spoken(toNext)} to the next colour"
        }
        val base = when (family) {
            WidgetFamily.COUNT -> countLine
            WidgetFamily.NEXT_COLOUR -> ringLine
            WidgetFamily.TIME_LIMIT -> when {
                !hasLimit -> "$time watched today, no daily limit set"
                over -> "$time watched, $gap over the $limitText limit"
                else -> "$time watched, $gap left of the $limitText limit"
            }
            WidgetFamily.RHYTHM -> if (peakHour < 0) {
                "$time watched today"
            } else {
                "$time watched today, peak at ${hourLabel(peakHour)} with ${minutes(hourlySeconds[peakHour] / 60)}"
            }
            WidgetFamily.BONSAI -> "Bonsai is $bonsaiStage, health $bonsaiHealth%, ${spoken(count)} today"
            WidgetFamily.BENTO -> if (size == WidgetSize.SMALL) countLine else ringLine
            WidgetFamily.PLAN -> planDescription
        }
        // The plan is read live at every draw: no tracking or stale note (EVO-073).
        if (family == WidgetFamily.PLAN) return base
        return when {
            trackingOff -> "$base, tracking is off"
            stale -> "$base, updated $updatedClock"
            else -> base
        }
    }

    /** "11 PM", or "23:00" in 24 h mode. */
    private fun hourLabel(h: Int): String = if (use24h) "${two(h)}:00" else "${h12(h)} ${meridiem(h)}"

    /** "9:40 PM", or "21:40" in 24 h mode, of [ms] in local time. */
    private fun clockLabel(ms: Long, zoneOffsetMin: Int): String {
        val minute = (ms + zoneOffsetMin * MINUTE_MS).floorDiv(MINUTE_MS).mod(MINUTES_PER_DAY).toInt()
        val h = minute / 60
        val mm = two(minute % 60)
        return if (use24h) "${two(h)}:$mm" else "${h12(h)}:$mm ${meridiem(h)}"
    }

    /** What the Plan face shows, highest first (EVO-073). */
    private enum class PlanKind { SERVICE_OFF, BLOCKING_OFF, PAUSED, CONSCIOUS, ONE_REEL, UNBLOCK, BLOCK_ALL }

    companion object {
        /** Lit segments out of this many on Time limit. */
        const val SEGMENT_COUNT = WidgetTokens.SEGMENT_COUNT
        private const val FULL_BAR_SECONDS = 1800.0
        private const val MIN_BAR = 0.04
        private const val MINUTE_MS = 60_000L
        private const val MINUTES_PER_DAY = 1440L
        private const val DAY_MS = 86_400_000L
        private const val STALE_MS = WidgetTokens.STALE_MINUTES * MINUTE_MS

        private val STAGES = listOf("Blooming", "Happy", "Thirsty", "Wilting", "Withering", "Leafless")
        private val HEALTH = listOf(100, 90, 70, 50, 25, 0)

        /** The local day number of [ms]: a day change compares this, never elapsed time (IM-04). */
        internal fun localDay(ms: Long, zoneOffsetMin: Int): Long = (ms + zoneOffsetMin * MINUTE_MS).floorDiv(DAY_MS)

        /**
         * Ms until a live Pause's widget countdown next steps down, [leftMs]
         * before its end; the last step is the end itself (EVO-073: the
         * service's plan tick). Never more than a minute: the service's
         * handler counts uptime, which stops while the CPU sleeps, so a
         * longer delay would land late after a wake. Pure.
         */
        internal fun planTickDelayMs(leftMs: Long): Long =
            if (leftMs < 2 * MINUTE_MS) minOf(leftMs, MINUTE_MS) else leftMs % MINUTE_MS + 1

        /** DS-09: counts past 999 read "999+". */
        private fun capped(n: Int): String = if (n > 999) "999+" else "$n"

        /** "1 reel" / "152 reels" on the widget, capped. */
        private fun reels(n: Int): String = if (n == 1) "1 reel" else "${capped(n)} reels"

        /** The same for TalkBack, with the real number. */
        private fun spoken(n: Int): String = if (n == 1) "1 reel" else "$n reels"

        private fun minutes(m: Int): String = if (m == 1) "1 minute" else "$m minutes"

        /** DS-09 time: "48m" / "1h 12m" / "2h", never seconds — Dart `formatHm` too. */
        private fun hm(seconds: Int): String = UsageQuery.formatHm(seconds * 1000L)

        // Plain string padding, not String.format: a locale with its own digits
        // would otherwise render the clock in them.
        private fun two(n: Int): String = n.toString().padStart(2, '0')

        private fun h12(h: Int): Int = if (h % 12 == 0) 12 else h % 12

        private fun meridiem(h: Int): String = if (h < 12) "AM" else "PM"
    }
}
