package com.lift.lift.wear

import android.content.Context
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

object WearTransport {
    const val PHONE_TO_WEAR_PATH = "/lift/phone/envelope"
    const val WEAR_TO_PHONE_PATH = "/lift/wear/envelope"

    suspend fun sendToPhone(context: Context, path: String, payload: ByteArray) {
        val nodeClient = Wearable.getNodeClient(context)
        val messageClient = Wearable.getMessageClient(context)
        val nodes = nodeClient.connectedNodes.await()
        for (node in nodes) {
            withContext(Dispatchers.IO) {
                messageClient.sendMessage(node.id, path, payload).await()
            }
        }
    }
}
