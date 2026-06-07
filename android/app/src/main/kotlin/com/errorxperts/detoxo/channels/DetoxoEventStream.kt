package com.errorxperts.detoxo.channels

import com.errorxperts.detoxo.engine.ServiceEventBus
import io.flutter.plugin.common.EventChannel

/**
 * Bridges [ServiceEventBus] to the Flutter EventChannel. While Dart is
 * listening, native engine events (status, detections, blocks) flow through.
 */
class DetoxoEventStream : EventChannel.StreamHandler {

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        ServiceEventBus.sink = if (events == null) null else ServiceEventBus.Sink { events.success(it) }
    }

    override fun onCancel(arguments: Any?) {
        ServiceEventBus.sink = null
    }
}
