package com.lift.lift.wearbridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicReference

object WearBridgeManager {
    const val PHONE_TO_WEAR_PATH = "/lift/phone/envelope"
    const val WEAR_TO_PHONE_PATH = "/lift/wear/envelope"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val intentSinkRef = AtomicReference<EventChannel.EventSink?>(null)
    private val sensorSinkRef = AtomicReference<EventChannel.EventSink?>(null)
    private val pendingIntentPayloads = ConcurrentLinkedQueue<ByteArray>()
    private val pendingSensorPayloads = ConcurrentLinkedQueue<ByteArray>()

    fun setIntentSink(sink: EventChannel.EventSink?) {
        intentSinkRef.set(sink)
        if (sink != null) {
            flushPendingIntentPayloads(sink)
        }
    }

    fun setSensorSink(sink: EventChannel.EventSink?) {
        sensorSinkRef.set(sink)
        if (sink != null) {
            flushPendingSensorPayloads(sink)
        }
    }

    fun publishSnapshot(context: Context, bytes: ByteArray) {
        scope.launch {
            val nodeClient = Wearable.getNodeClient(context)
            val messageClient = Wearable.getMessageClient(context)
            val nodes = runCatching { nodeClient.connectedNodes.await() }.getOrDefault(emptyList())
            Log.d("LiftWearBridge", "Publishing snapshot to ${nodes.size} node(s)")
            for (node in nodes) {
                runCatching { messageClient.sendMessage(node.id, PHONE_TO_WEAR_PATH, bytes).await() }
                    .onFailure { Log.e("LiftWearBridge", "Failed snapshot send to node=${node.id}", it) }
            }
        }
    }

    fun onWearEnvelopeReceived(path: String, bytes: ByteArray) {
        if (path != WEAR_TO_PHONE_PATH) return

        runCatching {
            val envelope = workout.v1.Wearable.WearToPhoneEnvelope.parseFrom(bytes)
            when {
                envelope.hasIntent() -> emitIntent(bytes)
                envelope.hasSensorBatch() -> emitSensor(bytes)
            }
            Log.d(
                "LiftWearBridge",
                "Received wear envelope payload=intent:${envelope.hasIntent()} sensor:${envelope.hasSensorBatch()}",
            )
        }
            .onFailure { Log.e("LiftWearBridge", "Failed to parse wear envelope", it) }
    }

    private fun emitIntent(bytes: ByteArray) {
        val sink = intentSinkRef.get()
        if (sink == null) {
            pendingIntentPayloads.add(bytes)
            return
        }
        mainHandler.post { sink.success(bytes) }
    }

    private fun emitSensor(bytes: ByteArray) {
        val sink = sensorSinkRef.get()
        if (sink == null) {
            pendingSensorPayloads.add(bytes)
            return
        }
        mainHandler.post { sink.success(bytes) }
    }

    private fun flushPendingIntentPayloads(sink: EventChannel.EventSink) {
        var payload = pendingIntentPayloads.poll()
        while (payload != null) {
            val bytes = payload
            mainHandler.post { sink.success(bytes) }
            payload = pendingIntentPayloads.poll()
        }
    }

    private fun flushPendingSensorPayloads(sink: EventChannel.EventSink) {
        var payload = pendingSensorPayloads.poll()
        while (payload != null) {
            val bytes = payload
            mainHandler.post { sink.success(bytes) }
            payload = pendingSensorPayloads.poll()
        }
    }
}
