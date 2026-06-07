package com.errorxperts.detoxo

import com.errorxperts.detoxo.channels.CommandHandler
import com.errorxperts.detoxo.channels.DetoxoEventStream
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity (required by local_auth) that wires the command
 * MethodChannel and the engine EventChannel to the Flutter engine.
 */
class MainActivity : FlutterFragmentActivity() {

    private var commandHandler: CommandHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val handler = CommandHandler(applicationContext, this)
        commandHandler = handler
        MethodChannel(messenger, COMMANDS_CHANNEL).setMethodCallHandler(handler)
        EventChannel(messenger, EVENTS_CHANNEL).setStreamHandler(DetoxoEventStream())
    }

    override fun onDestroy() {
        commandHandler?.attachActivity(null)
        super.onDestroy()
    }

    private companion object {
        const val COMMANDS_CHANNEL = "com.errorxperts.detoxo/commands"
        const val EVENTS_CHANNEL = "com.errorxperts.detoxo/events"
    }
}
