package com.errorxperts.detoxo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import androidx.core.content.ContextCompat
import com.errorxperts.detoxo.channels.CommandHandler
import com.errorxperts.detoxo.channels.DetoxoEventStream
import com.errorxperts.detoxo.engine.AccessibilityCheck
import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.widget.HomeWidgets
import com.errorxperts.detoxo.widget.ReelWidgetSync
import com.errorxperts.detoxo.widget.WidgetFamily
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.WidgetTapTarget
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity (required by local_auth) that wires the command
 * MethodChannel and the engine EventChannel to the Flutter engine, tracks
 * the last screen-off for the PIN lock's "when screen turns off" auto-lock,
 * and holds the last home-widget tap for Dart to route.
 */
class MainActivity : FlutterFragmentActivity() {

    private var commandHandler: CommandHandler? = null

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            lastScreenOffMillis = System.currentTimeMillis()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity re-reads its old launch intent: not a new tap.
        if (savedInstanceState == null) takeWidgetTap(intent)
        // ponytail: wall-clock stamp; a user clock change skews one comparison.
        // ponytail: API-34 broadcast deferral for cached processes can deliver a
        // screen-off after the resume query — one missed relock, self-heals.
        ContextCompat.registerReceiver(
            this,
            screenOffReceiver,
            IntentFilter(Intent.ACTION_SCREEN_OFF),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val handler = CommandHandler(applicationContext, this)
        commandHandler = handler
        MethodChannel(messenger, COMMANDS_CHANNEL).setMethodCallHandler(handler)
        EventChannel(messenger, EVENTS_CHANNEL).setStreamHandler(DetoxoEventStream())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        takeWidgetTap(intent)
    }

    /**
     * IM-08: a home-widget tap becomes [pendingWidgetTap], its target
     * decided now from the tracker's state. A relaunch from Recents replays
     * the old intent and is ignored, as is anything that is not a well-formed
     * tap. A plain launcher open clears a tap Dart never took, so it cannot
     * route a visit hours later ([HomeWidgets.isPlainLaunch]).
     */
    private fun takeWidgetTap(intent: Intent?) {
        if (intent == null) return
        if (HomeWidgets.isPlainLaunch(intent.action, intent.flags)) {
            pendingWidgetTap = null
            return
        }
        if (intent.action != HomeWidgets.ACTION_TAP) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val family = WidgetFamily.fromWire(intent.getStringExtra(HomeWidgets.EXTRA_FAMILY)) ?: return
        val size = WidgetSize.fromWire(intent.getStringExtra(HomeWidgets.EXTRA_SIZE)) ?: return
        val target = WidgetTapTarget.of(
            family,
            counterOn = ContentCounterStore(this).enabled,
            accessibilityOn = AccessibilityCheck.isEnabled(this),
            plan = ReelWidgetSync.plan(this),
        )
        pendingWidgetTap = HomeWidgets.tapWire(family, size, target)
    }

    override fun onDestroy() {
        unregisterReceiver(screenOffReceiver)
        commandHandler?.attachActivity(null)
        super.onDestroy()
    }

    companion object {
        private const val COMMANDS_CHANNEL = "com.errorxperts.detoxo/commands"
        private const val EVENTS_CHANNEL = "com.errorxperts.detoxo/events"

        /**
         * Wall-clock millis of the last ACTION_SCREEN_OFF this process (0 =
         * never). In-memory only: process death cold-starts through the splash
         * PIN gate anyway, so nothing needs persisting.
         */
        @Volatile
        var lastScreenOffMillis = 0L

        /**
         * The last home-widget tap, `"FAMILY|SIZE|TARGET"`, until Dart takes
         * it (`takePendingWidgetTap`, read-and-clear) or a plain launcher
         * open drops it. In-memory like [lastScreenOffMillis]: the tap that
         * cold-starts the process sets it in [onCreate].
         */
        @Volatile
        var pendingWidgetTap: String? = null
    }
}
