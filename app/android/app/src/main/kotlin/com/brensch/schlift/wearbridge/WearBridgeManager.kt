package com.brensch.schlift.wearbridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.CompletableDeferred
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

object WearBridgeManager {
    const val PHONE_TO_WEAR_SNAPSHOT_PATH = "/schlift/phone/snapshot"
    const val PHONE_TO_WEAR_LAUNCH_PATH = "/schlift/phone/launch"
    const val PHONE_TO_WEAR_CLOCK_SYNC_PATH = "/schlift/phone/clock_sync"
    const val PHONE_TO_WEAR_SENSOR_BATCH_ACK_PATH = "/schlift/phone/sensor_batch_ack"
    const val WEAR_TO_PHONE_INTENT_PATH = "/schlift/wear/intent"
    const val WEAR_TO_PHONE_SENSOR_BATCH_PATH = "/schlift/wear/sensor_batch"
    const val WEAR_TO_PHONE_UI_HEARTBEAT_PATH = "/schlift/wear/ui_heartbeat"
    const val WEAR_TO_PHONE_CLOCK_SYNC_PATH = "/schlift/wear/clock_sync"
    const val WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH = "/schlift/wear/snapshot_request"
    const val WEAR_APP_CAPABILITY = "lift_wear_companion"
    private const val WATCH_UI_HEARTBEAT_TTL_MS = 8_000L

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val intentSinkRef = AtomicReference<EventChannel.EventSink?>(null)
    private val sensorSinkRef = AtomicReference<EventChannel.EventSink?>(null)
    private val pendingIntentPayloads = ConcurrentLinkedQueue<ByteArray>()
    private val pendingSensorPayloads = ConcurrentLinkedQueue<ByteArray>()
    private val lastWatchUiHeartbeatAtMs = AtomicLong(0L)
    private val pendingClockSyncs = ConcurrentHashMap<String, CompletableDeferred<Long>>()
    private val lastSnapshotBytes = AtomicReference<ByteArray?>(null)

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
        lastSnapshotBytes.set(bytes)
        scope.launch {
            val nodeClient = Wearable.getNodeClient(context)
            val messageClient = Wearable.getMessageClient(context)
            val nodes = runCatching { nodeClient.connectedNodes.await() }.getOrDefault(emptyList())
            Log.d("SchliftWearBridge", "Publishing snapshot to ${nodes.size} node(s)")
            for (node in nodes) {
                runCatching { messageClient.sendMessage(node.id, PHONE_TO_WEAR_SNAPSHOT_PATH, bytes).await() }
                    .onFailure { Log.e("SchliftWearBridge", "Failed snapshot send to node=${node.id}", it) }
            }
        }
    }

    suspend fun requestWatchAppOpen(context: Context): Int {
        val nodeClient = Wearable.getNodeClient(context)
        val messageClient = Wearable.getMessageClient(context)
        val nodes = runCatching { nodeClient.connectedNodes.await() }.getOrDefault(emptyList())
        var sent = 0
        for (node in nodes) {
            runCatching {
                messageClient.sendMessage(node.id, PHONE_TO_WEAR_LAUNCH_PATH, ByteArray(0)).await()
            }
                .onSuccess {
                    sent += 1
                }
                .onFailure {
                    Log.e("SchliftWearBridge", "Failed launch send to node=${node.id}", it)
                }
        }
        return sent
    }

    suspend fun requestWatchClockSync(context: Context): Map<String, Long>? {
        val nodeClient = Wearable.getNodeClient(context)
        val messageClient = Wearable.getMessageClient(context)
        val nodes = runCatching { nodeClient.connectedNodes.await() }.getOrDefault(emptyList())
        val node = nodes.firstOrNull() ?: return null
        val requestId = System.currentTimeMillis().toString()
        val deferred = CompletableDeferred<Long>()
        pendingClockSyncs[requestId] = deferred
        val sentAtMs = System.currentTimeMillis()
        return try {
            messageClient.sendMessage(node.id, PHONE_TO_WEAR_CLOCK_SYNC_PATH, requestId.toByteArray()).await()
            val watchTimeMs = withTimeoutOrNull(3000) { deferred.await() } ?: return null
            val receivedAtMs = System.currentTimeMillis()
            mapOf(
                "watchTimeMs" to watchTimeMs,
                "sentAtMs" to sentAtMs,
                "receivedAtMs" to receivedAtMs,
            )
        } finally {
            pendingClockSyncs.remove(requestId)
        }
    }

    suspend fun isWatchAppAvailable(context: Context): Boolean {
        val capabilityClient = Wearable.getCapabilityClient(context)
        val capability = runCatching {
            capabilityClient
                .getCapability(WEAR_APP_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .await()
        }
            .onFailure { Log.e("SchliftWearBridge", "Failed capability query", it) }
            .getOrNull()
            ?: return false
        return capability.nodes.isNotEmpty()
    }

    fun isWatchAppOpenOnWatch(): Boolean {
        val lastSeen = lastWatchUiHeartbeatAtMs.get()
        if (lastSeen <= 0L) return false
        return (System.currentTimeMillis() - lastSeen) <= WATCH_UI_HEARTBEAT_TTL_MS
    }

    fun onWearMessageReceived(context: Context, sourceNodeId: String, path: String, bytes: ByteArray) {
        if (path == WEAR_TO_PHONE_UI_HEARTBEAT_PATH) {
            lastWatchUiHeartbeatAtMs.set(System.currentTimeMillis())
            return
        }
        if (path == WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH) {
            val snapshotBytes = lastSnapshotBytes.get() ?: return
            scope.launch {
                runCatching {
                    Wearable.getMessageClient(context)
                        .sendMessage(sourceNodeId, PHONE_TO_WEAR_SNAPSHOT_PATH, snapshotBytes)
                        .await()
                }.onFailure { Log.e("SchliftWearBridge", "Failed snapshot reply to node=$sourceNodeId", it) }
            }
            return
        }
        if (path == WEAR_TO_PHONE_CLOCK_SYNC_PATH) {
            val payload = bytes.decodeToString()
            val separator = payload.indexOf(':')
            if (separator > 0) {
                val requestId = payload.substring(0, separator)
                val watchTimeMs = payload.substring(separator + 1).toLongOrNull()
                if (watchTimeMs != null) {
                    pendingClockSyncs.remove(requestId)?.complete(watchTimeMs)
                }
            }
            return
        }
        when (path) {
            WEAR_TO_PHONE_INTENT_PATH -> runCatching {
                workout.v1.Wearable.WearIntent.parseFrom(bytes)
                emitIntent(bytes)
                Log.d("SchliftWearBridge", "Received wear intent bytes=${bytes.size}")
            }.onFailure { Log.e("SchliftWearBridge", "Failed to parse wear intent", it) }

            WEAR_TO_PHONE_SENSOR_BATCH_PATH -> runCatching {
                val batch = workout.v1.Wearable.WearSensorBatch.parseFrom(bytes)
                emitSensor(bytes)
                sendSensorBatchAck(context, sourceNodeId, batch)
                Log.d("SchliftWearBridge", "Received wear sensor batch id=${batch.batchId} bytes=${bytes.size}")
            }.onFailure { Log.e("SchliftWearBridge", "Failed to parse wear sensor batch", it) }
        }
    }

    private fun sendSensorBatchAck(
        context: Context,
        sourceNodeId: String,
        batch: workout.v1.Wearable.WearSensorBatch,
    ) {
        if (batch.batchId.isBlank()) return
        val ack = workout.v1.Wearable.WearSensorBatchAck.newBuilder()
            .setBatchId(batch.batchId)
            .setWorkoutId(batch.workoutId)
            .setReceivedAt(System.currentTimeMillis())
            .build()
        scope.launch {
            runCatching {
                Wearable.getMessageClient(context)
                    .sendMessage(sourceNodeId, PHONE_TO_WEAR_SENSOR_BATCH_ACK_PATH, ack.toByteArray())
                    .await()
            }.onFailure {
                Log.e("SchliftWearBridge", "Failed sensor batch ack id=${batch.batchId}", it)
            }
        }
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
