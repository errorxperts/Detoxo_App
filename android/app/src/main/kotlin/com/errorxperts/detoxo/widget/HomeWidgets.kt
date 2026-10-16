package com.errorxperts.detoxo.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.text.format.DateFormat
import android.util.Log
import android.widget.RemoteViews
import com.errorxperts.detoxo.MainActivity
import com.errorxperts.detoxo.R
import java.util.TimeZone
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * The home-screen widgets' Android side: the one worker every widget task
 * runs on, the per-instance render (size class, TalkBack line, tap), the pin
 * request and the picker previews. What to draw comes from [ReelWidgetSync];
 * how to draw it from [WidgetBitmapRenderer].
 */
object HomeWidgets {

    const val ACTION_TAP = "com.errorxperts.detoxo.action.WIDGET_TAP"
    const val EXTRA_FAMILY = "family"
    const val EXTRA_SIZE = "size"

    private const val TAG = "DetoxoWidgets"

    // One thread: renders and payload writes never interleave, so the
    // rendered-key dedupe needs no lock. Background priority, so a render
    // never competes with the app the user is scrolling. Lazy so the JVM
    // tests never start it.
    private val worker by lazy {
        Executors.newSingleThreadExecutor { task ->
            Thread({
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
                task.run()
            }, "detoxo-widgets")
        }
    }

    /**
     * The only way onto the widget worker. A throw is logged, never
     * rethrown: it would kill the process that hosts the accessibility
     * service.
     */
    fun run(block: () -> Unit) {
        worker.execute {
            try {
                block()
            } catch (t: Throwable) {
                Log.w(TAG, "widget task failed", t)
            }
        }
    }

    /** The provider class of [family]; exhaustive, so a new family needs its provider to compile. */
    fun providerFor(family: WidgetFamily): Class<out FamilyWidgetProvider> = when (family) {
        WidgetFamily.COUNT -> ContentCounterWidgetProvider::class.java
        WidgetFamily.NEXT_COLOUR -> NextColourWidgetProvider::class.java
        WidgetFamily.TIME_LIMIT -> TimeLimitWidgetProvider::class.java
        WidgetFamily.RHYTHM -> RhythmWidgetProvider::class.java
        WidgetFamily.BONSAI -> BonsaiWidgetProvider::class.java
        WidgetFamily.BENTO -> BentoWidgetProvider::class.java
        WidgetFamily.PLAN -> PlanWidgetProvider::class.java
    }

    /**
     * Worker only: every pinned instance of every family, as (family, id).
     * One binder call per family, so a push fetches them once.
     */
    fun pinned(ctx: Context): List<Pair<WidgetFamily, Int>> {
        val mgr = AppWidgetManager.getInstance(ctx) ?: return emptyList()
        return WidgetFamily.entries.flatMap { family ->
            mgr.getAppWidgetIds(ComponentName(ctx, providerFor(family))).map { family to it }
        }
    }

    /**
     * Worker only: [payload] on each [pinned] instance. One instance's throw
     * is logged and the rest still draw; true when every one drew.
     */
    fun renderAll(ctx: Context, pinned: List<Pair<WidgetFamily, Int>>, payload: WidgetPayload): Boolean {
        val mgr = AppWidgetManager.getInstance(ctx) ?: return false
        val model = model(ctx, payload)
        return tryEach(pinned, { (family, id), t -> Log.w(TAG, "render failed: $family #$id", t) }) { (family, id) ->
            render(ctx, mgr, family, id, model)
        }
    }

    /** [block] on every one of [items]; a throw goes to [onError] and the rest still run. True when none threw. */
    internal fun <T> tryEach(items: Iterable<T>, onError: (T, Throwable) -> Unit, block: (T) -> Unit): Boolean {
        var ok = true
        for (item in items) {
            try {
                block(item)
            } catch (t: Throwable) {
                ok = false
                onError(item, t)
            }
        }
        return ok
    }

