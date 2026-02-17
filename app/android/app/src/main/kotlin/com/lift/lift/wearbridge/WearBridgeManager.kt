package com.lift.lift.wearbridge

import android.content.Context
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.concurrent.atomic.AtomicReference

object WearBridgeManager {
    const val PHONE_TO_WEAR_PATH = "/lift/phone/envelope"
    const val WEAR_TO_PHONE_PATH = "/lift/wear/envelope"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val intentSinkRef = AtomicReference<EventChannel.EventSink?>(null)
    private val sensorSinkRef = AtomicReference<EventChannel.EventSink?>(null)

    fun setIntentSink(sink: EventChannel.EventSink?) {
        intentSinkRef.set(sink)
    }

    fun setSensorSink(sink: EventChannel.EventSink?) {
        sensorSinkRef.set(sink)
    }

    fun publishSnapshot(context: Context, bytes: ByteArray) {
        scope.launch {
            val nodeClient = Wearable.getNodeClient(context)
            val messageClient = Wearable.getMessageClient(context)
            val nodes = runCatching { nodeClient.connectedNodes.await() }.getOrDefault(emptyList())
            for (node in nodes) {
                runCatching { messageClient.sendMessage(node.id, PHONE_TO_WEAR_PATH, bytes).await() }
            }
        }
    }

    fun onWearEnvelopeReceived(path: String, bytes: ByteArray) {
        if (path != WEAR_TO_PHONE_PATH) return

        runCatching {
            val envelope = workout.v1.Wearable.WearToPhoneEnvelope.parseFrom(bytes)
            when {
                envelope.hasIntent() -> intentSinkRef.get()?.success(bytes)
                envelope.hasSensorBatch() -> sensorSinkRef.get()?.success(bytes)
            }
        }
    }
}
