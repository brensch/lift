package com.brensch.schlift.wear

import android.content.Context
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

object WearTransport {
    const val PHONE_TO_WEAR_SNAPSHOT_PATH = "/schlift/phone/snapshot"
    const val PHONE_TO_WEAR_LAUNCH_PATH = "/schlift/phone/launch"
    const val PHONE_TO_WEAR_CLOCK_SYNC_PATH = "/schlift/phone/clock_sync"
    const val PHONE_TO_WEAR_SENSOR_BATCH_ACK_PATH = "/schlift/phone/sensor_batch_ack"
    const val WEAR_TO_PHONE_INTENT_PATH = "/schlift/wear/intent"
    const val WEAR_TO_PHONE_SENSOR_BATCH_PATH = "/schlift/wear/sensor_batch"
    const val WEAR_TO_PHONE_UI_HEARTBEAT_PATH = "/schlift/wear/ui_heartbeat"
    const val WEAR_TO_PHONE_CLOCK_SYNC_PATH = "/schlift/wear/clock_sync"
    const val WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH = "/schlift/wear/snapshot_request"

    suspend fun sendToPhone(context: Context, path: String, payload: ByteArray): Int {
        val nodeClient = Wearable.getNodeClient(context)
        val messageClient = Wearable.getMessageClient(context)
        val nodes = nodeClient.connectedNodes.await()
        var sent = 0
        for (node in nodes) {
            withContext(Dispatchers.IO) {
                messageClient.sendMessage(node.id, path, payload).await()
            }
            sent += 1
        }
        return sent
    }
}