    /** Worker only: one [family] instance, [id], drawing [model] at its own size. */
    internal fun render(ctx: Context, mgr: AppWidgetManager, family: WidgetFamily, id: Int, model: WidgetModel) {
        val opts = mgr.getAppWidgetOptions(id)
        val config = ctx.resources.configuration
        val (wDp, hDp) = instanceDp(
            opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
            opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT),
            opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH),
            opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT),
            config.smallestScreenWidthDp,
            config.orientation == Configuration.ORIENTATION_LANDSCAPE,
        )
        val size = WidgetSize.of(wDp, hDp, config.smallestScreenWidthDp)
        // Before the launcher reports a size, draw the design box.
        val known = wDp > 0 && hDp > 0
        val density = ctx.resources.displayMetrics.density
        val wPx = ((if (known) wDp.toFloat() else size.designWidth) * density).roundToInt()
        val hPx = ((if (known) hDp.toFloat() else size.designHeight) * density).roundToInt()
        // ponytail: a Large bitmap (long side ≤ 1200 px, ≈ 5.8 MB) rides the
        // RemoteViews binder call; a device that throws TransactionTooLarge
        // needs a smaller pixel budget in WidgetBitmapRenderer.
        val views = RemoteViews(ctx.packageName, R.layout.content_counter_widget).apply {
            setImageViewBitmap(R.id.cc_widget_image, WidgetBitmapRenderer.render(ctx, family, size, model, wPx, hPx))
            setContentDescription(R.id.cc_widget_image, model.describe(family, size))
            setOnClickPendingIntent(R.id.cc_widget_image, tapIntent(ctx, id, family, size))
        }
        mgr.updateAppWidget(id, views)
    }

    /**
     * Asks the launcher to pin a [family] widget, its dialog showing that
     * family's demo face. False when the launcher can't pin.
     */
    fun requestPin(ctx: Context, family: WidgetFamily): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val mgr = ctx.getSystemService(AppWidgetManager::class.java) ?: return false
        if (!mgr.isRequestPinAppWidgetSupported) return false
        val extras = Bundle().apply { putParcelable(AppWidgetManager.EXTRA_APPWIDGET_PREVIEW, previewViews(ctx, family)) }
        return mgr.requestPinAppWidget(ComponentName(ctx, providerFor(family)), extras, null)
    }

    /**
     * Worker only. Android 15+ shows each family's real demo face in the
     * widget picker; published once per versionCode, since the system
     * rate-limits it. A refused family is retried on the next refresh.
     * Older launchers show each family's checked-in picture instead
     * (`android:previewImage`, EVO-071).
     */
    fun publishPickerPreviews(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val version = ctx.packageManager
            .getPackageInfo(ctx.packageName, PackageManager.PackageInfoFlags.of(0L))
            .longVersionCode
        val prefs = ReelWidgetSync.prefs(ctx)
        if (prefs.getLong(KEY_PREVIEWS_VERSION, -1L) == version) return
        val mgr = AppWidgetManager.getInstance(ctx) ?: return
        // Every family is tried, so one refusal doesn't hold back the rest.
        val published = WidgetFamily.entries.map {
            mgr.setWidgetPreview(
                ComponentName(ctx, providerFor(it)),
                AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                previewViews(ctx, it),
            )
        }.all { it }
        if (published) prefs.edit().putLong(KEY_PREVIEWS_VERSION, version).apply()
    }

    /** [family]'s Small face on the board's demo day, for the pin dialog and the picker. */
    private fun previewViews(ctx: Context, family: WidgetFamily): RemoteViews {
        val now = System.currentTimeMillis()
        val model = model(ctx, WidgetPayload.demo(PREVIEW_LIMIT_MINUTES, "system", true, now), PlanState.DEMO)
        return RemoteViews(ctx.packageName, R.layout.content_counter_widget).apply {
            setImageViewBitmap(R.id.cc_widget_image, WidgetBitmapRenderer.preview(ctx, family, model))
            setContentDescription(R.id.cc_widget_image, model.describe(family, WidgetSize.SMALL))
        }
    }

    /**
     * IM-08: the tap opens Detoxo with this instance's family and size;
     * [MainActivity] decides where to. CLEAR_TOP + SINGLE_TOP hand the tap to
     * the running instance's `onNewIntent`, even under Settings opened from
     * Detoxo: without CLEAR_TOP that stacks a second MainActivity (a second
     * Flutter engine), or brings the task forward and drops the tap.
     */
    private fun tapIntent(ctx: Context, id: Int, family: WidgetFamily, size: WidgetSize): PendingIntent =
        PendingIntent.getActivity(
            ctx,
            id,
            Intent(ctx, MainActivity::class.java)
                .setAction(ACTION_TAP)
                .putExtra(EXTRA_FAMILY, family.wire)
                .putExtra(EXTRA_SIZE, size.wire)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** [payload] and [plan] (EVO-073; live unless given) as the faces see them now, on this device's clock. */
    internal fun model(ctx: Context, payload: WidgetPayload, plan: PlanState = ReelWidgetSync.plan(ctx)): WidgetModel {
        val now = System.currentTimeMillis()
        return WidgetModel(
            payload,
            now,
            zoneOffsetMin(now),
            DateFormat.is24HourFormat(ctx),
            zoneOffsetMin(payload.updatedAt),
            plan,
        )
    }

    /**
     * The device's UTC offset at the instant [atMs], in minutes: at now for
     * the clock, at `updated_at` for the payload's own day and "Updated" time.
     */
    fun zoneOffsetMin(atMs: Long): Int = TimeZone.getDefault().getOffset(atMs) / 60_000

    /**
     * The dp box an instance is drawn at. A phone (smallest width < 600 dp)
     * always uses its portrait bounds, min width × max height, so turning it
     * never swaps the face; a tablet uses the current orientation's
     * (landscape: max width × min height). 0 = not reported.
     */
    internal fun instanceDp(
        minW: Int,
        minH: Int,
        maxW: Int,
        maxH: Int,
        smallestScreenDp: Int,
        landscape: Boolean,
    ): Pair<Int, Int> = if (smallestScreenDp >= TABLET_DP && landscape) maxW to minH else minW to maxH

    /** The `takePendingWidgetTap` string, `"FAMILY|SIZE|TARGET"` — Dart `WidgetTap.parse`. */
    fun tapWire(family: WidgetFamily, size: WidgetSize, target: WidgetTapTarget): String =
        "${family.wire}|${size.wire}|${target.name}"

    /**
     * A plain launcher open: `ACTION_MAIN`, not a Recents replay. It drops a
     * tap Dart never took (a tap, then quitting at the launch PIN): the open
     * hours later belongs to no widget. Pure.
     */
    fun isPlainLaunch(action: String?, flags: Int): Boolean =
        action == Intent.ACTION_MAIN && flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0

    /** The picker / pin previews' limit. */
    private const val PREVIEW_LIMIT_MINUTES = 120
    private const val TABLET_DP = 600
    private const val KEY_PREVIEWS_VERSION = "widget_previews_version"
}

