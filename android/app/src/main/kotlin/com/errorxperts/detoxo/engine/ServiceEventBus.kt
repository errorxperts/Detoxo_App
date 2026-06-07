package com.errorxperts.detoxo.engine

import android.os.Handler
import android.os.Looper

/**
 * In-process bridge from the AccessibilityService to the Flutter EventChannel.
 *
 * The service posts events here; when the Flutter engine is alive its
 * EventChannel stream handler registers a [sink] and receives them (always on
 * the main thread). When the UI is dead, events are simply dropped — the block
 * hot-path does not depend on Dart.
 */
object ServiceEventBus {

    fun interface Sink {
        fun emit(event: Map<String, Any?>)
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var sink: Sink? = null

    fun post(type: String, data: Map<String, Any?> = emptyMap()) {
        val sink = this.sink ?: return
        val payload = HashMap<String, Any?>(data).apply { put("type", type) }
        mainHandler.post { sink.emit(payload) }
    }
}
