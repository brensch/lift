package com.brensch.schlift.wear

import android.content.Context
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import workout.v1.Wearable

object WearSensorBatchOutbox {
    private const val PREFS_NAME = "wear_sensor_batch_outbox"
    private const val KEY_BATCHES = "batches"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val flushMutex = Mutex()

    fun enqueue(context: Context, batch: Wearable.WearSensorBatch): Boolean {
        val appContext = context.applicationContext
        synchronized(this) {
            val encodedBatches = loadEncodedBatches(appContext).toMutableList()
            val updated = encodedBatches.filterNot { encoded ->
                decodeBatch(encoded)?.batchId == batch.batchId
            }.toMutableList()
            updated.add(encodeBatch(batch))
            persistEncodedBatches(appContext, updated)
            Log.d("SchliftWear", "Enqueued HR batch id=${batch.batchId} samples=${batch.heartRateSamplesCount}")
            return true
        }
    }

    fun acknowledge(context: Context, ack: Wearable.WearSensorBatchAck) {
        val appContext = context.applicationContext
        synchronized(this) {
            val updated = loadEncodedBatches(appContext).filterNot { encoded ->
                decodeBatch(encoded)?.batchId == ack.batchId
            }
            persistEncodedBatches(appContext, updated)
        }
        Log.d("SchliftWear", "Acked HR batch id=${ack.batchId}")
    }

    fun flush(context: Context) {
        val appContext = context.applicationContext
        scope.launch {
            flushMutex.withLock {
                val encodedBatches = synchronized(this@WearSensorBatchOutbox) {
                    loadEncodedBatches(appContext)
                }
                if (encodedBatches.isEmpty()) return@withLock
                for (encoded in encodedBatches) {
                    val batch = decodeBatch(encoded) ?: continue
                    runCatching {
                        val sent = WearTransport.sendToPhone(
                            appContext,
                            WearTransport.WEAR_TO_PHONE_SENSOR_BATCH_PATH,
                            batch.toByteArray(),
                        )
                        if (sent == 0) {
                            throw IllegalStateException("No connected phone node")
                        }
                        Log.d("SchliftWear", "Sent queued HR batch id=${batch.batchId} samples=${batch.heartRateSamplesCount}")
                    }.onFailure {
                        Log.w("SchliftWear", "Failed sending queued HR batch id=${batch.batchId}", it)
                        return@withLock
                    }
                }
            }
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun loadEncodedBatches(context: Context): List<String> {
        val raw = prefs(context).getString(KEY_BATCHES, null) ?: return emptyList()
        return runCatching {
            val json = JSONArray(raw)
            List(json.length()) { index -> json.getString(index) }
        }.getOrElse {
            Log.w("SchliftWear", "Failed to decode stored HR outbox; clearing", it)
            prefs(context).edit().remove(KEY_BATCHES).apply()
            emptyList()
        }
    }

    private fun persistEncodedBatches(context: Context, encodedBatches: List<String>) {
        val json = JSONArray()
        encodedBatches.forEach(json::put)
        prefs(context).edit().putString(KEY_BATCHES, json.toString()).apply()
    }

    private fun encodeBatch(batch: Wearable.WearSensorBatch): String =
        Base64.encodeToString(batch.toByteArray(), Base64.NO_WRAP)

    private fun decodeBatch(encoded: String): Wearable.WearSensorBatch? =
        runCatching {
            Wearable.WearSensorBatch.parseFrom(Base64.decode(encoded, Base64.DEFAULT))
        }.getOrNull()
}