/** IM-08: where a widget tap leads, decided at tap time. The wire is the name (Dart `WidgetTapTarget`). */
enum class WidgetTapTarget {
    ACTIVITY,
    APPEARANCE,
    PERMISSIONS,

    /** Plan only (EVO-073): blocking is switched off. */
    SETTINGS,
    ;

    companion object {
        /**
         * Plan (EVO-073): the service not running → the grant; blocking switched
         * off → Settings, its "Blocking active" switch; else the plan switcher.
         * Its face reads the same [plan], so face and tap agree. The reel
         * families: counter off → the switch that turns it on; else
         * accessibility off → the grant; else today's activity.
         */
        fun of(family: WidgetFamily, counterOn: Boolean, accessibilityOn: Boolean, plan: PlanState): WidgetTapTarget =
            when {
                family == WidgetFamily.PLAN -> when {
                    !plan.serviceOn -> PERMISSIONS
                    !plan.blockingOn -> SETTINGS
                    else -> ACTIVITY
                }
                !counterOn -> APPEARANCE
                !accessibilityOn -> PERMISSIONS
                else -> ACTIVITY
            }
    }
}

/**
 * One family's home-screen widget. The launcher's update and resize
 * callbacks draw the stored payload on the widget worker, keeping the
 * broadcast alive until the render ends. Live updates come from
 * [ReelWidgetSync.push].
 */
abstract class FamilyWidgetProvider(private val family: WidgetFamily) : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) =
        later(context, appWidgetManager, appWidgetIds)

    // A resize can change the size class (S / M / L), and the bitmap must match the new cell.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) = later(context, appWidgetManager, intArrayOf(appWidgetId))

    private fun later(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        val app = context.applicationContext
        val pending = goAsync()
        HomeWidgets.run {
            try {
                // The first pin's update arms the midnight job, which runs
                // only while a widget is pinned. Idempotent.
                MidnightJobService.schedule(app)
                val model = HomeWidgets.model(app, ReelWidgetSync.current(app))
                for (id in ids) HomeWidgets.render(app, mgr, family, id, model)
            } finally {
                pending.finish()
            }
        }
    }
}

// The seven launcher entries (manifest receivers, each with its own provider info, EVO-071).
// Count keeps the original class name, so widgets pinned before the families existed carry on as Count.
class ContentCounterWidgetProvider : FamilyWidgetProvider(WidgetFamily.COUNT)
class NextColourWidgetProvider : FamilyWidgetProvider(WidgetFamily.NEXT_COLOUR)
class TimeLimitWidgetProvider : FamilyWidgetProvider(WidgetFamily.TIME_LIMIT)
class RhythmWidgetProvider : FamilyWidgetProvider(WidgetFamily.RHYTHM)
class BonsaiWidgetProvider : FamilyWidgetProvider(WidgetFamily.BONSAI)
class BentoWidgetProvider : FamilyWidgetProvider(WidgetFamily.BENTO)
class PlanWidgetProvider : FamilyWidgetProvider(WidgetFamily.PLAN)
